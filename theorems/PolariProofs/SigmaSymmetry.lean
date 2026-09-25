import Mathlib.Algebra.BigOperators.Fin
import Mathlib.Algebra.Ring.Defs

/-!
# σ = C:ε preserves symmetry — in GENERAL rank (D-pf-10 (a))

POLARI_STATEMENT_HASH defe1b5079bbcc673b96cc3ce465511cc405c54d603f9015f8ff14e86d000e73
POLARI_TERM {"symbolic":{"args":{"n":"any"},"template":"symmetry-of-contraction"}}

The framework's SymPy tier checks this over free symbols in 2-D (12 symbols) and 3-D (42 symbols); this file proves it
for every dimension `n`, over any commutative semiring: if the stiffness `C` has the minor symmetry in its first index
pair (`C i j k l = C j i k l`) then `σ i j = ∑ k l, C i j k l * ε k l` is symmetric — the second minor symmetry and ε's
symmetry are not even needed for THIS conclusion (they matter for the inverse map), which the term's LaTeX reading
over-assumes; the proof states the exact hypothesis it uses.
-/

namespace PolariProofs

open Finset

variable {R : Type*} [CommSemiring R] {n : ℕ}

/-- σ_ij = Σ_k Σ_l C_ijkl ε_kl — the named contraction the tensormath operator `stress-from-strain` performs. -/
def sigma (C : Fin n → Fin n → Fin n → Fin n → R) (ε : Fin n → Fin n → R) (i j : Fin n) : R :=
  ∑ k : Fin n, ∑ l : Fin n, C i j k l * ε k l

/-- If C is symmetric in its first index pair, σ is symmetric — for every n. -/
theorem sigma_symm (C : Fin n → Fin n → Fin n → Fin n → R) (ε : Fin n → Fin n → R)
    (hC : ∀ i j k l, C i j k l = C j i k l) (i j : Fin n) :
    sigma C ε i j = sigma C ε j i := by
  unfold sigma
  refine Finset.sum_congr rfl fun k _ => Finset.sum_congr rfl fun l _ => ?_
  rw [hC i j k l]

end PolariProofs
