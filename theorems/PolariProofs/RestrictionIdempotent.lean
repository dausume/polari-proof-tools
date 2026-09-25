import Mathlib.Tactic.SplitIfs

/-!
# Restriction is idempotent (D-pf-10 (c) — the toolchain smoke test)

POLARI_STATEMENT_HASH f0e4d1d836199af6b30aaedb9969aa01099bac34982541b34b78bd75a83a2631
POLARI_TERM {"symbolic":{"args":{},"template":"restriction-idempotent"}}

The `restriction-idempotent` rule's obligation, which SymPy checks for a fixed index range: an index restriction `R`
(keep the entries whose index satisfies `p`, zero the rest) applied twice is `R` applied once. Trivial by design — its
job is to prove the toolchain (elan → the pinned Lean → the pinned Mathlib → `flows/check.sh` → the worker) end to end.
-/

namespace PolariProofs

variable {ι α : Type*} [Zero α]

/-- An index-range restriction: keep `T i` where `p i`, else 0. -/
def restrict (p : ι → Prop) [DecidablePred p] (T : ι → α) : ι → α :=
  fun i => if p i then T i else 0

theorem restrict_idempotent (p : ι → Prop) [DecidablePred p] (T : ι → α) :
    restrict p (restrict p T) = restrict p T := by
  funext i
  unfold restrict
  split_ifs <;> rfl

end PolariProofs
