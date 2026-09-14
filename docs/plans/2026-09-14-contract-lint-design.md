# Contract lint design

## Decision

Expose `Document::lint() -> Array[Diagnostic]` as a pure semantic pass over an
already parsed document. Parsing remains responsible for JSON/OpenRPC shape;
linting reports declarations that are structurally legal but unsafe or
ambiguous for clients.

## Rules

- names must be non-empty;
- parameter names must be unique;
- a required positional parameter may not follow an optional parameter;
- schema bounds must be well-typed and internally consistent;
- composition arrays must contain at least one schema;
- nested `properties` and `items` schemas are linted recursively.

The pass returns every diagnostic in document order. It performs no network
access, code generation, coercion, or mutation, and it does not change the
schema-agnostic request builders.
