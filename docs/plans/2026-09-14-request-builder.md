# Validated JSON-RPC Request Builder Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let a parsed OpenRPC method construct a named-parameter JSON-RPC 2.0 request while checking required and unknown parameters.

**Architecture:** Keep request construction as a pure operation on `Method`; it returns a `Json` value and never opens a socket or chooses a transport. Parameter definitions remain the source of truth for presence checks, while schemas stay opaque JSON values until a separate schema-focused design exists.

**Tech Stack:** MoonBit standard `Json`, immutable contract values, `Result` diagnostics, and wasm-gc tests.

---

### Task 1: Define request behavior with a failing test

**Files:** `openrpc_test.mbt`

Write a test that parses a method with one required parameter and asks it to build a request. Assert that the JSON-RPC envelope and named parameter object are present. Run `moon test --target wasm-gc` and record the missing API failure.

### Task 2: Implement the pure request builder

**Files:** `openrpc.mbt`

Add `Method::build_request(id, params)` and diagnostics for missing required and unknown parameter names. Construct the envelope with `jsonrpc = "2.0"`, the caller-provided id, the method name, and a JSON object of named parameters. Preserve the existing parser API.

### Task 3: Add regression coverage

**Files:** `openrpc_test.mbt`

Cover required-parameter failure, unknown-parameter failure, and the empty-parameter request. Run formatting and all tests.

### Task 4: Document and integrate

**Files:** `README.md`, this plan

Document the transport-free request boundary and the intentional named-parameter limitation. Push the feature branch, open a PR linked to Issue #5, wait for both CI events, and merge with the full commit history if the PR is clean.
