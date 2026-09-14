# OpenRPC.mbt

OpenRPC document modeling and validation for MoonBit.

This project fills a narrow gap between a JSON-RPC transport and an application: a service can publish an OpenRPC document, and MoonBit code can parse it into a typed contract with diagnostics that point back to the document. It is a library first; it does not replace JSON-RPC transports or MCP runtimes.

## What works today

- Parses JSON into the required OpenRPC document, `info`, and method metadata.
- Accepts OpenRPC 1.x documents and rejects other major versions.
- Reports invalid JSON, missing fields, wrong field types, and non-object methods with JSON-style paths.
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

## Deliberate boundary

The first milestone stabilizes the document model and diagnostics before adding code generation. Transport, complete JSON Schema evaluation, `$ref` loading from the network, and a web editor are not part of this package's current contract. Future work can build on the parsed model without duplicating those concerns.

## Development

The public history follows the project workflow: Issue, feature branch, failing test, implementation, regression test, pull request, CI, and merge.

```text
moon fmt
moon test --target wasm-gc
```

The repository is maintained by `zmjknn` for the MoonBit September 2026 hackathon.
