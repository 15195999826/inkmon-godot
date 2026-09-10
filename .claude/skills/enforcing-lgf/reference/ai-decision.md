# AI Decision API

*Location: `core/ai_decision/`.*

"One decision" as a shape — the framework fixes the pipeline (facts → candidates → choice → explanation) and its discipline, and owns **no** algorithm. Candidate generation and the selection algorithm are project code (`OptionProvider` / `Reasoner` implementations). The module has no loop, no execution, no timing, and holds no RNG (it is passed in — determinism is the caller's responsibility).

## Contents
- [DecisionSnapshot](#decisionsnapshot-extends-refcounted)
- [DecisionOption](#decisionoption-extends-refcounted)
- [OptionProvider](#optionprovider-extends-refcounted)
- [Reasoner](#reasoner-extends-refcounted)
- [DecisionResult](#decisionresult-extends-refcounted)
- [DecisionOutcome](#decisionoutcome-extends-refcounted)
- [DecisionPipeline](#decisionpipeline-static-utility)
- [GoalBacktrackReasoner](#goalbacktrackreasoner-extends-reasoner)
- [Conventions](#conventions)

## DecisionSnapshot (extends RefCounted)

The slice of the world the AI sees — the single input of one decision. Projects subclass it and add concrete fields.

**Three contracts:**
1. **Read-only** — no mutation for the whole of `DecisionPipeline.run()`.
2. **Slice, not a world copy** — size scales with what the decision needs, not with the world. Data shared by many agents should be built once by the caller and reused (shared slice + per-agent appendix).
3. **Perception ground** — "what this AI can see" *is* the subclass's construction-time filter. Vision / intel rules are project policy; adding a filter must not touch the framework.

**Methods:**
- `content_hash() -> int` — Optional. Returns `0` (base default) to opt out of the read-only check; return non-zero and `DecisionPipeline` compares it before the provider runs and after `decide()`, asserting on any change

---

## DecisionOption (extends RefCounted)

One candidate — "a thing that could be done now". A goal is just its coarse-grained form: layered decisions run the pipeline once at goal granularity and again over the concrete behaviours under the chosen goal; the framework adds no concept for that.

**Properties:**
- `id: String` — Unique; also the pipeline's deterministic sort key (a duplicate id is an assertion, not a warning)
- `payload: Dictionary` — Project payload (activity reference, skill + target pairing, ...); the framework never interprets it
- `requires: Array[Dictionary]` — Typed preconditions (e.g. `{ "type": "min_purse", "amount": 40 }`). Content is opaque to the framework; `GoalBacktrackReasoner` asks the project about them through policy hooks
- `provides: Array[String]` — Supply-side tags (e.g. `["money"]`) — what GOAP-lite backtracking matches against

**Construction:** `_init(p_id: String = "", p_payload: Dictionary = {})`

---

## OptionProvider (extends RefCounted)

Interface — lists "what is worth considering this round". Project-implemented (where candidates come from is project knowledge).

- `provide(_snapshot: DecisionSnapshot) -> Array[DecisionOption]` — Override; the base asserts

**Contract:** the returned options **do not promise to be currently executable** — a planner must see a temporarily infeasible goal in order to backtrack to a preparation step; hard-gate filtering is project policy. No pre-sorting is needed (the pipeline sorts by id), but ids must be unique. Build **new** `DecisionOption` instances every `provide()` — options/payloads are shared by reference, and reusing instances across decisions lets a downstream write pollute the next one (GDScript has no freeze; this is a discipline).

---

## Reasoner (extends RefCounted)

Interface — how to choose, and why. Algorithm and parameters are entirely project-side (mechanism/policy separation): utility weighting, a rule table, or GOAP-lite (see `GoalBacktrackReasoner`) are all just implementations of this one interface over the same Snapshot/Option/Result.

- `decide(_snapshot: DecisionSnapshot, _options: Array[DecisionOption], _rng: RandomNumberGenerator) -> DecisionResult` — Override; the base asserts

**Three contracts:**
1. **Always returns a non-null `DecisionResult`** — "null = a legal result" is retired. On a selection, `selected` and `reason_key` are non-empty (the pipeline validates); when everything is judged infeasible, return a `DecisionResult` with an empty `selected` but a **filled `breakdown`** — that is what the pipeline turns into `NO_FEASIBLE_OPTION`. Returning null trips a pipeline assertion.
2. Does not mutate `snapshot` or `options` (read-only inputs).
3. Randomness uses only the passed-in `rng` — neither the framework nor the Reasoner owns a random source.

---

## DecisionResult (extends RefCounted)

What one decision produced: what to do, why, and the full working.

**Properties:**
- `selected: DecisionOption` — The step to take now (under GOAP-lite that is the head of the chain, not the final goal); `null` = judged all-infeasible
- `reason_key: String` — Narrative factor; the explainability contract (non-empty when `selected` is set, pipeline-validated). Projects usually map it to a weight source (`"personality:greedy"`) or a goal id
- `chain: Array[String]` — GOAP-lite backtrack chain as option ids, `[current step, ..., final goal]`. Empty = direct decision (the selected option *is* the goal)
- `breakdown: Array[Dictionary]` — Full per-candidate scoring detail, consumed by debug UI. Entry shape: `{ "option_id": String, "score": float, "parts": Dictionary, "rejected": String }` — a non-empty `rejected` is the reason it lost (e.g. `"unreachable"`). Keeping it out of the event stream / recording / save is the caller's job

---

## DecisionOutcome (extends RefCounted)

The typed outcome of one decision — `DecisionPipeline.run()` always returns this. Distinguishing "had no candidates" from "had candidates but none feasible" is what makes "why is he standing there doing nothing" answerable.

**Status constants:** `SELECTED`, `NO_OPTIONS`, `NO_FEASIBLE_OPTION`

**Properties:**
- `status: String` — One of the three above (default `NO_OPTIONS`)
- `result: DecisionResult` — Non-null **only** when `status == SELECTED`
- `breakdown: Array[Dictionary]` — Always carried: the same reference as `result.breakdown` on `SELECTED`; the full scoring detail (with `rejected` reasons) on `NO_FEASIBLE_OPTION`; always empty on `NO_OPTIONS`

**Factories:** `static selected(p_result: DecisionResult)` / `static no_options()` / `static no_feasible(p_breakdown: Array[Dictionary])`

---

## DecisionPipeline (static utility)

- `static run(snapshot: DecisionSnapshot, provider: OptionProvider, reasoner: Reasoner, rng: RandomNumberGenerator) -> DecisionOutcome`

Assembly plus discipline enforcement — a stateless static function: no state, no RNG, no decision loop / execution / timing (those belong to the caller, which branches on `status`; an idle policy is caller-side).

**The three disciplines it enforces:**
1. **Candidate determinism** — options are sorted by id ascending (never rely on the provider's incidental generation order; incidental order breaks replay reproducibility), and a duplicate id asserts.
2. **Explainability** — always returns a `DecisionOutcome`; a selection must carry `reason_key`, and a non-selection still separates "no candidates" from "all infeasible" while keeping the breakdown.
3. **Snapshot read-only** — `content_hash()` is sampled *before* the provider runs and re-checked after `decide()`, so both provider and reasoner are covered (active only when a subclass implements `content_hash`).

**Assertions it raises:** duplicate option id · `decide()` returned null · empty `breakdown` on an all-infeasible result · `selected` is not one of the provider's own instances (alien option) · empty `reason_key`.

---

## GoalBacktrackReasoner (extends Reasoner)

Optional GOAP-lite base class: supply/demand tag backtracking with **no predicate world, no simulated future, and a capped chain length**.

**Mechanism (framework-implemented, do not override):** walk goals in ranked order; a goal whose `requires` are all met is done directly; otherwise backtrack along the `provides` supply table for a preparation step (one table lookup, not a search), re-verifying every step against the real world. It only ever emits "the one step to take now" — never a committed plan; after a preparation step completes, the caller decides again against the real world.

**Reachability rule:** *every* unmet requirement of a node must have a feasible supply chain within budget — one unsolvable gap makes the whole goal unreachable (this prevents "earned the money, then found the equipment slot can never be freed" dead runs). If a gap's best-scoring provider is itself infeasible, the next-best is tried (score desc, id asc tiebreak). The returned chain's head comes from the first gap's chain; the other gaps are picked up naturally by later decisions through per-step re-verification.

**Properties / construction:**
- `max_chain_depth: int` — Chain-length cap **including the goal itself**, default `2` (preparation step + goal): a two-step chain's causality fits in one sentence ("to buy the sword, first earn money")
- `_init(p_max_chain_depth: int = 2)`

**Policy hooks (project implements):**
- `_score(_option: DecisionOption, _snapshot: DecisionSnapshot) -> float` — Required (base asserts). One ruler for goals and preparation steps alike; stickiness/bias live here
- `_is_requirement_met(_requirement: Dictionary, _snapshot: DecisionSnapshot) -> bool` — Required. Judges against the snapshot's real world, never predicts a future
- `_requirement_tag(_requirement: Dictionary) -> String` — Required. The demand-side tag of a gap (e.g. `min_purse` → `"money"`)
- `_rank_goals(options: Array[DecisionOption], scores: Dictionary, _snapshot: DecisionSnapshot, _rng: RandomNumberGenerator) -> Array[DecisionOption]` — Optional. Default is deterministic argmax (score desc, id asc); override with weighted sampling when you want randomness — that is the one place `rng` is used
- `_score_parts(_option: DecisionOption, _snapshot: DecisionSnapshot) -> Dictionary` — Optional, default `{}`. Source of the `parts` field in `breakdown` entries
- `_reason_for(goal: DecisionOption, _snapshot: DecisionSnapshot) -> String` — Optional, default the final goal's id

---

## Conventions

- **Never put the decision loop, execution, or timing in this module** — the pipeline runs exactly one decision; when and how often is the caller's.
- **Never let a `Reasoner` or `Provider` own a `RandomNumberGenerator`** — take it as a parameter, so the caller (e.g. a per-region RNG stream) owns determinism.
- **A `Reasoner` must return a `DecisionResult`, never null** — "all infeasible" is `selected = null` **with** `breakdown` filled.
- **`reason_key` is a contract, not a courtesy** — a selection without one crashes.
- **`OptionProvider.provide()` allocates fresh options each call** — never cache and hand back the same instances.
- Tests: `tests/core/ai_decision/decision_pipeline_test.gd` (determinism / backtrack chain / depth cap / cycle guard / tie-break / next-best supplier fallback / multi-gap reachability / breakdown conventions / typed `NO_OPTIONS` + `NO_FEASIBLE_OPTION`).
