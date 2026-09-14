# Contract-Aware JSON-RPC Notification Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let a parsed OpenRPC method build named and positional JSON-RPC 2.0 notifications without duplicating parameter validation.

**Architecture:** Add explicit pure notification builders beside the request builders. Extract private named/positional validation helpers and have both request and notification paths call them; notifications always omit `id` while retaining an object/array `params` field.

**Tech Stack:** MoonBit standard `Json`, `Map`, `Array`, `Result`, and `wasm-gc` tests.

---

### Task 1: Define notification behavior with a failing test

**Files:** `openrpc_test.mbt`

Write a test that parses a method, builds a named notification, and asserts `jsonrpc`, `method`, and `params` exist while `id` is absent. Run `moon test --target wasm-gc`; record the missing API failure.

### Task 2: Implement shared validation and named notifications

**Files:** `openrpc.mbt`

Extract the existing named-parameter checks into a private helper, reuse it from `build_request`, and add `build_notification(params)`. Emit an object-valued `params` field and no `id`.

### Task 3: Add positional notifications and regression coverage

**Files:** `openrpc_test.mbt`, `openrpc.mbt`

Add `build_positional_notification(values)` using the shared positional validation helper. Cover positional order, omitted trailing optionals, missing required values, excess values, and assert both notification builders reject invalid parameters like their request counterparts.

### Task 4: Document and integrate

**Files:** `README.md`, `docs/plans/2026-09-14-notifications-design.md`, this plan

Document one-way invocation and the intentional absence of `id`/response handling. Commit the design/plan with the implementation history, push the branch, open a PR linked to Issue #11, wait for push and PR CI, and merge only after all checks pass.
