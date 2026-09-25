# polari-proof-tools — the Lean 4 tier of Polari's `mathproofs` module

One pinned Lean 4 (`lean-toolchain`), Mathlib at one pinned commit (`lakefile.toml` + `lake-manifest.json`), the
compiled oleans cached in the image, the theorems the framework's MathClaims cite, and an engines WORKER
(`proof_engines_service.py`, :9810) so the checker runs on whatever device the topology assigns
(`pol allocate mathproofs.engines <instance>`) while the core keeps the rows.

    docker build -t polari-proof-tools:noble .          # big once (Mathlib's cache); every later check takes seconds
    docker run --rm polari-proof-tools:noble flows/check.sh theorems/PolariProofs/SigmaSymmetry.lean
    # as the worker: (cd .. && docker compose -p proof-engines -f docker-compose.proof-engines.yml up -d --build)

The bridge between a claim and its certificate is the `statement_hash`: each theorem file's header carries the JSON
term it proves, verbatim, and that term's sha256; the worker reports `hash_matches`, and the framework's lean tier
only writes `proved` when the hash it holds is the one the file cites. The framework never runs Lean on its own
(plan §I.9): a person or the pipeline asks (`POST /api/mathproofs/claims/{name}/check?tier=lean`).

Theorems (D-pf-10): `SigmaSymmetry` — σ = C:ε is symmetric in every rank n given C's first minor symmetry;
`ChainComposition` — pairwise domain inclusion along a chain gives validity on the last domain, which is the
intersection; `RestrictionIdempotent` — the toolchain smoke test. Licences: LICENSES.md.
