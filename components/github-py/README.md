# github-py

Python (componentize-py) implementation of the local:github component, on
**WASI 0.3** (`wasi:http@0.3.0-rc-2026-03-15`). Exports `get-user` and
`get-repo` as `async func` and consumes the response body via the new
`stream<u8>` body API.

See [`../github-rs/README.md`](../github-rs/README.md) for the cross-language
overview, the shared WIT, and build/run instructions.
