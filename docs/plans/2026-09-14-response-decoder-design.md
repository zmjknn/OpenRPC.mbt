# Contract-Aware JSON-RPC Response Decoder Design

## Context

The library now parses an OpenRPC document and builds a named-parameter JSON-RPC request. The remaining seam is the response: a caller should not have to repeat envelope checks or accidentally consume a response for another request. The MoonBit ecosystem already contains generic JSON-RPC and MCP codecs, so this feature must stay specific to the OpenRPC contract boundary rather than become another transport client.

## Options considered

1. **Add a generic response module.** This would mirror existing JSON-RPC packages and leave method-to-response association to every caller. It offers little value for this repository.
2. **Add `Method::decode_response` (recommended).** The method receives the expected request id and a parsed JSON value, validates only the JSON-RPC envelope, and returns either the raw result or a structured error. This keeps the operation pure, makes the OpenRPC method the association point, and leaves transport and schema evaluation outside the package.
3. **Validate the result against `schema`.** This would make the API appear more complete, but it would require choosing and implementing a substantial JSON Schema subset. The current contract deliberately keeps schemas opaque, so this is deferred.

## Selected architecture

Expose `RpcError { code : Int, message : String, data : Json? }` and `RpcResponse` with `Result(Json)` and `Error(RpcError)` variants. `Method::decode_response(response, request_id)` checks an object-valued `jsonrpc` field equal to `"2.0"`, an `id` equal to the expected JSON value, and exactly one of `result` or `error`. Error objects require an integer code and string message; `data` remains optional JSON. Failures use the existing path-aware diagnostic surface with dedicated response codes.

## Boundaries

The decoder performs no I/O, does not match method names (JSON-RPC responses carry ids, not method names), and does not evaluate OpenRPC/JSON Schema values. Tests cover success values including `null`, structured errors, id mismatches, malformed envelopes, and the mutually exclusive result/error rule on the `wasm-gc` target.
