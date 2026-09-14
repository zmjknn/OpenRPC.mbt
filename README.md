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
- Rejects missing required parameters and names that are not declared by the method before a request is sent.
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

The result is a JSON-RPC 2.0 envelope with an object-valued `params` field. This milestone intentionally accepts named parameters only; positional encoding, schema-value validation, and transport dispatch remain separate concerns.

## Deliberate boundary

The current milestone stabilizes the document model, diagnostics, and a transport-free request boundary before adding code generation. Schema values are kept as JSON instead of pretending to be a complete JSON Schema engine. Transport, `$ref` loading from the network, positional parameter encoding, and a web editor are not part of this package's current contract. Future work can build on the parsed model without duplicating those concerns.

## Development

The public history follows the project workflow: Issue, feature branch, failing test, implementation, regression test, pull request, CI, and merge.

```text
moon fmt
moon test --target wasm-gc
```

The repository is maintained by `zmjknn` for the MoonBit September 2026 hackathon.
