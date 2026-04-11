# User Journeys

## Who is served

| Actor | Goal |
|-------|------|
| Project owner | Associate their project with an ENS name for branding |
| Frontend client | Resolve a project's verified ENS handle for display |
| New owner | Re-associate a project after ownership transfer |
| Auditor | Verify the two-way verification model is sound |

## Journey 1: Set an ENS handle

**Actor:** Project owner (or anyone)

1. Owner sets the `juicebox` text record on their ENS name (e.g., `project.jeff.eth`) to `chainId:projectId` (e.g., `10:5`) via the ENS app.
2. Owner calls `setEnsNamePartsFor(chainId: 10, projectId: 5, parts: ["project", "jeff"])` on `JBProjectHandles` on Ethereum mainnet.
3. The contract validates that no parts are empty or contain dots, then stores the parts keyed by `(chainId, projectId, msg.sender)`.

**Result:** The reverse record is stored. Verification happens when `handleOf` is called.

## Journey 2: Resolve a verified handle

**Actor:** Frontend client

1. Client calls `handleOf(chainId: 10, projectId: 5, setter: ownerAddress)`.
2. Contract retrieves stored name parts for that key.
3. Contract computes the EIP-137 namehash and queries the ENS registry for a resolver.
4. Contract queries the resolver's `text(namehash, "juicebox")` record.
5. Contract compares the text record against `"10:5"`.
6. If matched, returns the formatted handle (e.g., `"project.jeff.eth"`). Otherwise returns `""`.

**Result:** Client displays the verified handle or falls back to showing the project ID.

## Journey 3: Handle ownership transfer

**Actor:** New project owner

1. Project ownership changes (the NFT transfers to a new address).
2. The old owner's handle record still exists but frontends pass the new owner's address as `setter`.
3. `handleOf` returns `""` because the new owner hasn't set name parts yet.
4. New owner calls `setEnsNamePartsFor` to associate the same or different ENS name.
5. New owner also updates the ENS text record if needed.

**Result:** Handle resolves under the new owner.

## Hand-offs

- **ENS app:** For setting text records (upstream of this contract).
- **JBProjects:** For determining who the "current owner" is that frontends should pass as `setter`.
- **Frontend clients:** Consume `handleOf` and decide which `setter` address to query.
