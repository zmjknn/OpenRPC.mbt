# OpenRPC.mbt

OpenRPC document modeling and validation for MoonBit.

This project fills a narrow gap between a JSON-RPC transport and an application: a service can publish an OpenRPC document, and MoonBit code can parse it into a typed contract with diagnostics that point back to the document. It is a library first; it does not replace JSON-RPC transports or MCP runtimes.

## What works today

- Parses JSON into the required OpenRPC document, `info`, and method metadata.
- Preserves ordered parameters (`name`, `required`, and raw `schema`) and optional result descriptors.
- Accepts OpenRPC 1.x documents and rejects other major versions.
- Rejects duplicate method names and reports invalid JSON, missing fields, wrong field types, and non-object methods with JSON-style paths.
- Supports deterministic lookup with `Document::find_method`.
- Builds a JSON-RPC 2.0 request from a parsed method with the caller's request id and named parameters.
- Builds a positional JSON-RPC 2.0 request from the method's declared parameter order.
- Rejects missing required parameters and names that are not declared by the method before a request is sent.
- Rejects missing required positional parameters and excess positional values while allowing omitted trailing optional parameters.
- Builds named or positional JSON-RPC notifications that omit `id` and reuse the same contract checks.
- Decodes a JSON-RPC 2.0 response for an expected request id into a raw result or structured error.
- Rejects malformed response envelopes, mismatched ids, and invalid error objects with JSON-style diagnostics.
- Keeps the result embeddable on MoonBit targets; there is no native-only file or network dependency.

## Small example

```moonbit
import { "zmjknn/openrpc" @openrpc }

let source = #|{
  #|  "openrpc": "1.4.0",
  #|  "info": {"title": "Inventory", "version": "1.0.0"},
  #|  "methods": [{"name": "inventory.list"}]
  #|}

match @openrpc.Document::parse(source) {
  Ok(document) => println(document.methods[0].name)
  Err(diagnostics) => {
    for diagnostic in diagnostics {
      println(diagnostic.path + ": " + diagnostic.message)
    }
  }
}
```

After selecting a method, request construction stays pure and transport-agnostic:

```moonbit
let params : Map[String, Json] = {"id": "abc"}
let request = method_value.build_request(7, params)
```

The result is a JSON-RPC 2.0 envelope with an object-valued `params` field. When a server expects positional parameters, the ordered contract can be used directly:

```moonbit
let values : Array[Json] = ["abc"]
let request = method_value.build_positional_request(7, values)
```

Positional values are a prefix of the declared list, so only trailing optional parameters may be omitted. Schema-value validation and transport dispatch remain separate concerns.

For one-way calls, use a notification builder; it intentionally emits no `id` and therefore has no response to decode:

```moonbit
let notification = method_value.build_notification({"scope": "all"})
```

When a transport returns a JSON value, the same method can validate the response envelope without performing I/O:

```moonbit
match method_value.decode_response(response, 7) {
  Ok(@openrpc.RpcResponse::Result(value)) => println(value.stringify())
  Ok(@openrpc.RpcResponse::Error(error_value)) => println(error_value.message)
  Err(diagnostics) => {
    for diagnostic in diagnostics {
      println(diagnostic.path + ": " + diagnostic.message)
    }
  }
}
```

The decoder matches the request id, enforces the JSON-RPC 2.0 envelope, and preserves result/error payloads as JSON. It does not evaluate the method's opaque schema.

## Deliberate boundary

The current milestone stabilizes the document model, diagnostics, and transport-free request/response/notification boundaries before adding code generation. Schema values are kept as JSON instead of pretending to be a complete JSON Schema engine. Transport, `$ref` loading from the network, result-schema evaluation, and a web editor are not part of this package's current contract. Future work can build on the parsed model without duplicating those concerns.

## Development

The public history follows the project workflow: Issue, feature branch, failing test, implementation, regression test, pull request, CI, and merge.

```text
moon fmt
moon test --target wasm-gc
```

The repository is maintained by `zmjknn` for the MoonBit September 2026 hackathon.
