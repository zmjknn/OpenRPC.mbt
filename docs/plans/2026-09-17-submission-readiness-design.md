# Submission readiness design

The hackathon checklist is treated as an acceptance contract for the
repository, not as a reason to add unrelated product features.

## Evidence map

| Requirement | Repository evidence |
| --- | --- |
| MoonBit implementation | `moon.mod`, `.mbt` sources, MoonBit CI commands |
| Public history | GitHub Issues, branches, commits, PRs, and CI checks |
| Clear source structure | `docs/architecture.md` and focused root modules |
| Reproducible README | quickstart command and expected output |
| Continuous integration | format, check, wasm-gc build, tests, and example run |
| Runnable sample | root `moon run . --target wasm-gc` entry point |
| Core-path tests | parser, builders, responses, schema, lint, and example tests |
| Mooncakes readiness | package metadata, publish checklist, and dry-run validation |
| OSI license | Apache-2.0 metadata and `LICENSE` text |

The example uses the library in-process and does not pretend to be a network
server. It demonstrates the smallest useful path: parse a contract, lint it,
find a method, and build a JSON-RPC request.
