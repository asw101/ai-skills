"""Python implementation of the local:copilot component, on WASI 0.3.

Talks to the GitHub Copilot LLM API at api.githubcopilot.com using the
two-step auth dance (GH_TOKEN -> Copilot session token -> chat). Exposes
`list-models` (GET /models) and a streaming `chat` (POST /chat/completions
with `stream: true`) — chat returns a `stream<string>` of delta fragments
driven by an asyncio task that pumps the SSE body into the writer.
"""

import asyncio
import json
from typing import List, Optional

import wit_world
from componentize_py_async_support.streams import StreamReader, StreamWriter
from componentize_py_types import Err, Ok
from wit_world import exports
from wit_world.exports import api as api_types
from wit_world.imports import client
from wit_world.imports.wasi_http_types import (
    Fields,
    Method_Get,
    Method_Post,
    Request,
    Response,
    Scheme_Https,
)


USER_AGENT = "copilot-wasm-py/0.1"
EDITOR_VERSION = "vscode/1.96.0"
EDITOR_PLUGIN_VERSION = "copilot-chat/0.20.0"
COPILOT_INTEGRATION_ID = "vscode-chat"
DEFAULT_MODEL = "gpt-4o-mini"

GITHUB_API_AUTHORITY = "api.github.com"
COPILOT_API_AUTHORITY = "api.githubcopilot.com"


def _trailers_future():
    return wit_world.result_option_wasi_http_types_fields_wasi_http_types_error_code_future(
        lambda: Ok(None)
    )[1]


def _unit_future():
    return wit_world.result_unit_wasi_http_types_error_code_future(lambda: Ok(None))[1]


async def _build_request(
    method,
    authority: str,
    path: str,
    headers: Fields,
    body_bytes: Optional[bytes],
):
    body_reader = None
    if body_bytes:
        body_writer, body_reader = wit_world.byte_stream()

        async def _pump_body():
            with body_writer:
                await body_writer.write_all(body_bytes)

        asyncio.create_task(_pump_body())

    request = Request.new(headers, body_reader, _trailers_future(), None)[0]
    request.set_method(method)
    request.set_scheme(Scheme_Https())
    request.set_authority(authority)
    request.set_path_with_query(path)
    return request


async def _drain_body(response: Response):
    status = response.get_status_code()
    rx = Response.consume_body(response, _unit_future())[0]
    chunks: list[bytes] = []
    with rx:
        while not rx.writer_dropped:
            chunk = await rx.read(64 * 1024)
            if chunk:
                chunks.append(chunk)
    return status, b"".join(chunks)


async def _exchange_token(gh_token: str) -> str:
    headers = Fields()
    headers.append("Authorization", f"token {gh_token}".encode())
    headers.append("Accept", b"application/json")
    headers.append("User-Agent", USER_AGENT.encode())
    headers.append("Editor-Version", EDITOR_VERSION.encode())

    request = await _build_request(
        Method_Get(), GITHUB_API_AUTHORITY, "/copilot_internal/v2/token", headers, None
    )
    response: Response = await client.send(request)
    status, body = await _drain_body(response)
    if not (200 <= status < 300):
        snippet = body[:200].decode("utf-8", errors="replace")
        raise Err(f"copilot token exchange failed: HTTP {status}: {snippet}")
    parsed = json.loads(body)
    token = parsed.get("token")
    if not isinstance(token, str):
        raise Err("copilot token exchange: missing 'token' in response")
    return token


def _copilot_chat_headers(session_token: str) -> Fields:
    headers = Fields()
    headers.append("Authorization", f"Bearer {session_token}".encode())
    headers.append("Content-Type", b"application/json")
    headers.append("Accept", b"application/json")
    headers.append("User-Agent", USER_AGENT.encode())
    headers.append("Editor-Version", EDITOR_VERSION.encode())
    headers.append("Editor-Plugin-Version", EDITOR_PLUGIN_VERSION.encode())
    headers.append("Copilot-Integration-Id", COPILOT_INTEGRATION_ID.encode())
    headers.append("OpenAI-Intent", b"conversation-panel")
    return headers


def _parse_sse_event(event_bytes: bytes) -> Optional[Optional[str]]:
    """Return None to skip, ('',) for [DONE], or the content fragment."""
    try:
        text = event_bytes.decode("utf-8", errors="replace")
    except Exception:
        return None
    payload: Optional[str] = None
    for line in text.split("\n"):
        line = line.rstrip("\r")
        if line.startswith("data:"):
            payload = line[len("data:"):].lstrip()
    if payload is None:
        return None
    if payload == "[DONE]":
        return ""  # sentinel "done" — see caller
    try:
        obj = json.loads(payload)
    except Exception:
        return None
    try:
        choices = obj.get("choices") or []
        if not choices:
            return None
        delta = choices[0].get("delta") or {}
        content = delta.get("content")
        if not isinstance(content, str) or not content:
            return None
        return content
    except Exception:
        return None


async def _pump_sse(body_rx, out_writer: StreamWriter[str]) -> None:
    buf = bytearray()
    done = False
    try:
        with body_rx, out_writer:
            while not body_rx.writer_dropped:
                chunk = await body_rx.read(32 * 1024)
                if chunk:
                    buf.extend(chunk)

                # Emit each complete `\n\n`-delimited event.
                while True:
                    idx = buf.find(b"\n\n")
                    if idx < 0:
                        break
                    event = bytes(buf[:idx])
                    del buf[: idx + 2]
                    parsed = _parse_sse_event(event)
                    if parsed is None:
                        continue
                    if parsed == "":
                        done = True
                        break
                    written = await out_writer.write([parsed])
                    if written == 0 or out_writer.reader_dropped:
                        done = True
                        break
                if done:
                    break
    except Exception:
        # Any error mid-stream — close the stream silently. Host sees EOF.
        pass


class Api(exports.Api):
    async def list_models(self, gh_token: str) -> List[api_types.ModelInfo]:
        session = await _exchange_token(gh_token)
        headers = _copilot_chat_headers(session)
        request = await _build_request(
            Method_Get(), COPILOT_API_AUTHORITY, "/models", headers, None
        )
        response: Response = await client.send(request)
        status, body = await _drain_body(response)
        if not (200 <= status < 300):
            snippet = body[:200].decode("utf-8", errors="replace")
            raise Err(f"list-models failed: HTTP {status}: {snippet}")
        parsed = json.loads(body)
        out: list[api_types.ModelInfo] = []
        for raw in parsed.get("data", []) or []:
            model_id = raw.get("id")
            if not isinstance(model_id, str):
                continue
            caps_obj = raw.get("capabilities") or {}
            kind = caps_obj.get("type") if isinstance(caps_obj, dict) else None
            out.append(
                api_types.ModelInfo(
                    id=model_id,
                    name=str(raw.get("name") or model_id),
                    vendor=str(raw.get("vendor") or "Unknown"),
                    capabilities=[str(kind) if kind else "chat"],
                    preview=bool(raw.get("preview", False)),
                )
            )
        return out

    async def chat(
        self,
        gh_token: str,
        messages: List[api_types.Message],
        options: Optional[api_types.ChatOptions],
    ) -> StreamReader[str]:
        session = await _exchange_token(gh_token)
        headers = _copilot_chat_headers(session)

        model = (options.model if options and options.model else None) or DEFAULT_MODEL
        body_obj: dict = {
            "model": model,
            "messages": [{"role": m.role, "content": m.content} for m in messages],
            "stream": True,
        }
        if options is not None:
            if options.temperature is not None:
                body_obj["temperature"] = options.temperature
            if options.max_tokens is not None:
                body_obj["max_tokens"] = options.max_tokens
        body_bytes = json.dumps(body_obj).encode()

        request = await _build_request(
            Method_Post(),
            COPILOT_API_AUTHORITY,
            "/chat/completions",
            headers,
            body_bytes,
        )
        response: Response = await client.send(request)
        status = response.get_status_code()
        if not (200 <= status < 300):
            _, body = await _drain_body(response)
            snippet = body[:200].decode("utf-8", errors="replace")
            raise Err(f"chat failed: HTTP {status}: {snippet}")

        body_rx = Response.consume_body(response, _unit_future())[0]
        out_writer, out_reader = wit_world.string_stream()

        asyncio.create_task(_pump_sse(body_rx, out_writer))
        return out_reader
