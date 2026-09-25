import Mathlib.Order.Monotone.Basic
import Mathlib.Data.Set.Lattice.Indexed
import Mathlib.Order.Interval.Finset.Nat

/-!
# The tree-composition lemma (D-pf-10 (b))

POLARI_STATEMENT_HASH b218dce74b478c9931760c6db515f18165a698cca4c762201852b56d5ea2bf36
POLARI_TERM {"symbolic":{"args":{"links":"any"},"template":"chain-domains-compose"}}

A chain of mappings m₀ → m₁ → … → mₙ through a TensorTree is legitimate where every link's validity domain lies inside
the previous link's (the `chain-domain-inclusion` rule demands exactly this pairwise, and the interval / z3 tiers
decide each pair). This lemma is what makes the PAIRWISE obligations sufficient: if `V (i+1) ⊆ V i` for every link,
then the whole chain is valid on the LAST link's domain, and that domain IS the intersection of all of them — nothing
is lost by checking neighbours only. Stated over any type `α` (a validity domain is a set of points of the state space;
the interval boxes are one instance).
-/

namespace PolariProofs

variable {α : Type*}

/-- Pairwise inclusion along the chain gives inclusion across any span: `V j ⊆ V i` whenever `i ≤ j`. -/
theorem chain_subset_of_le (V : ℕ → Set α) (h : ∀ i, V (i + 1) ⊆ V i) {i j : ℕ} (hij : i ≤ j) :
    V j ⊆ V i :=
  antitone_nat_of_succ_le h hij

/-- The chain m₀ … mₙ is valid on the last link's domain: `V n` lies inside every link's domain. -/
theorem chain_valid_on_last (V : ℕ → Set α) (h : ∀ i, V (i + 1) ⊆ V i) (n : ℕ) :
    ∀ i ≤ n, V n ⊆ V i :=
  fun _ hi => chain_subset_of_le V h hi

/-- …and that domain is exactly the intersection of all the links' domains — pairwise checks lose nothing. -/
theorem chain_inter_eq_last (V : ℕ → Set α) (h : ∀ i, V (i + 1) ⊆ V i) (n : ℕ) :
    (⋂ i ∈ Finset.range (n + 1), V i) = V n := by
  apply Set.Subset.antisymm
  · exact Set.biInter_subset_of_mem (Finset.mem_range.mpr (Nat.lt_succ_self n))
  · exact Set.subset_iInter₂ fun i hi => chain_subset_of_le V h (Nat.lt_succ_iff.mp (Finset.mem_range.mp hi))

end PolariProofs
