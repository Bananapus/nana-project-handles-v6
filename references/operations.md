# Operations

## Change checklist

| If you're editing... | Verify... |
|---------------------|-----------|
| `setEnsNamePartsFor` validation | Dot and empty-part rejection still works; fuzz tests pass |
| `_namehash` | Output matches EIP-137 for known ENS names; all `handleOf` tests pass |
| `_formatHandle` | Output matches expected `name.subdomain.subsubdomain` format |
| `handleOf` ENS queries | Mock calls in tests match real ENS registry/resolver interface |
| Constructor / ERC2771 | Meta-transaction `_msgSender()` still resolves correctly |

## Common failure modes

| Symptom | Likely cause |
|---------|-------------|
| `handleOf` returns empty for a valid handle | ENS text record doesn't match `chainId:projectId` format exactly |
| `handleOf` returns empty despite stored parts | ENS registry has no resolver, the resolver reverts, or the text record is missing/mismatched |
| `setEnsNamePartsFor` reverts unexpectedly | Name part contains a dot or is empty |
| Handle works for one setter but not another | Frontend is querying with wrong `setter` address |
