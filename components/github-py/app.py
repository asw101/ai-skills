"""Python implementation of the local:github component.

componentize-py generates bindings under `wit_world/` and ships a
`poll_loop.py` helper that drives wasi:io polling via asyncio. We use
`poll_loop.send()` to issue the request and `poll_loop.Stream` to read
the response body. Authentication is per-call via an optional bearer
token.
"""

import asyncio
import json
from typing import Optional

import poll_loop
from poll_loop import PollLoop, Stream, send

from wit_world.exports import Api as ApiBase
from wit_world.exports import api as api_types
from wit_world.imports import types as ht


USER_AGENT = "github-wasm-py/0.1"


def _build_request(path: str, token: Optional[str]) -> ht.OutgoingRequest:
    headers = ht.Fields()
    headers.append("User-Agent", USER_AGENT.encode())
    headers.append("Accept", b"application/vnd.github+json")
    if token:
        headers.append("Authorization", f"Bearer {token}".encode())

    req = ht.OutgoingRequest(headers)
    req.set_method(ht.Method_Get())
    req.set_scheme(ht.Scheme_Https())
    req.set_authority("api.github.com")
    req.set_path_with_query(path)
    return req


async def _fetch_json(path: str, token: Optional[str]) -> dict:
    req = _build_request(path, token)
    resp = await send(req)
    status = resp.status()
    body_handle = resp.consume()
    stream = Stream(body_handle)
    chunks: list[bytes] = []
    while True:
        chunk = await stream.next()
        if chunk is None:
            break
        chunks.append(chunk)
    payload = b"".join(chunks)
    if not (200 <= status < 300):
        snippet = payload[:200].decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {status}: {snippet}")
    return json.loads(payload)


def _run(coro):
    """Drive a coroutine to completion on a fresh PollLoop."""
    loop = PollLoop()
    asyncio.set_event_loop(loop)
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()


class Api(ApiBase):
    def get_user(self, login: str, token: Optional[str]) -> api_types.UserInfo:
        data = _run(_fetch_json(f"/users/{login}", token))
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

    def get_repo(self, owner: str, repo: str, token: Optional[str]) -> api_types.RepoInfo:
        data = _run(_fetch_json(f"/repos/{owner}/{repo}", token))
        return api_types.RepoInfo(
            full_name=data["full_name"],
            description=data.get("description"),
            stargazers_count=data["stargazers_count"],
            forks_count=data["forks_count"],
            language=data.get("language"),
            default_branch=data["default_branch"],
            html_url=data["html_url"],
        )
