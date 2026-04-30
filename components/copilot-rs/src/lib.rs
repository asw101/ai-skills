// Rust implementation of the local:copilot component, on WASI 0.3.
//
// Talks to the GitHub Copilot LLM API at api.githubcopilot.com using the
// caller-supplied GH_TOKEN as a bearer token directly — the same path
// Copilot CLI / Codespaces / Actions take. Exposes `list-models`
// (GET /models) and a streaming `chat` (POST /chat/completions with
// `stream: true`) — chat returns a `stream<string>` of delta fragments
// driven by a spawned SSE-parser task.

use serde::Deserialize;
use serde_json::json;
use wit_bindgen::rt::async_support::{self, StreamResult};

wit_bindgen::generate!({
    world: "copilot",
    path: "wit",
    generate_all,
    async: ["wasi:http/client@0.3.0-rc-2026-03-15#send"],
});

use exports::local::copilot::api::{ChatOptions, Guest, Message, ModelInfo};
use wasi::http::client;
use wasi::http::types::{ErrorCode, Fields, Method, Request, Response, Scheme};

const USER_AGENT: &str = "copilot-wasm-rs/0.1";
const EDITOR_VERSION: &str = "vscode/1.96.0";
const EDITOR_PLUGIN_VERSION: &str = "copilot-chat/0.20.0";
const COPILOT_INTEGRATION_ID: &str = "vscode-chat";
const DEFAULT_MODEL: &str = "gpt-4o-mini";

const COPILOT_API_AUTHORITY: &str = "api.githubcopilot.com";

#[derive(Deserialize)]
struct ModelsListResponse {
    data: Vec<RawModel>,
}

#[derive(Deserialize)]
struct RawModel {
    id: String,
    #[serde(default)]
    name: Option<String>,
    #[serde(default)]
    vendor: Option<String>,
    #[serde(default)]
    capabilities: Option<RawCapabilities>,
    #[serde(default)]
    preview: Option<bool>,
}

#[derive(Deserialize)]
struct RawCapabilities {
    #[serde(default, rename = "type")]
    kind: Option<String>,
}

fn add_header(headers: &Fields, name: &str, value: &str) -> Result<(), String> {
    headers
        .append(&name.to_string(), &value.as_bytes().to_vec())
        .map_err(|e| format!("header {name}: {e:?}"))
}

fn build_request(
    method: Method,
    authority: &str,
    path: &str,
    headers: Fields,
    body: Option<Vec<u8>>,
) -> Result<Request, String> {
    let body_reader = if let Some(bytes) = body {
        let (mut writer, reader) = wit_stream::new::<u8>();
        async_support::spawn(async move {
            let _ = writer.write_all(bytes).await;
            drop(writer);
        });
        Some(reader)
    } else {
        None
    };

    let trailers_future = wit_future::new::<Result<Option<Fields>, ErrorCode>>(|| Ok(None)).1;
    let (request, _send_status) = Request::new(headers, body_reader, trailers_future, None);
    request.set_method(&method).map_err(|_| "set method")?;
    request
        .set_scheme(Some(&Scheme::Https))
        .map_err(|_| "set scheme")?;
    request
        .set_authority(Some(&authority.to_string()))
        .map_err(|_| "set authority")?;
    request
        .set_path_with_query(Some(&path.to_string()))
        .map_err(|_| "set path")?;
    Ok(request)
}

async fn drain_body(response: Response) -> (u16, Vec<u8>) {
    let status = response.get_status_code();
    let res_future = wit_future::new::<Result<(), ErrorCode>>(|| Ok(())).1;
    let (mut body_stream, _trailers) = Response::consume_body(response, res_future);

    let mut buf = Vec::new();
    loop {
        let chunk_buf = Vec::with_capacity(32 * 1024);
        let (status, chunk) = body_stream.read(chunk_buf).await;
        if !chunk.is_empty() {
            buf.extend_from_slice(&chunk);
        }
        match status {
            StreamResult::Complete(_) => continue,
            StreamResult::Dropped | StreamResult::Cancelled => break,
        }
    }
    (status, buf)
}

/// Build the standard set of headers for a request to api.githubcopilot.com.
/// `gh_token` is used as a bearer token directly — works with the
/// Copilot CLI / Codespaces / Actions GH_TOKEN, with a Copilot-scoped
/// fine-grained PAT, and with an OAuth token from a Copilot-aware app.
fn copilot_chat_headers(gh_token: &str) -> Result<Fields, String> {
    let headers = Fields::new();
    add_header(&headers, "Authorization", &format!("Bearer {gh_token}"))?;
    add_header(&headers, "Content-Type", "application/json")?;
    add_header(&headers, "Accept", "application/json")?;
    add_header(&headers, "User-Agent", USER_AGENT)?;
    add_header(&headers, "Editor-Version", EDITOR_VERSION)?;
    add_header(&headers, "Editor-Plugin-Version", EDITOR_PLUGIN_VERSION)?;
    add_header(&headers, "Copilot-Integration-Id", COPILOT_INTEGRATION_ID)?;
    add_header(&headers, "OpenAI-Intent", "conversation-panel")?;
    Ok(headers)
}

/// SSE event chunks are separated by `\n\n`. Returns the index of the first
/// `\n\n` if any (pointing at the first `\n`).
fn find_event_boundary(buf: &[u8]) -> Option<usize> {
    buf.windows(2).position(|w| w == b"\n\n")
}

/// Extract `delta.content` from a single OpenAI-style SSE `data:` event.
/// Returns:
///   * `Some(Some(text))` if the event carried text content,
///   * `Some(None)` if the event was `[DONE]`,
///   * `None` if the event had no actionable content (role-only frame, ping, …).
fn parse_sse_event(event_bytes: &[u8]) -> Option<Option<String>> {
    let text = std::str::from_utf8(event_bytes).ok()?;
    let mut payload: Option<&str> = None;
    for line in text.split('\n') {
        let line = line.trim_end_matches('\r');
        if let Some(rest) = line.strip_prefix("data:") {
            payload = Some(rest.trim_start());
        }
    }
    let payload = payload?;
    if payload == "[DONE]" {
        return Some(None);
    }
    let value: serde_json::Value = serde_json::from_str(payload).ok()?;
    let content = value
        .get("choices")?
        .get(0)?
        .get("delta")?
        .get("content")?
        .as_str()?
        .to_string();
    if content.is_empty() {
        None
    } else {
        Some(Some(content))
    }
}

struct Component;

/// Build + send a /chat/completions POST. Returns the response body
/// stream (still-encoded SSE), or an error if the request fails.
async fn send_chat_request(
    gh_token: &str,
    messages: &[Message],
    options: Option<&ChatOptions>,
) -> Result<wit_bindgen::rt::async_support::StreamReader<u8>, String> {
    let headers = copilot_chat_headers(gh_token)?;

    let model = options
        .and_then(|o| o.model.clone())
        .unwrap_or_else(|| DEFAULT_MODEL.to_string());
    let json_messages: Vec<serde_json::Value> = messages
        .iter()
        .map(|m| json!({"role": m.role, "content": m.content}))
        .collect();
    let mut body = json!({
        "model": model,
        "messages": json_messages,
        "stream": true,
    });
    if let Some(opts) = options {
        if let Some(t) = opts.temperature {
            body["temperature"] = json!(t);
        }
        if let Some(mt) = opts.max_tokens {
            body["max_tokens"] = json!(mt);
        }
    }
    let body_bytes = serde_json::to_vec(&body).map_err(|e| format!("encode body: {e}"))?;

    let request = build_request(
        Method::Post,
        COPILOT_API_AUTHORITY,
        "/chat/completions",
        headers,
        Some(body_bytes),
    )?;
    let response = client::send(request)
        .await
        .map_err(|e| format!("send chat: {e:?}"))?;

    let status = response.get_status_code();
    if !(200..300).contains(&status) {
        let (_, body) = drain_body(response).await;
        let snip = String::from_utf8_lossy(&body);
        return Err(format!("chat failed: HTTP {status}: {snip}"));
    }

    let res_future = wit_future::new::<Result<(), ErrorCode>>(|| Ok(())).1;
    let (body_stream, _trailers) = Response::consume_body(response, res_future);
    Ok(body_stream)
}

impl Guest for Component {
    async fn list_models(gh_token: String) -> Result<Vec<ModelInfo>, String> {
        let headers = copilot_chat_headers(&gh_token)?;
        let request = build_request(
            Method::Get,
            COPILOT_API_AUTHORITY,
            "/models",
            headers,
            None,
        )?;
        let response = client::send(request)
            .await
            .map_err(|e| format!("send list-models: {e:?}"))?;
        let (status, body) = drain_body(response).await;
        if !(200..300).contains(&status) {
            let snip = String::from_utf8_lossy(&body);
            return Err(format!("list-models failed: HTTP {status}: {snip}"));
        }
        let parsed: ModelsListResponse =
            serde_json::from_slice(&body).map_err(|e| format!("parse models list: {e}"))?;
        let models = parsed
            .data
            .into_iter()
            .map(|m| ModelInfo {
                name: m.name.clone().unwrap_or_else(|| m.id.clone()),
                vendor: m.vendor.unwrap_or_else(|| "Unknown".to_string()),
                capabilities: vec![m
                    .capabilities
                    .and_then(|c| c.kind)
                    .unwrap_or_else(|| "chat".to_string())],
                preview: m.preview.unwrap_or(false),
                id: m.id,
            })
            .collect();
        Ok(models)
    }

    async fn chat(
        gh_token: String,
        messages: Vec<Message>,
        options: Option<ChatOptions>,
    ) -> Result<wit_bindgen::rt::async_support::StreamReader<String>, String> {
        let mut body_stream = send_chat_request(&gh_token, &messages, options.as_ref()).await?;

        let (mut out_writer, out_reader) = wit_stream::new::<String>();

        async_support::spawn(async move {
            let mut buf: Vec<u8> = Vec::with_capacity(8 * 1024);
            let mut done = false;
            loop {
                let chunk_buf = Vec::with_capacity(32 * 1024);
                let (status, chunk) = body_stream.read(chunk_buf).await;
                if !chunk.is_empty() {
                    buf.extend_from_slice(&chunk);
                }

                while let Some(idx) = find_event_boundary(&buf) {
                    let event: Vec<u8> = buf.drain(..idx + 2).collect();
                    let event_body = &event[..idx];
                    match parse_sse_event(event_body) {
                        Some(Some(text)) => {
                            let (write_status, _) = out_writer.write(vec![text]).await;
                            match write_status {
                                StreamResult::Complete(_) => {}
                                StreamResult::Dropped | StreamResult::Cancelled => {
                                    done = true;
                                    break;
                                }
                            }
                        }
                        Some(None) => {
                            done = true;
                            break;
                        }
                        None => {}
                    }
                }
                if done {
                    break;
                }
                match status {
                    StreamResult::Complete(_) => continue,
                    StreamResult::Dropped | StreamResult::Cancelled => break,
                }
            }
            drop(out_writer);
        });

        Ok(out_reader)
    }

    async fn chat_buffered(
        gh_token: String,
        messages: Vec<Message>,
        options: Option<ChatOptions>,
    ) -> Result<Vec<String>, String> {
        let mut body_stream = send_chat_request(&gh_token, &messages, options.as_ref()).await?;
        let mut out: Vec<String> = Vec::new();
        let mut buf: Vec<u8> = Vec::with_capacity(8 * 1024);
        loop {
            let chunk_buf = Vec::with_capacity(32 * 1024);
            let (status, chunk) = body_stream.read(chunk_buf).await;
            if !chunk.is_empty() {
                buf.extend_from_slice(&chunk);
            }
            let mut done = false;
            while let Some(idx) = find_event_boundary(&buf) {
                let event: Vec<u8> = buf.drain(..idx + 2).collect();
                let event_body = &event[..idx];
                match parse_sse_event(event_body) {
                    Some(Some(text)) => out.push(text),
                    Some(None) => {
                        done = true;
                        break;
                    }
                    None => {}
                }
            }
            if done {
                break;
            }
            match status {
                StreamResult::Complete(_) => continue,
                StreamResult::Dropped | StreamResult::Cancelled => break,
            }
        }
        Ok(out)
    }
}

export!(Component);
