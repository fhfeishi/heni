use std::{
    fs::File,
    path::Path,
    sync::{
        atomic::{AtomicBool, AtomicU32, AtomicU64, Ordering},
        Arc,
    },
    thread::{self, JoinHandle},
    time::{Duration, Instant},
};

use cpal::{
    traits::{DeviceTrait, HostTrait, StreamTrait},
    Device, FromSample, OutputCallbackInfo, SampleFormat, SizedSample, Stream, StreamConfig, I24,
    U24,
};
use ringbuf::{traits::*, HeapCons, HeapProd, HeapRb};
use symphonia::{
    core::{
        codecs::audio::{AudioDecoder, AudioDecoderOptions},
        errors::Error as SymphoniaError,
        formats::{probe::Hint, FormatOptions, FormatReader, SeekMode, SeekTo, TrackType},
        io::MediaSourceStream,
        meta::MetadataOptions,
        units::{Time, TimeBase},
    },
    default::get_probe,
};

use super::{pcm::PcmPipeline, EngineObservation, PlaybackEngine};
use crate::playback::contracts::{MediaKind, PlaybackError, PlaybackItem};

const RING_DURATION_MS: usize = 500;
const PREFILL_DURATION_MS: usize = 100;
const PREFILL_TIMEOUT: Duration = Duration::from_secs(2);

struct DecoderState {
    format: Box<dyn FormatReader>,
    decoder: Box<dyn AudioDecoder>,
    track_id: u32,
    sample_rate: u32,
    channels: usize,
    time_base: Option<TimeBase>,
    discard_before_nanos: Option<i128>,
}

struct OpenedDecoder {
    state: DecoderState,
    duration_ms: Option<u64>,
}

#[derive(Default)]
struct PlaybackMetrics {
    cancelled: AtomicBool,
    completed: AtomicBool,
    decoder_failed: AtomicBool,
    gain_bits: AtomicU32,
    muted: AtomicBool,
    playing: AtomicBool,
    producer_done: AtomicBool,
    produced_samples: AtomicU64,
    consumed_samples: AtomicU64,
    stream_errors: AtomicU64,
}

struct ActivePlayback {
    metrics: Arc<PlaybackMetrics>,
    stream: Option<Stream>,
    worker: Option<JoinHandle<()>>,
    output_rate: u32,
    output_channels: usize,
    base_position_ms: u64,
    duration_ms: Option<u64>,
}

impl ActivePlayback {
    fn observation(&self) -> EngineObservation {
        let consumed_samples = self.metrics.consumed_samples.load(Ordering::Acquire);
        let consumed_frames = consumed_samples / self.output_channels as u64;
        let elapsed_ms = consumed_frames
            .saturating_mul(1_000)
            .checked_div(u64::from(self.output_rate))
            .unwrap_or(0);
        let position_ms = self.duration_ms.map_or(
            self.base_position_ms.saturating_add(elapsed_ms),
            |duration| {
                self.base_position_ms
                    .saturating_add(elapsed_ms)
                    .min(duration)
            },
        );

        EngineObservation {
            active: true,
            position_ms,
            duration_ms: self.duration_ms,
            completed: self.metrics.completed.load(Ordering::Acquire),
            failed: self.metrics.decoder_failed.load(Ordering::Acquire)
                || self.metrics.stream_errors.load(Ordering::Acquire) > 0,
        }
    }

    fn shutdown(&mut self) {
        self.metrics.cancelled.store(true, Ordering::Release);
        self.stream.take();
        if let Some(worker) = self.worker.take() {
            let _ = worker.join();
        }
    }
}

impl Drop for ActivePlayback {
    fn drop(&mut self) {
        self.shutdown();
    }
}

#[derive(Default)]
pub(in crate::playback) struct NativeAudioEngine {
    active: Option<ActivePlayback>,
}

impl NativeAudioEngine {
    fn build_active(
        item: &PlaybackItem,
        position_ms: u64,
        playing: bool,
        volume: f64,
        muted: bool,
    ) -> Result<ActivePlayback, PlaybackError> {
        if item.kind != MediaKind::Audio {
            return Err(PlaybackError::new(
                "unsupported-media-kind",
                "Video playback is not available in the current audio adapter.",
            ));
        }

        let path = Path::new(&item.path);
        if !path.is_file() {
            return Err(PlaybackError::new(
                "file-unavailable",
                "The selected audio file is no longer available.",
            ));
        }

        let opened = open_decoder(path, position_ms)?;
        let host = cpal::default_host();
        let device = host.default_output_device().ok_or_else(|| {
            PlaybackError::new(
                "audio-device-unavailable",
                "Windows did not provide a default audio output device.",
            )
        })?;
        let supported_config = device.default_output_config().map_err(|_| {
            PlaybackError::new(
                "audio-device-unavailable",
                "The default audio device did not provide a usable output format.",
            )
        })?;
        let sample_format = supported_config.sample_format();
        let config: StreamConfig = supported_config.into();
        let output_channels = usize::from(config.channels);

        let samples_per_ms = config.sample_rate as usize * output_channels / 1_000;
        let ring_capacity = samples_per_ms.saturating_mul(RING_DURATION_MS).max(1);
        let prefill_samples = samples_per_ms.saturating_mul(PREFILL_DURATION_MS) as u64;
        let ring = HeapRb::<f32>::new(ring_capacity);
        let (producer, consumer) = ring.split();

        let metrics = Arc::new(PlaybackMetrics::default());
        metrics
            .gain_bits
            .store(gain_for(volume).to_bits(), Ordering::Release);
        metrics.muted.store(muted, Ordering::Release);

        let stream = build_stream_for_format(
            &device,
            &config,
            sample_format,
            consumer,
            Arc::clone(&metrics),
        )?;

        let worker_metrics = Arc::clone(&metrics);
        let output_rate = config.sample_rate;
        let decoder_state = opened.state;
        let worker = thread::Builder::new()
            .name("heni-audio-decoder".to_owned())
            .spawn(move || {
                if decode_into_ring(
                    decoder_state,
                    producer,
                    Arc::clone(&worker_metrics),
                    output_rate,
                    output_channels,
                )
                .is_err()
                {
                    worker_metrics.decoder_failed.store(true, Ordering::Release);
                }
                worker_metrics.producer_done.store(true, Ordering::Release);
            })
            .map_err(|_| {
                PlaybackError::new(
                    "audio-output",
                    "The audio decoder worker could not be started.",
                )
            })?;

        wait_for_prefill(&metrics, prefill_samples);
        if metrics.decoder_failed.load(Ordering::Acquire)
            || (metrics.producer_done.load(Ordering::Acquire)
                && metrics.produced_samples.load(Ordering::Acquire) == 0)
        {
            metrics.cancelled.store(true, Ordering::Release);
            drop(stream);
            let _ = worker.join();
            return Err(PlaybackError::new(
                "decoder-failed",
                "The selected file could not be decoded as supported audio.",
            ));
        }

        metrics.playing.store(playing, Ordering::Release);
        if stream.play().is_err() {
            metrics.cancelled.store(true, Ordering::Release);
            drop(stream);
            let _ = worker.join();
            return Err(PlaybackError::new(
                "audio-output",
                "Windows could not start the audio output stream.",
            ));
        }

        Ok(ActivePlayback {
            metrics,
            stream: Some(stream),
            worker: Some(worker),
            output_rate,
            output_channels,
            base_position_ms: position_ms,
            duration_ms: opened.duration_ms,
        })
    }
}

impl PlaybackEngine for NativeAudioEngine {
    fn load(
        &mut self,
        item: &PlaybackItem,
        position_ms: u64,
        playing: bool,
        volume: f64,
        muted: bool,
    ) -> Result<Option<u64>, PlaybackError> {
        let next = Self::build_active(item, position_ms, false, volume, muted)?;
        let duration_ms = next.duration_ms;
        self.active = Some(next);
        self.set_playing(playing)?;
        Ok(duration_ms)
    }

    fn set_playing(&mut self, playing: bool) -> Result<(), PlaybackError> {
        let active = self.active.as_ref().ok_or_else(|| {
            PlaybackError::new(
                "playback-unavailable",
                "No audio stream is loaded for this playback command.",
            )
        })?;
        active.metrics.playing.store(playing, Ordering::Release);
        Ok(())
    }

    fn stop(&mut self) {
        self.active = None;
    }

    fn set_volume(&mut self, volume: f64) {
        if let Some(active) = &self.active {
            active
                .metrics
                .gain_bits
                .store(gain_for(volume).to_bits(), Ordering::Release);
        }
    }

    fn set_muted(&mut self, muted: bool) {
        if let Some(active) = &self.active {
            active.metrics.muted.store(muted, Ordering::Release);
        }
    }

    fn observation(&self) -> EngineObservation {
        self.active
            .as_ref()
            .map_or_else(EngineObservation::default, ActivePlayback::observation)
    }
}

fn gain_for(volume: f64) -> f32 {
    (volume / 100.0).clamp(0.0, 1.0) as f32
}

fn open_decoder(path: &Path, seek_ms: u64) -> Result<OpenedDecoder, PlaybackError> {
    let file = File::open(path).map_err(|_| {
        PlaybackError::new(
            "file-unavailable",
            "The selected audio file could not be opened.",
        )
    })?;
    let source = MediaSourceStream::new(Box::new(file), Default::default());
    let mut hint = Hint::new();
    if let Some(extension) = path.extension().and_then(|value| value.to_str()) {
        hint.with_extension(extension);
    }

    let mut format = get_probe()
        .probe(
            &hint,
            source,
            FormatOptions::default(),
            MetadataOptions::default(),
        )
        .map_err(|_| {
            PlaybackError::new(
                "unsupported-media",
                "The selected file has an unsupported or damaged media container.",
            )
        })?;
    let track = format
        .default_track(TrackType::Audio)
        .cloned()
        .ok_or_else(|| {
            PlaybackError::new(
                "unsupported-media",
                "The selected file does not contain a supported audio track.",
            )
        })?;
    let audio_params = track
        .codec_params
        .as_ref()
        .and_then(|parameters| parameters.audio())
        .ok_or_else(|| {
            PlaybackError::new(
                "unsupported-media",
                "The selected audio track does not expose usable codec parameters.",
            )
        })?;
    let sample_rate = audio_params.sample_rate.ok_or_else(|| {
        PlaybackError::new(
            "unsupported-media",
            "The selected audio track has no sample rate.",
        )
    })?;
    let channels = audio_params
        .channels
        .as_ref()
        .map(|channel_mask| channel_mask.count())
        .ok_or_else(|| {
            PlaybackError::new(
                "unsupported-media",
                "The selected audio track has no channel layout.",
            )
        })?;
    let time_base = track.time_base;
    let duration_ms = track
        .duration
        .and_then(|duration| time_base.and_then(|base| base.calc_duration(duration)))
        .and_then(|time| u64::try_from(time.as_millis()).ok())
        .or_else(|| {
            track
                .num_frames
                .map(|frames| frames.saturating_mul(1_000) / u64::from(sample_rate))
        });

    let mut discard_before_nanos = None;
    if seek_ms > 0 {
        let seeked = format
            .seek(
                SeekMode::Accurate,
                SeekTo::Time {
                    time: Time::from_millis_u64(seek_ms),
                    track_id: Some(track.id),
                },
            )
            .map_err(|_| {
                PlaybackError::new(
                    "unsupported-media",
                    "The selected audio container could not seek to that position.",
                )
            })?;
        let required = time_base
            .ok_or_else(|| {
                PlaybackError::new(
                    "unsupported-media",
                    "The selected audio track has no timing information for seeking.",
                )
            })?
            .calc_time_saturating(seeked.required_ts);
        discard_before_nanos = Some(required.as_nanos());
    }

    let decoder = crate::media_support::audio_codec_registry()
        .make_audio_decoder(audio_params, &AudioDecoderOptions::default())
        .map_err(|_| {
            PlaybackError::new(
                "unsupported-media",
                "The selected audio codec is not supported by this Heni build.",
            )
        })?;

    Ok(OpenedDecoder {
        state: DecoderState {
            format,
            decoder,
            track_id: track.id,
            sample_rate,
            channels,
            time_base,
            discard_before_nanos,
        },
        duration_ms,
    })
}

fn decode_into_ring(
    mut state: DecoderState,
    mut producer: HeapProd<f32>,
    metrics: Arc<PlaybackMetrics>,
    output_rate: u32,
    output_channels: usize,
) -> Result<(), String> {
    let mut converted = Vec::<f32>::new();
    let mut transformed = Vec::<f32>::new();
    let mut pipeline = PcmPipeline::new(
        state.sample_rate,
        output_rate,
        state.channels,
        output_channels,
    )?;

    loop {
        if metrics.cancelled.load(Ordering::Acquire) {
            return Ok(());
        }

        let packet = match state.format.next_packet() {
            Ok(Some(packet)) => packet,
            Ok(None) => break,
            Err(SymphoniaError::ResetRequired) => {
                state.decoder.reset();
                continue;
            }
            Err(error) => return Err(error.to_string()),
        };
        if packet.track_id != state.track_id {
            continue;
        }
        let packet_start_nanos = state
            .time_base
            .map(|time_base| time_base.calc_time_saturating(packet.pts).as_nanos());

        let decoded = match state.decoder.decode(&packet) {
            Ok(decoded) => decoded,
            Err(SymphoniaError::DecodeError(_)) => continue,
            Err(SymphoniaError::ResetRequired) => {
                state.decoder.reset();
                continue;
            }
            Err(error) => return Err(error.to_string()),
        };
        decoded.copy_to_vec_interleaved::<f32>(&mut converted);

        let offset = if let Some(discard_before_nanos) = state.discard_before_nanos {
            let packet_start_nanos = packet_start_nanos
                .ok_or_else(|| "cannot trim accurate seek without packet timing".to_owned())?;
            if packet_start_nanos >= discard_before_nanos {
                state.discard_before_nanos = None;
                0
            } else {
                let delta_nanos = discard_before_nanos - packet_start_nanos;
                let skip_samples = samples_to_skip(delta_nanos, state.sample_rate, state.channels)?;
                if skip_samples >= converted.len() {
                    continue;
                }
                state.discard_before_nanos = None;
                skip_samples
            }
        } else {
            0
        };

        pipeline.push(&converted[offset..], &mut transformed)?;
        if !push_into_ring(&transformed, &mut producer, &metrics) {
            return Ok(());
        }
    }

    pipeline.finish(&mut transformed)?;
    let _ = push_into_ring(&transformed, &mut producer, &metrics);
    Ok(())
}

fn push_into_ring(
    samples: &[f32],
    producer: &mut HeapProd<f32>,
    metrics: &PlaybackMetrics,
) -> bool {
    let mut offset = 0;
    while offset < samples.len() {
        if metrics.cancelled.load(Ordering::Acquire) {
            return false;
        }
        let pushed = producer.push_slice(&samples[offset..]);
        if pushed == 0 {
            thread::sleep(Duration::from_millis(1));
            continue;
        }
        offset += pushed;
        metrics
            .produced_samples
            .fetch_add(pushed as u64, Ordering::Release);
    }
    true
}

fn samples_to_skip(delta_nanos: i128, sample_rate: u32, channels: usize) -> Result<usize, String> {
    if delta_nanos <= 0 {
        return Ok(0);
    }
    let skip_frames = (delta_nanos * i128::from(sample_rate) + 999_999_999) / 1_000_000_000;
    usize::try_from(skip_frames)
        .map_err(|_| "seek trim exceeds addressable memory".to_owned())?
        .checked_mul(channels)
        .ok_or_else(|| "seek trim exceeds addressable memory".to_owned())
}

fn build_output_stream<T>(
    device: &Device,
    config: &StreamConfig,
    mut consumer: HeapCons<f32>,
    metrics: Arc<PlaybackMetrics>,
) -> Result<Stream, PlaybackError>
where
    T: SizedSample + FromSample<f32>,
{
    let stream_metrics = Arc::clone(&metrics);
    let error_metrics = Arc::clone(&metrics);

    device
        .build_output_stream(
            *config,
            move |output: &mut [T], _: &OutputCallbackInfo| {
                if !stream_metrics.playing.load(Ordering::Acquire)
                    || stream_metrics.completed.load(Ordering::Acquire)
                {
                    for target in output {
                        *target = T::from_sample(0.0);
                    }
                    return;
                }

                let muted = stream_metrics.muted.load(Ordering::Relaxed);
                let gain = f32::from_bits(stream_metrics.gain_bits.load(Ordering::Relaxed));
                for target in output {
                    match consumer.try_pop() {
                        Some(sample) => {
                            *target = T::from_sample(if muted { 0.0 } else { sample * gain });
                            stream_metrics
                                .consumed_samples
                                .fetch_add(1, Ordering::Relaxed);
                        }
                        None => {
                            *target = T::from_sample(0.0);
                            if stream_metrics.producer_done.load(Ordering::Acquire) {
                                stream_metrics.completed.store(true, Ordering::Release);
                                stream_metrics.playing.store(false, Ordering::Release);
                            }
                        }
                    }
                }
            },
            move |_| {
                error_metrics.stream_errors.fetch_add(1, Ordering::Relaxed);
            },
            None,
        )
        .map_err(|_| {
            PlaybackError::new(
                "audio-output",
                "Windows could not create an output stream for the selected device format.",
            )
        })
}

fn build_stream_for_format(
    device: &Device,
    config: &StreamConfig,
    sample_format: SampleFormat,
    consumer: HeapCons<f32>,
    metrics: Arc<PlaybackMetrics>,
) -> Result<Stream, PlaybackError> {
    match sample_format {
        SampleFormat::I8 => build_output_stream::<i8>(device, config, consumer, metrics),
        SampleFormat::I16 => build_output_stream::<i16>(device, config, consumer, metrics),
        SampleFormat::I24 => build_output_stream::<I24>(device, config, consumer, metrics),
        SampleFormat::I32 => build_output_stream::<i32>(device, config, consumer, metrics),
        SampleFormat::I64 => build_output_stream::<i64>(device, config, consumer, metrics),
        SampleFormat::U8 => build_output_stream::<u8>(device, config, consumer, metrics),
        SampleFormat::U16 => build_output_stream::<u16>(device, config, consumer, metrics),
        SampleFormat::U24 => build_output_stream::<U24>(device, config, consumer, metrics),
        SampleFormat::U32 => build_output_stream::<u32>(device, config, consumer, metrics),
        SampleFormat::U64 => build_output_stream::<u64>(device, config, consumer, metrics),
        SampleFormat::F32 => build_output_stream::<f32>(device, config, consumer, metrics),
        SampleFormat::F64 => build_output_stream::<f64>(device, config, consumer, metrics),
        _ => Err(PlaybackError::new(
            "audio-output",
            "The default output device uses an unsupported sample format.",
        )),
    }
}

fn wait_for_prefill(metrics: &PlaybackMetrics, target_samples: u64) {
    let started = Instant::now();
    while metrics.produced_samples.load(Ordering::Acquire) < target_samples
        && !metrics.producer_done.load(Ordering::Acquire)
        && started.elapsed() < PREFILL_TIMEOUT
        && !metrics.decoder_failed.load(Ordering::Acquire)
    {
        thread::sleep(Duration::from_millis(2));
    }
}

#[cfg(test)]
mod tests {
    use std::{path::PathBuf, thread, time::Duration};

    use super::{gain_for, samples_to_skip, NativeAudioEngine, PlaybackEngine};
    use crate::playback::contracts::{MediaKind, PlaybackItem};

    #[test]
    fn converts_seek_delta_to_interleaved_samples() {
        assert_eq!(
            samples_to_skip(20_000_000, 48_000, 2).expect("valid seek delta"),
            1_920
        );
    }

    #[test]
    fn rounds_partial_frames_up() {
        assert_eq!(samples_to_skip(1, 48_000, 2).expect("valid seek delta"), 2);
    }

    #[test]
    fn clamps_public_volume_to_a_linear_gain() {
        assert_eq!(gain_for(-1.0), 0.0);
        assert_eq!(gain_for(50.0), 0.5);
        assert_eq!(gain_for(101.0), 1.0);
    }

    #[test]
    #[ignore = "requires a Windows audio device and the generated media fixture"]
    fn plays_the_generated_wav_through_the_production_engine() {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("..")
            .join("spikes")
            .join("media-fixtures")
            .join("generated")
            .join("tone.wav");
        assert!(path.is_file(), "generate the local spike fixtures first");
        let item = PlaybackItem {
            id: "hardware-smoke".to_owned(),
            path: path.to_string_lossy().into_owned(),
            title: "tone.wav".to_owned(),
            kind: MediaKind::Audio,
            duration_ms: None,
        };
        let mut engine = NativeAudioEngine::default();

        let duration = engine
            .load(&item, 0, true, 5.0, true)
            .expect("production engine should load the generated WAV");

        for _ in 0..500 {
            let observation = engine.observation();
            assert!(!observation.failed, "production audio stream failed");
            if observation.completed {
                assert!(observation.position_ms >= 900);
                assert!(duration.is_some());
                engine.stop();
                return;
            }
            thread::sleep(Duration::from_millis(10));
        }
        panic!("production audio stream did not complete within five seconds");
    }
}
