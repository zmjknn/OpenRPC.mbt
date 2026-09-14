# Contract-Aware JSON-RPC Batch Design

## Context

The package can now build named and positional requests, notifications, and response values one call at a time. A caller that wants to batch calls still has to resolve method names, select the encoding, and keep request ids unique by hand. The useful gap is contract-aware composition, not another generic JSON-RPC message codec.

## Options considered

1. **Expose a raw array helper.** This would simply wrap already-built JSON values and provide no OpenRPC validation or method lookup.
2. **Add `Document::build_batch` with typed call entries (recommended).** Each entry carries a request id, method name, and explicit named/positional arguments. The document resolves the method, reuses its validators, prefixes diagnostics with the batch index, and rejects ambiguous ids before emitting the array.
3. **Include notifications in the same batch entry type.** JSON-RPC permits them, but mixing response-bearing calls and one-way notifications would complicate the result association API. Notifications remain an explicit separate path for now.

## Selected architecture

Expose `RequestParams` with `Named(Map[String, Json])` and `Positional(Array[Json])`, plus `BatchCall { id : Json, method : String, params : RequestParams }`. `Document::build_batch(calls)` rejects an empty list, resolves each method by name, checks duplicate ids with JSON structural equality, then emits a JSON array of regular request envelopes. Existing builders remain the source of envelope shape; private validation helpers accept a batch path prefix so an error such as `$.params.id` becomes `$[1].params.id`.

## Boundaries

The batch builder performs no I/O, does not include notifications, and does not evaluate schemas. It returns the first actionable diagnostic to match the library's existing parser/builders. Tests cover mixed encodings, method lookup failures, duplicate ids, empty batches, and indexed parameter diagnostics on `wasm-gc`.
