# Mooncakes publication checklist

The module metadata is ready for publication as `zmjknn/openrpc`:

- `moon.mod` declares the module name, version, README, repository, license,
  keywords, and description;
- `LICENSE` contains the Apache-2.0 text;
- the package builds and tests on `wasm-gc`;
- the quickstart executable consumes the library API from a child package.

Publication requires the maintainer's Mooncakes account and must never place a
token in the repository. Run the following locally after authenticating with
the account that owns the `zmjknn` namespace:

```text
moon login
moon whoami
moon package
moon publish
```

Before publishing, verify the package contents and version. Bump `version` in
`moon.mod` for every subsequent release and record the resulting Mooncakes
version in the release notes. CI validates the package build, but publication
is intentionally a maintainer-controlled release action.
