# Runtime

## Core role

`JBProjectHandles` stores ENS name parts and verifies handles by querying the ENS registry. It is the "reverse record" side of a two-way ENS association for Juicebox projects.

## High-risk areas

### Setter trust

Storage is keyed by `_msgSender()`. Frontends must pass the correct `setter` (typically the project owner) to get the intended handle. Passing a wrong setter returns empty or a different handle.

### ENS dependency

`handleOf` makes external calls to the ENS registry and resolver. If these revert, handle resolution fails. This is read-only — no fund loss possible.

### Dot validation

The `setEnsNamePartsFor` function validates that no name parts contain dots. This prevents ENS injection where a single part like `"a.b"` could hash differently than two parts `["a", "b"]`.

### EIP-137 namehash

The `_namehash` function must match the EIP-137 standard exactly. An incorrect hash would cause ENS resolution to look up the wrong name.

## Tests to trust first

| Test file | What it covers |
|-----------|---------------|
| `test/JBProjectHandles.t.sol` | Fuzz tests for set/get, dot validation, handle verification, ENS mocking |
