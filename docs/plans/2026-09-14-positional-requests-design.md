# Ordered Positional Request Design

## Context

OpenRPC parameter descriptors are ordered, and the parser already preserves that order. The library can currently build only named-parameter request objects, so a caller using positional JSON-RPC has to duplicate the contract's arity rules. The missing capability belongs at the same pure contract boundary as `Method::build_request`.

## Options considered

1. **Replace the existing builder with a sum-typed parameter mode.** This would make one entry point cover both encodings, but it would complicate a stable API and force callers to construct a mode value for the current named case.
2. **Add a dedicated `Method::build_positional_request` (recommended).** It preserves the named builder, uses the method's source order directly, and gives positional arity its own diagnostics. The two JSON-RPC encodings remain explicit at call sites.
3. **Expose only a raw array encoder.** This is small but abandons the contract's required/optional information and recreates validation in every caller.

## Selected architecture

`Method::build_positional_request(id, values)` returns a JSON-RPC 2.0 object whose `params` is a JSON array. It accepts a prefix of the declared parameter list, so omitted parameters must be trailing and optional. If more values than declarations are supplied, it returns `TooManyParameters`; if the first omitted declaration is required, it returns `MissingParameter` at that parameter's positional path. Existing named construction and response decoding remain unchanged.

## Boundaries

The builder performs no transport I/O and no schema-value evaluation. It does not invent defaults for omitted optional parameters, and it does not allow holes in the positional array. Tests cover ordered values, optional suffixes, required omissions, and excess values on `wasm-gc`.
