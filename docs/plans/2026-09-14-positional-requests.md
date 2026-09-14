# Ordered Positional JSON-RPC Request Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let a parsed OpenRPC method construct a positional JSON-RPC 2.0 request while enforcing declared order and arity.

**Architecture:** Add a dedicated pure `Method::build_positional_request` API beside the stable named builder. Treat the supplied array as a prefix of the ordered declarations, allowing only trailing optional omissions; preserve the existing diagnostic surface with a new excess-parameter code.

**Tech Stack:** MoonBit standard `Json`, `Array`, `Result`, and `wasm-gc` tests.

---

### Task 1: Define ordered request behavior with a failing test

**Files:** `openrpc_test.mbt`

Write a test that parses two ordered parameters and asks the method to build an array-valued request. Assert the JSON-RPC envelope and value order. Run `moon test --target wasm-gc`; record the missing API failure.

### Task 2: Implement positional request construction

**Files:** `openrpc.mbt`

Add `TooManyParameters` and `Method::build_positional_request(id, values)`. Reject arrays longer than the declared parameter list, reject the first omitted required declaration, and otherwise emit `jsonrpc = "2.0"`, the caller id, method name, and `Json::array(values)`.

### Task 3: Add arity regression coverage

**Files:** `openrpc_test.mbt`

Cover omitted trailing optional parameters, missing required parameters, and excess positional values. Assert diagnostic paths/codes and run formatting plus the complete wasm-gc suite.

### Task 4: Document and integrate

**Files:** `README.md`, `docs/plans/2026-09-14-positional-requests-design.md`, this plan

Document the explicit named-versus-positional request APIs and their prefix rule. Commit the design/plan with the implementation history, push the feature branch, open a PR linked to Issue #9, wait for push and PR CI, and merge only after all checks pass.
