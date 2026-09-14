# Batch response correlation implementation plan

1. Add failing tests for empty calls, malformed response arrays, out-of-order
   result/error responses, unknown ids, duplicate ids, missing ids, and
   malformed envelopes.
2. Add a `BatchResponse` record and batch-specific diagnostic codes.
3. Implement id indexing with JSON structural equality and deterministic
   original-call ordering; delegate per-item envelope decoding to the method
   decoder.
4. Add regression tests for mixed success/error batches and response-order
   stability.
5. Update README and roadmap, run `moon fmt`, `moon test --target wasm-gc`,
   and verify the GitHub Actions check before merging.
