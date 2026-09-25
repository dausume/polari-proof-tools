# polari-proof-tools — licence ledger

Polari is GPLv3 ([[project-license-gplv3]]). Everything in this image is a TOOL the framework invokes as a separate
process (`lake env lean <file>` through `flows/check.sh`, behind the worker's HTTP API); nothing is linked into Polari
and nothing is vendored into a Polari repo. The `.lean` files under `theorems/` are OURS (GPLv3, like the rest of the
suite); they `import` Mathlib the way a C program includes a header of a permissively-licensed library. Verified
2026-09-25 against the upstream LICENSE files.

| Component | Version / pin | Licence | Verified where | Verdict |
|---|---|---|---|---|
| elan | latest at build (`elan-init.sh`) | Apache-2.0 OR MIT | leanprover/elan LICENSE-APACHE / LICENSE-MIT | tool — fine |
| Lean 4 | `lean-toolchain` = leanprover/lean4:v4.34.1 (stable, 2026-09-24) | Apache-2.0 | leanprover/lean4 LICENSE | tool — fine; one-way compatible into GPLv3 |
| Mathlib | commit d13f23b723b8a846827a245b89c10fc7d3f11612 (tag v4.34.1), in `lake-manifest.json` | Apache-2.0 | leanprover-community/mathlib4 LICENSE | library imported by our theorem files; compatible into GPLv3 |
| Mathlib's transitive lake deps (batteries, aesop, Qq, proofwidgets, importGraph, LeanSearchClient, plausible, Cli) | as pinned by Mathlib's manifest | Apache-2.0 (all) | each repo's LICENSE | libraries — fine |
| falcon, gunicorn | PyPI latest at build | Apache-2.0 / MIT | PyPI metadata | the worker's HTTP layer — fine |
| Ubuntu 24.04 base | noble | various (Ubuntu) | — | base image |

Policy (D-pf-11, ratified 2026-09-24): track stable Lean releases; bump `lean-toolchain` + the Mathlib rev together,
deliberately, with every theorem re-checked in the same commit (the image build fails otherwise); never float.
