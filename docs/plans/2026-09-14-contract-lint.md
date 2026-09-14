# Contract lint implementation plan

1. Add failing fixtures for empty names, duplicate parameters, ambiguous
   positional declarations, contradictory bounds, malformed bound types, and
   empty composition arrays.
2. Add dedicated diagnostic codes and implement `Document::lint` with a
   document-order traversal.
3. Recurse through object properties, array item schemas, and composition
   branches while preserving JSON-style paths.
4. Add valid-contract regression fixtures and multi-diagnostic ordering tests.
5. Update the README and expansion roadmap, run formatter and wasm-gc tests,
   then verify and merge the GitHub PR.
