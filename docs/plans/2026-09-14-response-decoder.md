# Contract-Aware JSON-RPC Response Decoder Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let a parsed OpenRPC method decode a JSON-RPC 2.0 response for an expected request id into either a raw result or a structured RPC error.

**Architecture:** Keep response decoding as a pure operation on `Method`. Validate only the JSON-RPC envelope and error shape; leave result schemas opaque and transport dispatch to callers. Reuse the existing path-aware `Diagnostic` surface with dedicated response diagnostics.

**Tech Stack:** MoonBit standard `Json`, `Map`, `Result`, and `wasm-gc` tests.

---

### Task 1: Define the success response contract with a failing test

**Files:** `openrpc_test.mbt`

Write a test that parses a method, decodes a JSON-RPC 2.0 response with the expected id and a result value, and asserts the result is returned. Run `moon test --target wasm-gc`; record the missing response API failure.

### Task 2: Implement response envelope types and success decoding

**Files:** `openrpc.mbt`

Add public `RpcError` and `RpcResponse` types, response-related diagnostic codes, and `Method::decode_response(response, request_id)`. Validate the protocol version, compare ids with `Json::equal`, and return the raw result when present.

### Task 3: Add structured error decoding

**Files:** `openrpc_test.mbt`, `openrpc.mbt`

Add a failing regression test for an error response with integer code, message, and optional data. Implement the error-object path while preserving raw JSON data.

### Task 4: Cover malformed and ambiguous envelopes

**Files:** `openrpc_test.mbt`

Cover id mismatch, missing both `result` and `error`, both fields present, invalid error code/message, and a `null` success result. Assert diagnostic paths and codes. Run formatting and the full wasm-gc test suite.

### Task 5: Document and integrate

**Files:** `README.md`, `docs/plans/2026-09-14-response-decoder-design.md`, this plan

Document the contract-aware, transport-free response boundary and its non-goals. Commit the design/plan with the implementation history, push the branch, open a PR linked to Issue #7, wait for push and PR CI, and merge only after all checks are successful.
