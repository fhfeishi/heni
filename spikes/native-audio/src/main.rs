use std::{env, error::Error, fs::File, path::Path};

use serde::Serialize;
use symphonia::{
    core::{
        codecs::{audio::AudioDecoderOptions, registry::CodecRegistry},
        errors::Error as SymphoniaError,
        formats::{probe::Hint, FormatOptions, TrackType},
        io::MediaSourceStream,
        meta::MetadataOptions,
    },
    default::{get_probe, register_enabled_codecs},
};
use symphonia_adapter_libopus::OpusDecoder;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct DecodeReport {
    file_name: String,
    codec_id: String,
    sample_rate: u32,
    channels: usize,
    decoded_frames: u64,
    decoded_duration_ms: u64,
}

fn codec_registry() -> CodecRegistry {
    let mut registry = CodecRegistry::new();
    register_enabled_codecs(&mut registry);
    registry.register_audio_decoder::<OpusDecoder>();
    registry
}

fn decode(path: &Path, codecs: &CodecRegistry) -> Result<DecodeReport, Box<dyn Error>> {
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
    let codec_id = format!("{:?}", audio_params.codec);
    let mut decoder = codecs.make_audio_decoder(audio_params, &AudioDecoderOptions::default())?;
    let mut decoded_frames = 0_u64;
    let mut sample_rate = audio_params.sample_rate.unwrap_or_default();
    let mut channels = audio_params
        .channels
        .as_ref()
        .map_or(0, |channel_mask| channel_mask.count());

    loop {
        let packet = match format.next_packet() {
            Ok(Some(packet)) => packet,
            Ok(None) => break,
            Err(SymphoniaError::ResetRequired) => {
                decoder.reset();
                continue;
            }
            Err(error) => return Err(error.into()),
        };
        if packet.track_id != track.id {
            continue;
        }

        match decoder.decode(&packet) {
            Ok(decoded) => {
                decoded_frames = decoded_frames.saturating_add(decoded.frames() as u64);
                sample_rate = decoded.spec().rate();
                channels = decoded.spec().channels().count();
            }
            Err(SymphoniaError::DecodeError(_)) => continue,
            Err(SymphoniaError::ResetRequired) => {
                decoder.reset();
            }
            Err(error) => return Err(error.into()),
        }
    }

    if decoded_frames == 0 || sample_rate == 0 || channels == 0 {
        return Err("decoder produced no audio frames".into());
    }

    Ok(DecodeReport {
        file_name: path
            .file_name()
            .and_then(|value| value.to_str())
            .unwrap_or("<non-unicode-name>")
            .to_owned(),
        codec_id,
        sample_rate,
        channels,
        decoded_frames,
        decoded_duration_ms: decoded_frames.saturating_mul(1_000) / u64::from(sample_rate),
    })
}

fn main() -> Result<(), Box<dyn Error>> {
    let paths = env::args_os().skip(1).collect::<Vec<_>>();
    if paths.is_empty() {
        return Err("pass one or more local audio paths".into());
    }

    let codecs = codec_registry();
    let mut failed = false;
    for path in paths {
        let path = Path::new(&path);
        match decode(path, &codecs) {
            Ok(report) => println!("{}", serde_json::to_string(&report)?),
            Err(error) => {
                failed = true;
                eprintln!(
                    "{}: {error}",
                    path.file_name()
                        .and_then(|value| value.to_str())
                        .unwrap_or("<non-unicode-name>")
                );
            }
        }
    }

    if failed {
        return Err("one or more decode cases failed".into());
    }
    Ok(())
}
