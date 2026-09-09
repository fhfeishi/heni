use std::error::Error;

use cpal::traits::{DeviceTrait, HostTrait};
use serde::Serialize;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct OutputDeviceReport {
    host: String,
    device_name: String,
    channels: u16,
    sample_rate: u32,
    sample_format: String,
}

fn main() -> Result<(), Box<dyn Error>> {
    let host = cpal::default_host();
    let device = host
        .default_output_device()
        .ok_or("no default output device")?;
    let description = device.description()?;
    let config = device.default_output_config()?;
    let report = OutputDeviceReport {
        host: format!("{:?}", host.id()),
        device_name: description.name().to_owned(),
        channels: config.channels(),
        sample_rate: config.sample_rate(),
        sample_format: format!("{:?}", config.sample_format()),
    };

    println!("{}", serde_json::to_string(&report)?);
    Ok(())
}
