# Contract-Aware JSON-RPC Batch Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let an OpenRPC document build a validated JSON-RPC batch from named and positional method calls.

**Architecture:** Add typed `BatchCall`/`RequestParams` values and a pure `Document::build_batch` operation. Reuse the existing request validators and prefix their diagnostics with the batch index; reject empty batches, unknown methods, and duplicate ids before producing a JSON array.

**Tech Stack:** MoonBit standard `Json`, `Map`, `Array`, `Result`, and `wasm-gc` tests.

---

### Task 1: Define mixed batch behavior with a failing test

**Files:** `openrpc_test.mbt`

Write a test that builds a two-call batch using one named and one positional call, then asserts both request envelopes are present in order. Run `moon test --target wasm-gc`; record the missing batch API/type failure.

### Task 2: Implement batch entries and composition

**Files:** `openrpc.mbt`

Add `RequestParams`, `BatchCall`, and diagnostic codes for empty batches, unknown methods, and duplicate ids. Implement `Document::build_batch`, reuse request validation, and emit a JSON array of regular request objects.

### Task 3: Add batch boundary regression coverage

**Files:** `openrpc_test.mbt`

Cover empty input, unknown method names, duplicate ids, and indexed missing/unknown/arity diagnostics. Assert that mixed named/positional order and request ids are preserved. Run formatting and the complete wasm-gc suite.

### Task 4: Document and integrate

**Files:** `README.md`, `docs/plans/2026-09-14-batch-requests-design.md`, this plan

Document the contract-aware batch API and its deliberate exclusion of notifications and transports. Commit the design/plan with the implementation history, push the branch, open a PR linked to Issue #13, wait for push and PR CI, and merge only after all checks pass.
