# Portable OpenRPC Schema Validation Design

## Context

The OpenRPC parser intentionally keeps parameter and result schemas as raw JSON. That keeps the contract model small, but it leaves a practical gap: a caller cannot ask the same contract to validate a request value or returned result. The next milestone adds an opt-in validator without turning the package into a transport client or pretending to implement every JSON Schema draft feature.

## Options considered

1. **Depend on an external JSON Schema package.** This would reduce local code, but adds a registry dependency and target constraints that are not yet stable in the MoonBit ecosystem.
2. **Implement a small pure validator over `Json` (recommended).** A focused subset covers the OpenRPC examples most callers need, remains portable to `wasm-gc`, and can report paths in the same `Diagnostic` type. Unknown keywords remain ignored according to JSON Schema's extension model and are listed as a deliberate non-goal.
3. **Generate typed validators from schemas.** This could be faster at runtime, but requires code generation, a schema AST, and a new build workflow before the runtime semantics are proven.

## Selected architecture

Add `validate_schema(value, schema)` plus an internal path-aware recursive evaluator. Boolean schemas support unconditional acceptance/rejection. Object schemas handle `type`, `required`, `properties`, `additionalProperties`, and property count bounds; arrays handle `items` and item count bounds; strings handle length bounds; numbers handle minimum/maximum and exclusive bounds. `enum`, `const`, and `allOf`/`anyOf`/`oneOf`/`not` provide reusable composition. Numeric checks use JSON's `Double` representation and distinguish integer values with truncation.

Expose `Parameter::validate(value)` and `Method::validate_named_params`/`validate_positional_params` as opt-in APIs. Existing request and notification builders continue to validate presence and arity only, so callers choose when schema enforcement is appropriate. Every failure identifies the instance path and the violated keyword.

## Boundaries

The validator does not perform `$ref` resolution, regex `pattern`, `format`, external loading, defaults, coercion, or network I/O. Unsupported keywords are ignored rather than guessed at, and the README lists this boundary explicitly. Tests exercise nested objects/arrays, compositions, numeric edge cases, and method parameter integration on `wasm-gc`.
