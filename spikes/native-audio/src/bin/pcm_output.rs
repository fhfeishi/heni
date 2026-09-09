use std::{
    env,
    error::Error,
    ffi::OsString,
    fs::File,
    path::Path,
    sync::{
        atomic::{AtomicBool, AtomicU64, Ordering},
        Arc,
    },
    thread,
    time::{Duration, Instant},
};

use cpal::{
    traits::{DeviceTrait, HostTrait, StreamTrait},
    Device, FromSample, OutputCallbackInfo, SampleFormat, SizedSample, Stream, StreamConfig, I24,
    U24,
};
use ringbuf::{traits::*, HeapCons, HeapProd, HeapRb};
use rubato::{
    audioadapter_buffers::direct::InterleavedSlice, Async, FixedAsync, Indexing, Resampler,
    SincInterpolationParameters, SincInterpolationType, WindowFunction,
};
use serde::Serialize;
use symphonia::{
    core::{
        codecs::{
            audio::{AudioDecoder, AudioDecoderOptions},
            registry::CodecRegistry,
        },
        errors::Error as SymphoniaError,
        formats::{probe::Hint, FormatOptions, FormatReader, SeekMode, SeekTo, TrackType},
        io::MediaSourceStream,
        meta::MetadataOptions,
        units::{Time, TimeBase},
    },
    default::{get_probe, register_enabled_codecs},
};
use symphonia_adapter_libopus::OpusDecoder;

const OUTPUT_GAIN: f32 = 0.05;
const RING_DURATION_MS: usize = 500;
const PREFILL_DURATION_MS: usize = 100;
const PLAYBACK_TIMEOUT: Duration = Duration::from_secs(10);

struct DecoderState {
    format: Box<dyn FormatReader>,
    decoder: Box<dyn AudioDecoder>,
    track_id: u32,
    sample_rate: u32,
    channels: usize,
    time_base: Option<TimeBase>,
    discard_before_nanos: Option<i128>,
}

#[derive(Default)]
struct SeekReport {
    requested_ms: Option<u64>,
    required_ms: Option<u64>,
    actual_ms: Option<u64>,
}

#[derive(Default)]
struct PlaybackMetrics {
    cancelled: AtomicBool,
    completed: AtomicBool,
    pause_acknowledged: AtomicBool,
    playing: AtomicBool,
    producer_done: AtomicBool,
    produced_samples: AtomicU64,
    consumed_samples: AtomicU64,
    stopped: AtomicBool,
    underrun_callbacks: AtomicU64,
    stream_errors: AtomicU64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct PlaybackReport {
    file_name: String,
    device_name: String,
    source_sample_rate: u32,
    source_channels: usize,
    sample_rate: u32,
    channels: u16,
    sample_format: String,
    resampled: bool,
    channels_mapped: bool,
    produced_samples: u64,
    consumed_samples: u64,
    underrun_callbacks: u64,
    stream_errors: u64,
    elapsed_ms: u64,
    requested_seek_ms: Option<u64>,
    required_seek_ms: Option<u64>,
    actual_seek_ms: Option<u64>,
    pause_at_ms: Option<u64>,
    pause_duration_ms: Option<u64>,
    pause_consumed_delta: Option<u64>,
    stop_at_ms: Option<u64>,
    stopped: bool,
}

struct ControlPlan {
    pause_at_ms: Option<u64>,
    pause_duration_ms: Option<u64>,
    stop_at_ms: Option<u64>,
}

fn codec_registry() -> CodecRegistry {
    let mut registry = CodecRegistry::new();
    register_enabled_codecs(&mut registry);
    registry.register_audio_decoder::<OpusDecoder>();
    registry
}

fn open_decoder(
    path: &Path,
    codecs: &CodecRegistry,
    seek_ms: Option<u64>,
) -> Result<(DecoderState, u32, usize, SeekReport), Box<dyn Error>> {
    let file = File::open(path)?;
    let source = MediaSourceStream::new(Box::new(file), Default::default());
    let mut hint = Hint::new();
    if let Some(extension) = path.extension().and_then(|value| value.to_str()) {
        hint.with_extension(extension);
    }

    let mut format = get_probe().probe(
        &hint,
        source,
        FormatOptions::default(),
        MetadataOptions::default(),
    )?;
    let track = format
        .default_track(TrackType::Audio)
        .cloned()
        .ok_or("no audio track")?;
    let audio_params = track
        .codec_params
        .as_ref()
        .and_then(|params| params.audio())
        .ok_or("no audio codec parameters")?;
    let sample_rate = audio_params
        .sample_rate
        .ok_or("unknown source sample rate")?;
    let channels = audio_params
        .channels
        .as_ref()
        .map(|channel_mask| channel_mask.count())
        .ok_or("unknown source channel count")?;
    let time_base = track.time_base;
    let mut seek_report = SeekReport::default();
    let mut discard_before_nanos = None;
    if let Some(requested_ms) = seek_ms {
        let seeked = format.seek(
            SeekMode::Accurate,
            SeekTo::Time {
                time: Time::from_millis_u64(requested_ms),
                track_id: Some(track.id),
            },
        )?;
        let track_time_base = time_base.ok_or("source has no time base for seek measurement")?;
        let required = track_time_base.calc_time_saturating(seeked.required_ts);
        let actual = track_time_base.calc_time_saturating(seeked.actual_ts);
        discard_before_nanos = Some(required.as_nanos());
        seek_report = SeekReport {
            requested_ms: Some(requested_ms),
            required_ms: u64::try_from(required.as_millis()).ok(),
            actual_ms: u64::try_from(actual.as_millis()).ok(),
        };
    }
    let decoder = codecs.make_audio_decoder(audio_params, &AudioDecoderOptions::default())?;

    Ok((
        DecoderState {
            format,
            decoder,
            track_id: track.id,
            sample_rate,
            channels,
            time_base,
            discard_before_nanos,
        },
        sample_rate,
        channels,
        seek_report,
    ))
}

fn decode_into_ring(
    mut state: DecoderState,
    mut producer: HeapProd<f32>,
    metrics: Arc<PlaybackMetrics>,
    output_rate: u32,
    output_channels: usize,
) -> Result<u64, String> {
    let result = (|| {
        let mut converted = Vec::<f32>::new();
        let mut transformed = Vec::<f32>::new();
        let mut total = 0_u64;
        let mut pipeline = PcmPipeline::new(
            state.sample_rate,
            output_rate,
            state.channels,
            output_channels,
        )?;

        loop {
            if metrics.cancelled.load(Ordering::Acquire) {
                return Ok(total);
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
                    let skip_samples =
                        samples_to_skip(delta_nanos, state.sample_rate, state.channels)?;
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
            if !push_into_ring(&transformed, &mut producer, &metrics, &mut total) {
                return Ok(total);
            }
        }

        pipeline.finish(&mut transformed)?;
        let _ = push_into_ring(&transformed, &mut producer, &metrics, &mut total);
        Ok(total)
    })();

    metrics.producer_done.store(true, Ordering::Release);
    result
}

fn push_into_ring(
    samples: &[f32],
    producer: &mut HeapProd<f32>,
    metrics: &PlaybackMetrics,
    total: &mut u64,
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
        *total = total.saturating_add(pushed as u64);
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

struct PcmPipeline {
    input_rate: u32,
    output_rate: u32,
    input_channels: usize,
    output_channels: usize,
    resampler: Option<Async<f32>>,
    pending: Vec<f32>,
    mapped: Vec<f32>,
    output_delay_remaining: usize,
    total_input_frames: u64,
    emitted_output_frames: u64,
}

impl PcmPipeline {
    fn new(
        input_rate: u32,
        output_rate: u32,
        input_channels: usize,
        output_channels: usize,
    ) -> Result<Self, String> {
        if input_rate == 0 || output_rate == 0 || input_channels == 0 || output_channels == 0 {
            return Err("PCM transform rates and channels must be non-zero".to_owned());
        }
        let supported_channel_map =
            input_channels == output_channels || input_channels == 1 || output_channels == 1;
        if !supported_channel_map {
            return Err(format!(
                "unsupported channel map: {input_channels} input channels to {output_channels} output channels"
            ));
        }

        let resampler = if input_rate == output_rate {
            None
        } else {
            let parameters = SincInterpolationParameters::new(128, WindowFunction::Blackman2)
                .oversampling_factor(256)
                .interpolation(SincInterpolationType::Quadratic);
            Some(
                Async::<f32>::new_sinc(
                    f64::from(output_rate) / f64::from(input_rate),
                    1.1,
                    &parameters,
                    1_024,
                    output_channels,
                    FixedAsync::Input,
                )
                .map_err(|error| error.to_string())?,
            )
        };
        let output_delay_remaining = resampler.as_ref().map_or(0, Resampler::output_delay);

        Ok(Self {
            input_rate,
            output_rate,
            input_channels,
            output_channels,
            resampler,
            pending: Vec::new(),
            mapped: Vec::new(),
            output_delay_remaining,
            total_input_frames: 0,
            emitted_output_frames: 0,
        })
    }

    fn push(&mut self, input: &[f32], output: &mut Vec<f32>) -> Result<(), String> {
        if !input.len().is_multiple_of(self.input_channels) {
            return Err("decoded PCM is not aligned to complete input frames".to_owned());
        }
        self.total_input_frames = self
            .total_input_frames
            .saturating_add((input.len() / self.input_channels) as u64);
        Self::map_channels(
            input,
            self.input_channels,
            self.output_channels,
            &mut self.mapped,
        );

        output.clear();
        if self.resampler.is_none() {
            output.extend_from_slice(&self.mapped);
            self.emitted_output_frames = self
                .emitted_output_frames
                .saturating_add((self.mapped.len() / self.output_channels) as u64);
            return Ok(());
        }

        self.pending.extend_from_slice(&self.mapped);
        self.process_full_chunks(output)
    }

    fn finish(&mut self, output: &mut Vec<f32>) -> Result<(), String> {
        output.clear();
        if self.resampler.is_none() {
            return Ok(());
        }

        let expected_frames = self.expected_output_frames();
        if !self.pending.is_empty() {
            let input_frames = self.pending.len() / self.output_channels;
            let required_frames = self
                .resampler
                .as_ref()
                .expect("resampler exists")
                .input_frames_next();
            self.pending
                .resize(required_frames * self.output_channels, 0.0);
            let chunk = std::mem::take(&mut self.pending);
            let adapter = InterleavedSlice::new(&chunk, self.output_channels, required_frames)
                .map_err(|error| error.to_string())?;
            let indexing = Indexing::new().partial_len(input_frames);
            let processed = self
                .resampler
                .as_mut()
                .expect("resampler exists")
                .process(&adapter, Some(&indexing))
                .map_err(|error| error.to_string())?
                .take_data();
            self.append_processed(&processed, Some(expected_frames), output);
        }

        let mut zero_pumps = 0;
        while self.emitted_output_frames < expected_frames {
            zero_pumps += 1;
            if zero_pumps > 32 {
                return Err("resampler did not flush its delayed output".to_owned());
            }
            let required_frames = self
                .resampler
                .as_ref()
                .expect("resampler exists")
                .input_frames_next();
            let zeros = vec![0.0; required_frames * self.output_channels];
            let adapter = InterleavedSlice::new(&zeros, self.output_channels, required_frames)
                .map_err(|error| error.to_string())?;
            let indexing = Indexing::new().partial_len(0);
            let processed = self
                .resampler
                .as_mut()
                .expect("resampler exists")
                .process(&adapter, Some(&indexing))
                .map_err(|error| error.to_string())?
                .take_data();
            self.append_processed(&processed, Some(expected_frames), output);
        }

        if self.emitted_output_frames != expected_frames {
            return Err(format!(
                "resampler frame accounting mismatch: expected={expected_frames}, emitted={}",
                self.emitted_output_frames
            ));
        }
        Ok(())
    }

    fn process_full_chunks(&mut self, output: &mut Vec<f32>) -> Result<(), String> {
        loop {
            let required_frames = self
                .resampler
                .as_ref()
                .expect("resampler exists")
                .input_frames_next();
            let required_samples = required_frames * self.output_channels;
            if self.pending.len() < required_samples {
                return Ok(());
            }

            let chunk = self.pending.drain(..required_samples).collect::<Vec<_>>();
            let adapter = InterleavedSlice::new(&chunk, self.output_channels, required_frames)
                .map_err(|error| error.to_string())?;
            let processed = self
                .resampler
                .as_mut()
                .expect("resampler exists")
                .process(&adapter, None)
                .map_err(|error| error.to_string())?
                .take_data();
            self.append_processed(&processed, None, output);
        }
    }

    fn append_processed(
        &mut self,
        processed: &[f32],
        maximum_frames: Option<u64>,
        output: &mut Vec<f32>,
    ) {
        let frames = processed.len() / self.output_channels;
        let skipped = self.output_delay_remaining.min(frames);
        self.output_delay_remaining -= skipped;
        let available_frames = frames - skipped;
        let accepted_frames = maximum_frames.map_or(available_frames, |maximum| {
            maximum
                .saturating_sub(self.emitted_output_frames)
                .min(available_frames as u64) as usize
        });
        let first = skipped * self.output_channels;
        let last = first + accepted_frames * self.output_channels;
        output.extend_from_slice(&processed[first..last]);
        self.emitted_output_frames = self
            .emitted_output_frames
            .saturating_add(accepted_frames as u64);
    }

    fn expected_output_frames(&self) -> u64 {
        self.total_input_frames
            .saturating_mul(u64::from(self.output_rate))
            .saturating_add(u64::from(self.input_rate) - 1)
            / u64::from(self.input_rate)
    }

    fn map_channels(
        input: &[f32],
        input_channels: usize,
        output_channels: usize,
        output: &mut Vec<f32>,
    ) {
        output.clear();
        output.reserve(input.len() / input_channels * output_channels);
        if input_channels == output_channels {
            output.extend_from_slice(input);
        } else if input_channels == 1 {
            for &sample in input {
                output.extend(std::iter::repeat_n(sample, output_channels));
            }
        } else {
            for frame in input.chunks_exact(input_channels) {
                let mixed = frame.iter().copied().sum::<f32>() / input_channels as f32;
                output.push(mixed);
            }
        }
    }
}

fn build_output_stream<T>(
    device: &Device,
    config: &StreamConfig,
    mut consumer: HeapCons<f32>,
    metrics: Arc<PlaybackMetrics>,
) -> Result<Stream, cpal::Error>
where
    T: SizedSample + FromSample<f32>,
{
    let stream_metrics = Arc::clone(&metrics);
    let error_metrics = Arc::clone(&metrics);

    device.build_output_stream(
        *config,
        move |output: &mut [T], _: &OutputCallbackInfo| {
            if stream_metrics.stopped.load(Ordering::Acquire) {
                for target in output {
                    *target = T::from_sample(0.0);
                }
                stream_metrics.completed.store(true, Ordering::Release);
                return;
            }
            if !stream_metrics.playing.load(Ordering::Acquire) {
                stream_metrics
                    .pause_acknowledged
                    .store(true, Ordering::Release);
                for target in output {
                    *target = T::from_sample(0.0);
                }
                return;
            }

            let mut underrun = false;
            for target in output {
                match consumer.try_pop() {
                    Some(sample) => {
                        *target = T::from_sample(sample * OUTPUT_GAIN);
                        stream_metrics
                            .consumed_samples
                            .fetch_add(1, Ordering::Relaxed);
                    }
                    None => {
                        *target = T::from_sample(0.0);
                        if stream_metrics.producer_done.load(Ordering::Acquire) {
                            stream_metrics.completed.store(true, Ordering::Release);
                        } else {
                            underrun = true;
                        }
                    }
                }
            }
            if underrun {
                stream_metrics
                    .underrun_callbacks
                    .fetch_add(1, Ordering::Relaxed);
            }
        },
        move |_| {
            error_metrics.stream_errors.fetch_add(1, Ordering::Relaxed);
        },
        None,
    )
}

fn build_stream_for_format(
    device: &Device,
    config: &StreamConfig,
    sample_format: SampleFormat,
    consumer: HeapCons<f32>,
    metrics: Arc<PlaybackMetrics>,
) -> Result<Stream, Box<dyn Error>> {
    let stream = match sample_format {
        SampleFormat::I8 => build_output_stream::<i8>(device, config, consumer, metrics)?,
        SampleFormat::I16 => build_output_stream::<i16>(device, config, consumer, metrics)?,
        SampleFormat::I24 => build_output_stream::<I24>(device, config, consumer, metrics)?,
        SampleFormat::I32 => build_output_stream::<i32>(device, config, consumer, metrics)?,
        SampleFormat::I64 => build_output_stream::<i64>(device, config, consumer, metrics)?,
        SampleFormat::U8 => build_output_stream::<u8>(device, config, consumer, metrics)?,
        SampleFormat::U16 => build_output_stream::<u16>(device, config, consumer, metrics)?,
        SampleFormat::U24 => build_output_stream::<U24>(device, config, consumer, metrics)?,
        SampleFormat::U32 => build_output_stream::<u32>(device, config, consumer, metrics)?,
        SampleFormat::U64 => build_output_stream::<u64>(device, config, consumer, metrics)?,
        SampleFormat::F32 => build_output_stream::<f32>(device, config, consumer, metrics)?,
        SampleFormat::F64 => build_output_stream::<f64>(device, config, consumer, metrics)?,
        unsupported => {
            return Err(format!("unsupported output sample format: {unsupported}").into())
        }
    };
    Ok(stream)
}

fn wait_for_prefill(metrics: &PlaybackMetrics, target_samples: u64) {
    let started = Instant::now();
    while metrics.produced_samples.load(Ordering::Acquire) < target_samples
        && !metrics.producer_done.load(Ordering::Acquire)
        && started.elapsed() < Duration::from_secs(2)
    {
        thread::sleep(Duration::from_millis(2));
    }
}

fn parse_millis(value: OsString, label: &str) -> Result<u64, String> {
    value
        .to_str()
        .ok_or_else(|| format!("{label} must be valid Unicode"))?
        .parse::<u64>()
        .map_err(|_| format!("{label} must be an unsigned integer"))
}

fn main() -> Result<(), Box<dyn Error>> {
    let mut arguments = env::args_os().skip(1);
    let path = arguments.next().ok_or("pass one local audio path")?;
    let seek_ms = arguments
        .next()
        .map(|value| parse_millis(value, "seek milliseconds"))
        .transpose()?;
    let pause_at_ms = arguments
        .next()
        .map(|value| parse_millis(value, "pause position"))
        .transpose()?;
    let pause_duration_ms = arguments
        .next()
        .map(|value| parse_millis(value, "pause duration"))
        .transpose()?;
    let stop_at_ms = arguments
        .next()
        .map(|value| parse_millis(value, "stop position"))
        .transpose()?;
    if arguments.next().is_some() {
        return Err(
            "usage: pcm_output <audio-path> [seek-ms] [pause-at-ms pause-duration-ms] [stop-at-ms]"
                .into(),
        );
    }
    if pause_at_ms.is_some() != pause_duration_ms.is_some() {
        return Err("pause position and pause duration must be provided together".into());
    }
    let pause_requested = pause_duration_ms.is_some_and(|duration| duration > 0);
    let control = ControlPlan {
        pause_at_ms: pause_at_ms.filter(|_| pause_requested),
        pause_duration_ms: pause_duration_ms.filter(|_| pause_requested),
        stop_at_ms,
    };
    let path = Path::new(&path);
    let codecs = codec_registry();
    let (decoder, source_rate, source_channels, seek_report) =
        open_decoder(path, &codecs, seek_ms)?;

    let host = cpal::default_host();
    let device = host
        .default_output_device()
        .ok_or("no default output device")?;
    let device_name = device.description()?.name().to_owned();
    let supported_config = device.default_output_config()?;
    let sample_format = supported_config.sample_format();
    let config: StreamConfig = supported_config.into();

    let output_channels = usize::from(config.channels);
    let samples_per_ms = config.sample_rate as usize * output_channels / 1_000;
    let ring_capacity = samples_per_ms.saturating_mul(RING_DURATION_MS).max(1);
    let prefill_samples = samples_per_ms.saturating_mul(PREFILL_DURATION_MS) as u64;
    let ring = HeapRb::<f32>::new(ring_capacity);
    let (producer, consumer) = ring.split();
    let metrics = Arc::new(PlaybackMetrics::default());
    let stream = build_stream_for_format(
        &device,
        &config,
        sample_format,
        consumer,
        Arc::clone(&metrics),
    )?;

    let producer_metrics = Arc::clone(&metrics);
    let output_rate = config.sample_rate;
    let producer_thread = thread::Builder::new()
        .name("heni-spike-decoder".to_owned())
        .spawn(move || {
            decode_into_ring(
                decoder,
                producer,
                producer_metrics,
                output_rate,
                output_channels,
            )
        })?;

    wait_for_prefill(&metrics, prefill_samples);
    let started = Instant::now();
    metrics.playing.store(true, Ordering::Release);
    stream.play()?;

    let mut pause_started = false;
    let mut pause_finished = false;
    let mut consumed_before_pause = 0_u64;
    let mut pause_acknowledged_at_ms = None;
    let mut pause_consumed_delta = None;
    let mut stop_requested = false;
    while !metrics.completed.load(Ordering::Acquire) && started.elapsed() < PLAYBACK_TIMEOUT {
        let elapsed_ms = started.elapsed().as_millis() as u64;
        if let (Some(pause_at_ms), Some(pause_duration_ms)) =
            (control.pause_at_ms, control.pause_duration_ms)
        {
            if !pause_started && elapsed_ms >= pause_at_ms {
                metrics.pause_acknowledged.store(false, Ordering::Release);
                metrics.playing.store(false, Ordering::Release);
                pause_started = true;
            }
            if pause_started
                && pause_acknowledged_at_ms.is_none()
                && metrics.pause_acknowledged.load(Ordering::Acquire)
            {
                consumed_before_pause = metrics.consumed_samples.load(Ordering::Acquire);
                pause_acknowledged_at_ms = Some(elapsed_ms);
            }
            if pause_started
                && !pause_finished
                && pause_acknowledged_at_ms.is_some_and(|acknowledged_at| {
                    elapsed_ms >= acknowledged_at.saturating_add(pause_duration_ms)
                })
            {
                let consumed_after_pause = metrics.consumed_samples.load(Ordering::Acquire);
                pause_consumed_delta = Some(consumed_after_pause - consumed_before_pause);
                metrics.playing.store(true, Ordering::Release);
                pause_finished = true;
            }
        }
        if !stop_requested
            && control
                .stop_at_ms
                .is_some_and(|stop_at| elapsed_ms >= stop_at)
        {
            metrics.stopped.store(true, Ordering::Release);
            metrics.cancelled.store(true, Ordering::Release);
            stop_requested = true;
        }
        thread::sleep(Duration::from_millis(5));
    }

    if !metrics.completed.load(Ordering::Acquire) {
        metrics.cancelled.store(true, Ordering::Release);
        drop(stream);
        let _ = producer_thread.join();
        return Err("timed out waiting for the output callback to drain decoded PCM".into());
    }

    drop(stream);
    let decoded_samples = producer_thread
        .join()
        .map_err(|_| "decoder thread panicked")?
        .map_err(|error| format!("decoder failed: {error}"))?;
    let produced_samples = metrics.produced_samples.load(Ordering::Acquire);
    let consumed_samples = metrics.consumed_samples.load(Ordering::Acquire);
    let stopped = metrics.stopped.load(Ordering::Acquire);
    if control.pause_at_ms.is_some() && pause_consumed_delta != Some(0) {
        return Err(
            format!("pause consumed PCM unexpectedly: delta={pause_consumed_delta:?}").into(),
        );
    }
    if decoded_samples != produced_samples
        || (!stopped && consumed_samples != produced_samples)
        || consumed_samples > produced_samples
    {
        return Err(format!(
            "PCM accounting mismatch: decoded={decoded_samples}, produced={produced_samples}, consumed={consumed_samples}"
        )
        .into());
    }

    let report = PlaybackReport {
        file_name: path
            .file_name()
            .and_then(|value| value.to_str())
            .unwrap_or("<non-unicode-name>")
            .to_owned(),
        device_name,
        source_sample_rate: source_rate,
        source_channels,
        sample_rate: config.sample_rate,
        channels: config.channels,
        sample_format: sample_format.to_string(),
        resampled: source_rate != config.sample_rate,
        channels_mapped: source_channels != usize::from(config.channels),
        produced_samples,
        consumed_samples,
        underrun_callbacks: metrics.underrun_callbacks.load(Ordering::Acquire),
        stream_errors: metrics.stream_errors.load(Ordering::Acquire),
        elapsed_ms: started.elapsed().as_millis() as u64,
        requested_seek_ms: seek_report.requested_ms,
        required_seek_ms: seek_report.required_ms,
        actual_seek_ms: seek_report.actual_ms,
        pause_at_ms: control.pause_at_ms,
        pause_duration_ms: control.pause_duration_ms,
        pause_consumed_delta,
        stop_at_ms: control.stop_at_ms,
        stopped,
    };
    println!("{}", serde_json::to_string(&report)?);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{samples_to_skip, PcmPipeline};

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
    fn does_not_skip_for_non_positive_delta() {
        assert_eq!(samples_to_skip(0, 48_000, 2).expect("zero delta"), 0);
        assert_eq!(samples_to_skip(-1, 48_000, 2).expect("negative delta"), 0);
    }

    #[test]
    fn resamples_streamed_mono_44100_to_stereo_48000() {
        let input = vec![0.25_f32; 44_100];
        let mut pipeline = PcmPipeline::new(44_100, 48_000, 1, 2).expect("valid transform");
        let mut block = Vec::new();
        let mut output = Vec::new();

        for chunk in input.chunks(777) {
            pipeline.push(chunk, &mut block).expect("streaming block");
            output.extend_from_slice(&block);
        }
        pipeline.finish(&mut block).expect("resampler tail");
        output.extend_from_slice(&block);

        assert_eq!(output.len(), 48_000 * 2);
    }

    #[test]
    fn mixes_stereo_to_mono_without_resampling() {
        let mut pipeline = PcmPipeline::new(48_000, 48_000, 2, 1).expect("valid transform");
        let mut output = Vec::new();

        pipeline
            .push(&[1.0, -1.0, 0.5, 0.5], &mut output)
            .expect("channel map");

        assert_eq!(output, [0.0, 0.5]);
    }

    #[test]
    fn rejects_ambiguous_multichannel_mapping() {
        let result = PcmPipeline::new(48_000, 48_000, 2, 4);

        assert!(result.is_err());
    }
}
