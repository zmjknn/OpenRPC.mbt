# OpenRPC.mbt architecture

## Scope

OpenRPC.mbt is a MoonBit library for the contract boundary around JSON-RPC.
It parses OpenRPC documents, builds and checks messages, and reports precise
diagnostics. It deliberately does not open sockets, dispatch transports, or
load remote references.

## Source layout

| Path | Responsibility |
| --- | --- |
| `openrpc.mbt` | OpenRPC model, parser, request builders, response decoders |
| `schema.mbt` | Portable JSON Schema subset evaluator |
| `lint.mbt` | Semantic contract lint pass |
| `*_test.mbt` | Focused parser, message, schema, batch, lint, and example tests |
| `example_contract.mbt` | Reusable quickstart fixture and summary |
| `examples/quickstart` | Executable MoonBit consumer of the published package API |
| `docs/plans` | Design decisions and implementation records |
| `.github/workflows` | Reproducible format, check, build, test, and example CI |

## Data flow

```text
OpenRPC JSON
    -> Document::parse
    -> Method lookup
    -> request / notification / batch builder
    -> transport owned by the application
    -> single or batch response decoder
    -> optional result-schema validation
```

`Document::lint` is an independent pre-publication pass. It checks semantic
problems that require the whole declaration context, while the builders stay
schema-agnostic and reusable at runtime.

## Portability boundary

The library depends only on MoonBit core JSON facilities. No network, file
system, native FFI, or platform-specific runtime is required by the library or
the quickstart. CI uses `wasm-gc` for the reproducible build and test target.
