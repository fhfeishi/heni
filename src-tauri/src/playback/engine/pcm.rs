use rubato::{
    audioadapter_buffers::direct::InterleavedSlice, Async, FixedAsync, Indexing, Resampler,
    SincInterpolationParameters, SincInterpolationType, WindowFunction,
};

pub(super) struct PcmPipeline {
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
    pub(super) fn new(
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

    pub(super) fn push(&mut self, input: &[f32], output: &mut Vec<f32>) -> Result<(), String> {
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

    pub(super) fn finish(&mut self, output: &mut Vec<f32>) -> Result<(), String> {
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

#[cfg(test)]
mod tests {
    use super::PcmPipeline;

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
        assert!(PcmPipeline::new(48_000, 48_000, 2, 4).is_err());
    }
}
