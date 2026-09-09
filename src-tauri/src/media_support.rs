use std::sync::OnceLock;

use symphonia::{core::codecs::registry::CodecRegistry, default::register_enabled_codecs};
use symphonia_adapter_libopus::OpusDecoder;

pub(crate) fn audio_codec_registry() -> &'static CodecRegistry {
    static REGISTRY: OnceLock<CodecRegistry> = OnceLock::new();

    REGISTRY.get_or_init(|| {
        let mut registry = CodecRegistry::new();
        register_enabled_codecs(&mut registry);
        registry.register_audio_decoder::<OpusDecoder>();
        registry
    })
}
