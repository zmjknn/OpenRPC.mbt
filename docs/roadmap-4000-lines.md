# OpenRPC.mbt Meaningful Expansion Roadmap

The repository is expanding toward more than 4,000 maintained lines across implementation, tests, examples, and design records. The target excludes `_build` artifacts and generated caches; every line must support a documented behavior or its verification.

## Milestones

| Milestone | Scope | Evidence |
| --- | --- | --- |
| 1 | Portable JSON Schema subset and opt-in contract validation | Issue #15 / PR #16, focused recursive evaluator and fixtures |
| 2 | Batch response correlation by request id | Issue #17 / PR #17, indexed success/error/missing/duplicate response diagnostics |
| 3 | OpenRPC metadata, examples, servers, and component references | Parsed discovery data without transport coupling |
| 4 | Contract linter and reusable conformance fixtures | Stable lint rules, golden JSON fixtures, CI matrix |

The implementation is deliberately split into reviewable PRs. Tests and examples count toward the target only when they exercise real behavior; no placeholder modules or repeated boilerplate are planned.
