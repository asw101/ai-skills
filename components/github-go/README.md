# github-go

Go (TinyGo wasip2) implementation of the local:github component.

> **Status: pinned to WASI 0.2.** TinyGo 0.41 has no `wasip3` build target,
> so even though `wit-bindgen-go` can emit p3 bindings, there's no toolchain
> to compile them through. Re-evaluate when TinyGo gains a `wasip3` target.
> The Rust and Python siblings have already moved to WASI 0.3 — see
> [`../github-rs/README.md`](../github-rs/README.md#per-language-quirks).

See [`../github-rs/README.md`](../github-rs/README.md) for the cross-language
overview, the shared WIT, and build/run instructions.
