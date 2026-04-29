// Rust implementation of the local:github component, on WASI 0.3.
//
// Uses wit-bindgen 0.57.1 with async-fn codegen + async streams. The
// exports are async (return `result<...>` to the host) and we drive
// `wasi:http/client.send` directly via .await.

use serde::Deserialize;

wit_bindgen::generate!({
    world: "github",
    path: "wit",
    generate_all,
    async: ["wasi:http/client@0.3.0-rc-2026-03-15#send"],
});

use exports::local::github::api::{Guest, RepoInfo, UserInfo};
use wasi::http::client;
use wasi::http::types::{ErrorCode, Fields, Method, Request, Response, Scheme};

const USER_AGENT: &str = "github-wasm-rs/0.2";

#[derive(Deserialize)]
struct GhUser {
    login: String,
    id: u64,
    name: Option<String>,
    bio: Option<String>,
    public_repos: u32,
    followers: u32,
    following: u32,
    html_url: String,
}

#[derive(Deserialize)]
struct GhRepo {
    full_name: String,
    description: Option<String>,
    stargazers_count: u32,
    forks_count: u32,
    language: Option<String>,
    default_branch: String,
    html_url: String,
}

async fn http_get_json(path: &str, token: Option<&str>) -> Result<Vec<u8>, String> {
    let headers = Fields::new();
    headers
        .append(&"User-Agent".to_string(), &USER_AGENT.as_bytes().to_vec())
        .map_err(|e| format!("header User-Agent: {e:?}"))?;
    headers
        .append(
            &"Accept".to_string(),
            &b"application/vnd.github+json".to_vec(),
        )
        .map_err(|e| format!("header Accept: {e:?}"))?;
    if let Some(t) = token {
        let v = format!("Bearer {t}").into_bytes();
        headers
            .append(&"Authorization".to_string(), &v)
            .map_err(|e| format!("header Authorization: {e:?}"))?;
    }

    // No body → no contents stream and a trivially-Ok trailers future.
    let trailers_future = wit_future::new::<Result<Option<Fields>, ErrorCode>>(|| Ok(None)).1;
    let (request, _send_status) = Request::new(headers, None, trailers_future, None);
    request.set_method(&Method::Get).map_err(|_| "set method")?;
    request
        .set_scheme(Some(&Scheme::Https))
        .map_err(|_| "set scheme")?;
    request
        .set_authority(Some(&"api.github.com".to_string()))
        .map_err(|_| "set authority")?;
    request
        .set_path_with_query(Some(&path.to_string()))
        .map_err(|_| "set path")?;

    let response: Response = client::send(request)
        .await
        .map_err(|e| format!("send: {e:?}"))?;
    let status = response.get_status_code();

    let res_future = wit_future::new::<Result<(), ErrorCode>>(|| Ok(())).1;
    let (mut body_stream, _trailers) = Response::consume_body(response, res_future);

    let mut buf = Vec::new();
    loop {
        let chunk_buf = Vec::with_capacity(64 * 1024);
        let (status, chunk) = body_stream.read(chunk_buf).await;
        if !chunk.is_empty() {
            buf.extend_from_slice(&chunk);
        }
        match status {
            wit_bindgen::rt::async_support::StreamResult::Complete(_) => continue,
            wit_bindgen::rt::async_support::StreamResult::Dropped => break,
            wit_bindgen::rt::async_support::StreamResult::Cancelled => break,
        }
    }

    if !(200..300).contains(&status) {
        let snip = String::from_utf8_lossy(&buf);
        return Err(format!("HTTP {status}: {snip}"));
    }
    Ok(buf)
}

struct Component;

impl Guest for Component {
    async fn get_user(login: String, token: Option<String>) -> Result<UserInfo, String> {
        let path = format!("/users/{login}");
        let bytes = http_get_json(&path, token.as_deref()).await?;
        let u: GhUser = serde_json::from_slice(&bytes).map_err(|e| format!("parse: {e}"))?;
        Ok(UserInfo {
            login: u.login,
            id: u.id,
            name: u.name,
            bio: u.bio,
            public_repos: u.public_repos,
            followers: u.followers,
            following: u.following,
            html_url: u.html_url,
        })
    }

    async fn get_repo(
        owner: String,
        repo: String,
        token: Option<String>,
    ) -> Result<RepoInfo, String> {
        let path = format!("/repos/{owner}/{repo}");
        let bytes = http_get_json(&path, token.as_deref()).await?;
        let r: GhRepo = serde_json::from_slice(&bytes).map_err(|e| format!("parse: {e}"))?;
        Ok(RepoInfo {
            full_name: r.full_name,
            description: r.description,
            stargazers_count: r.stargazers_count,
            forks_count: r.forks_count,
            language: r.language,
            default_branch: r.default_branch,
            html_url: r.html_url,
        })
    }
}

export!(Component);
