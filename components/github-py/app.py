"""Python implementation of the local:github component, on WASI 0.3.

componentize-py 0.23 generates p3-aware bindings: `client.send` is an
`async` function and bodies are async byte streams. The exported
`Api` protocol's `get_user` / `get_repo` are also async (matching the
`async func` declarations in our WIT).
"""

import json
from typing import Optional

import wit_world
from componentize_py_types import Ok
from wit_world import exports
from wit_world.exports import api as api_types
from wit_world.imports import client
from wit_world.imports.wasi_http_types import (
    Fields,
    Method_Get,
    Request,
    Response,
    Scheme_Https,
)


USER_AGENT = "github-wasm-py/0.3"


def _trailers_future():
    """A future that resolves to Ok(None) — no trailers, no error."""
    return wit_world.result_option_wasi_http_types_fields_wasi_http_types_error_code_future(
        lambda: Ok(None)
    )[1]


def _unit_future():
    """A future that resolves to Ok(None) for `consume_body`'s `res` parameter."""
    return wit_world.result_unit_wasi_http_types_error_code_future(
        lambda: Ok(None)
    )[1]


async def _http_get_json(path: str, token: Optional[str]) -> dict:
    headers = Fields()
    headers.append("User-Agent", USER_AGENT.encode())
    headers.append("Accept", b"application/vnd.github+json")
    if token:
        headers.append("Authorization", f"Bearer {token}".encode())

    request = Request.new(headers, None, _trailers_future(), None)[0]
    request.set_method(Method_Get())
    request.set_scheme(Scheme_Https())
    request.set_authority("api.github.com")
    request.set_path_with_query(path)

    response: Response = await client.send(request)
    status = response.get_status_code()

    rx = Response.consume_body(response, _unit_future())[0]
    chunks: list[bytes] = []
    with rx:
        while not rx.writer_dropped:
            chunk = await rx.read(64 * 1024)
            if chunk:
                chunks.append(chunk)
    payload = b"".join(chunks)

    if not (200 <= status < 300):
        snippet = payload[:200].decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {status}: {snippet}")
    return json.loads(payload)


class Api(exports.Api):
    async def get_user(self, login: str, token: Optional[str]) -> api_types.UserInfo:
        data = await _http_get_json(f"/users/{login}", token)
        return api_types.UserInfo(
            login=data["login"],
            id=data["id"],
            name=data.get("name"),
            bio=data.get("bio"),
            public_repos=data["public_repos"],
            followers=data["followers"],
            following=data["following"],
            html_url=data["html_url"],
        )

    async def get_repo(self, owner: str, repo: str, token: Optional[str]) -> api_types.RepoInfo:
        data = await _http_get_json(f"/repos/{owner}/{repo}", token)
        return api_types.RepoInfo(
            full_name=data["full_name"],
            description=data.get("description"),
            stargazers_count=data["stargazers_count"],
            forks_count=data["forks_count"],
            language=data.get("language"),
            default_branch=data["default_branch"],
            html_url=data["html_url"],
        )
