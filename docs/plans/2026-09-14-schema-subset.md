# Portable OpenRPC Schema Subset Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an opt-in JSON Schema subset validator that can validate OpenRPC parameter values without transport or code generation.

**Architecture:** Keep schemas as `Json` and evaluate them recursively with path-aware diagnostics. Expose standalone validation plus `Parameter` and `Method` helpers; preserve existing request/notification builders as schema-agnostic APIs.

**Tech Stack:** MoonBit standard `Json`, `Map`, `Array`, `Double`, `Result`, and `wasm-gc` tests.

---

### Task 1: Define primitive validation with a failing test

**Files:** `schema_test.mbt`

Write tests for a string type and a mismatched number. Run `moon test --target wasm-gc`; record the missing validator API failure.

### Task 2: Implement recursive primitive and scalar constraints

**Files:** `schema.mbt`, `openrpc.mbt`

Add the standalone validator, diagnostics, boolean schemas, `type`, `enum`, `const`, string length bounds, and numeric bounds. Add `Parameter::validate` as a thin contract adapter.

### Task 3: Implement object, array, and composition constraints

**Files:** `schema.mbt`, `schema_test.mbt`

Support `required`, `properties`, `additionalProperties`, property counts, `items`, item counts, and `allOf`/`anyOf`/`oneOf`/`not` with nested paths. Cover valid and invalid combinations.

### Task 4: Integrate method-level opt-in validation

**Files:** `openrpc.mbt`, `schema_test.mbt`

Add named and positional method validation helpers that reuse presence/arity checks and then validate supplied values against parameter schemas. Keep request and notification builders unchanged.

### Task 5: Document and integrate

**Files:** `README.md`, `docs/plans/2026-09-14-schema-subset-design.md`, this plan, `docs/roadmap-4000-lines.md`

Document supported keywords, unsupported boundaries, and opt-in usage. Commit the design/plan with the implementation history, push the branch, open a PR linked to Issue #15, wait for push and PR CI, and merge only after all checks pass.
