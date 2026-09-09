//! Local-only, session-authorized streaming. HTTP parsing belongs to tiny_http.
use super::{byte_range, VideoState};
use std::{
    io::{self, Read, Seek, SeekFrom},
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex, Weak,
    },
    thread,
    time::Duration,
};
use tiny_http::{Header, Method, Response, Server, StatusCode};

pub(super) struct VideoServer {
    server: Arc<Server>,
    stop: Arc<AtomicBool>,
    origin: String,
    token: String,
}

impl VideoServer {
    pub fn start(state: Weak<Mutex<VideoState>>) -> Result<Self, String> {
        let server = Arc::new(
            Server::http((std::net::Ipv4Addr::LOCALHOST, 0))
                .map_err(|_| "Video transport could not start.")?,
        );
        let origin = format!("http://{}", server.server_addr());
        let mut random = [0u8; 16];
        getrandom::fill(&mut random)
            .map_err(|_| "Video transport could not create a source token.")?;
        let token = random
            .iter()
            .map(|byte| format!("{byte:02x}"))
            .collect::<String>();
        let endpoint = Self {
            server,
            stop: Arc::new(AtomicBool::new(false)),
            origin,
            token,
        };
        // Fixed workers bound concurrent disk reads; no playback thread waits on a client socket.
        for _ in 0..4 {
            let server = endpoint.server.clone();
            let stop = endpoint.stop.clone();
            let token = endpoint.token.clone();
            let state = state.clone();
            thread::Builder::new()
                .name("heni-video-stream".into())
                .spawn(move || {
                    while !stop.load(Ordering::Acquire) {
                        if let Ok(Some(request)) = server.recv_timeout(Duration::from_millis(100)) {
                            let response = prepare(&request, &state, &token, &stop);
                            let _ = request.respond(response);
                        }
                    }
                })
                .map_err(|_| "Video transport worker could not start.")?;
        }
        Ok(endpoint)
    }
    pub fn source(&self, epoch: u64) -> String {
        format!("{}/{}/{epoch}", self.origin, self.token)
    }
}

impl Drop for VideoServer {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Release);
        for _ in 0..4 {
            self.server.unblock();
        }
    }
}

fn header(name: &str, value: impl AsRef<str>) -> Header {
    Header::from_bytes(name.as_bytes(), value.as_ref().as_bytes()).expect("static video header")
}

fn prepare(
    request: &tiny_http::Request,
    state: &Weak<Mutex<VideoState>>,
    token: &str,
    stop: &Arc<AtomicBool>,
) -> tiny_http::ResponseBox {
    let empty = |status| Response::empty(StatusCode(status)).boxed();
    if request.method() != &Method::Get && request.method() != &Method::Head {
        return empty(405);
    }
    let prefix = format!("/{token}/");
    let Some(epoch) = request
        .url()
        .strip_prefix(&prefix)
        .and_then(|value| value.parse::<u64>().ok())
    else {
        return empty(403);
    };
    let Some(state) = state.upgrade() else {
        return empty(503);
    };
    let (length, mime) = {
        let Ok(state) = state.lock() else {
            return empty(503);
        };
        let Some(active) = state
            .active
            .as_ref()
            .filter(|active| active.intent.epoch == epoch)
        else {
            return empty(403);
        };
        let Ok(metadata) = active.file.metadata() else {
            return empty(404);
        };
        (metadata.len(), active.mime)
    };
    let range = request
        .headers()
        .iter()
        .find(|header| header.field.equiv("Range"))
        .map(|header| header.value.as_str());
    let Some((start, end)) = byte_range(range, length) else {
        return Response::empty(StatusCode(416))
            .with_header(header("Content-Range", format!("bytes */{length}")))
            .boxed();
    };
    let mut headers = vec![
        header("Content-Type", mime),
        header("Accept-Ranges", "bytes"),
        header("Cache-Control", "no-store"),
    ];
    if range.is_some() {
        headers.push(header(
            "Content-Range",
            format!("bytes {start}-{end}/{length}"),
        ));
    }
    let reader = VideoReader {
        state: Arc::downgrade(&state),
        stop: stop.clone(),
        epoch,
        position: start,
        end,
    };
    let Ok(size) = usize::try_from(end - start + 1) else {
        return empty(413);
    };
    // Content-Length describes the full requested range. The reader never allocates the full movie.
    Response::new(
        StatusCode(if range.is_some() { 206 } else { 200 }),
        headers,
        reader,
        Some(size),
        None,
    )
    .with_chunked_threshold(usize::MAX)
    .boxed()
}

struct VideoReader {
    state: Weak<Mutex<VideoState>>,
    stop: Arc<AtomicBool>,
    epoch: u64,
    position: u64,
    end: u64,
}

impl Read for VideoReader {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        if self.position > self.end || buffer.is_empty() {
            return Ok(0);
        }
        if self.stop.load(Ordering::Acquire) {
            return Err(io::Error::other("Video stream stopped"));
        }
        let state = self
            .state
            .upgrade()
            .ok_or_else(|| io::Error::other("Video stream released"))?;
        let mut state = state
            .lock()
            .map_err(|_| io::Error::other("Video session unavailable"))?;
        let active = state
            .active
            .as_mut()
            .filter(|active| active.intent.epoch == self.epoch)
            .ok_or_else(|| io::Error::other("Video source revoked"))?;
        active.file.seek(SeekFrom::Start(self.position))?;
        let limit = (self.end - self.position + 1)
            .min(buffer.len() as u64)
            .min(64 * 1024) as usize;
        let count = active.file.read(&mut buffer[..limit])?;
        self.position += count as u64;
        Ok(count)
    }
}
