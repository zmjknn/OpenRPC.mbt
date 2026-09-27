# OpenRPC.mbt

OpenRPC document modeling and validation for MoonBit.

Language: **MoonBit** · License: **Apache-2.0** · Package: `zmjknn/openrpc`

[![verify](https://github.com/zmjknn/OpenRPC.mbt/actions/workflows/verify.yml/badge.svg)](https://github.com/zmjknn/OpenRPC.mbt/actions/workflows/verify.yml)

This project fills a narrow gap between a JSON-RPC transport and an application: a service can publish an OpenRPC document, and MoonBit code can parse it into a typed contract with diagnostics that point back to the document. It is a library first; it does not replace JSON-RPC transports or MCP runtimes.

## What works today

- Parses OpenRPC 1.x document metadata, including tags, servers, server variables, method summaries, and examples.
- Preserves reusable schemas, examples, pairings, content descriptors, errors, links, and tags under components.
- Resolves local JSON Pointer references in method, parameter, result, tag, and example entries.
- Validates parameter and result schemas that use nested local component references.
- Validates parameter, result, and pairing examples against their declared schemas.
- Expands declared server URL variables using caller overrides or defaults and enforces enum values.
- Compares two parsed documents and classifies method, parameter, result, server, tag, and component changes.
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
- Builds contract-aware JSON-RPC batches from named or positional calls, checking method names and unique request ids.
- Decodes a JSON-RPC 2.0 response for an expected request id into a raw result or structured error.
- Correlates JSON-RPC batch responses with the original calls, reorders them deterministically, and preserves per-method result/error records.
- Rejects malformed response envelopes, mismatched ids, and invalid error objects with JSON-style diagnostics.
- Provides a pure, portable JSON Schema subset validator for boolean schemas, primitive `type`, `enum`, `const`, object properties, arrays, string and numeric bounds, and `allOf`/`anyOf`/`oneOf`/`not` composition.
- Exposes opt-in `Parameter::validate`, `Method::validate_named_params`, `Method::validate_positional_params`, `Method::validate_result`, and `ResultDescriptor::validate` helpers with stable JSON-style paths.
- Lints parsed contracts for empty names, duplicate parameters, ambiguous positional ordering, malformed or contradictory schema boundaries, and invalid nested composition.
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

## Install from Mooncakes

After the maintainer publishes a release, add the module to a MoonBit project:

```text
moon add zmjknn/openrpc
```

Then import it as `@openrpc` as shown above. The repository quickstart can be run
before publication with `moon run examples/quickstart --target wasm-gc`.

## Runnable quickstart

The repository includes an executable consumer under `examples/quickstart`.
Run it from the repository root:

```text
moon run examples/quickstart --target wasm-gc
```

Expected output:

```text
method=inventory.get, server=https://dev.inventory.example/rpc, request={"jsonrpc":"2.0","id":7,"method":"inventory.get","params":{"id":"abc"}}
```

The same contract is exercised by `submission_readiness_test.mbt`, so the
README example and the library behavior are tested together.

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

Schema validation is explicit when an application wants a contract check at its boundary:

```moonbit
let params : Map[String, Json] = {"id": "abc"}
match method_value.validate_named_params(params) {
  Ok(_) => println("parameters satisfy the OpenRPC schemas")
  Err(diagnostics) => println(diagnostics[0].path + ": " + diagnostics[0].message)
}
```

The validator intentionally covers a portable JSON Schema subset. Document-aware validation resolves local references, including references nested below object properties and composition keywords. Circular references are reported during value validation. The library does not load external schemas, evaluate regular-expression `pattern` or `format`, coerce values, or apply defaults. Request builders remain schema-agnostic unless one of the opt-in validation helpers is called.

For component-backed schemas, validate through the parsed document:

```moonbit
match document.validate_named_params("inventory.get", {"id": "abc"}) {
  Ok(_) => println("parameters satisfy the referenced schemas")
  Err(diagnostics) => println(diagnostics[0].path + ": " + diagnostics[0].message)
}
```

Server URL variables can be expanded without opening a connection:

```moonbit
match document.find_server("primary") {
  Some(server) =>
    match server.render_url({"region": "staging"}) {
      Ok(url) => println(url)
      Err(diagnostics) => println(diagnostics[0].message)
    }
  None => println("server is not declared")
}
```

Use `Document::diff` to compare revisions. Each change includes a path, kind, and compatibility impact. `Document::resolve_ref` resolves local JSON Pointers such as `#/components/schemas/Item`; external URLs are rejected, and the library never reads files or performs network requests.

Run the semantic pass after parsing when a document is being published or registered:

```moonbit
let diagnostics = document.lint()
for diagnostic in diagnostics {
  println(diagnostic.path + ": " + diagnostic.message)
}
```

Linting is deterministic and non-mutating. It catches duplicate parameter names, a required positional parameter after an optional one, empty declaration names, and contradictory or malformed bounds below nested `properties`, `items`, and composition schemas.

For one-way calls, use a notification builder; it intentionally emits no `id` and therefore has no response to decode:

```moonbit
let notification = method_value.build_notification({"scope": "all"})
```

For several response-bearing calls, let the document resolve each method and compose one batch:

```moonbit
let calls : Array[@openrpc.BatchCall] = [
  @openrpc.BatchCall::new(
    1,
    "inventory.get",
    @openrpc.RequestParams::named({"id": "abc"}),
  ),
]
let batch = document.build_batch(calls)
```

Batch diagnostics include the failing call index, and duplicate request ids are rejected before the JSON array is emitted. Notifications remain a separate API because they do not participate in response matching.

When a server returns a batch, pass the original calls back to the document to correlate out-of-order responses:

```moonbit
match document.decode_batch_response(response, calls) {
  Ok(values) => {
    for value in values {
      println(value.method_name)
    }
  }
  Err(diagnostics) => println(diagnostics[0].path + ": " + diagnostics[0].message)
}
```

The correlator reports unknown, duplicate, and missing ids before returning a partial result. It delegates each envelope to `Method::decode_response`, so single-response and batch-response validation share the same JSON-RPC rules.

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

## Repository structure

The implementation boundaries and package layout are documented in
[`docs/architecture.md`](docs/architecture.md). The parser and message model
live in `openrpc.mbt`; metadata parsing, local reference resolution, contract
diffs, schema validation, and semantic linting are separated into focused
modules. The quickstart demonstrates a separate executable consumer.

## Deliberate boundary

The library covers the document model, local reference resolution, semantic linting, schema validation, contract comparison, and transport-free request/response/notification/batch boundaries. It does not open sockets, load remote files, generate SDK code, or provide a web editor.

## Development

The public history follows the project workflow: Issue, feature branch, failing test, implementation, regression test, pull request, CI, and merge.

```text
moon fmt --check
moon check --target wasm-gc
moon build --target wasm-gc
moon test --target wasm-gc
moon run examples/quickstart --target wasm-gc
```

GitHub Actions runs the same format, check, build, test, and quickstart steps.
The public development record is maintained by `zmjknn` through Issues,
feature branches, failing tests, implementation commits, PR review, CI, and
merge.

## Mooncakes publication

The module metadata and package contents are prepared for Mooncakes. The
maintainer-controlled login and publish steps are documented in
[`docs/mooncakes-publish.md`](docs/mooncakes-publish.md); no credential is
stored in this repository.

The repository is maintained by `zmjknn` for the MoonBit September 2026 hackathon.
