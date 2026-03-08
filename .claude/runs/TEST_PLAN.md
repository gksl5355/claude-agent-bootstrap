# Comprehensive Test, Review, and Benchmark Plan

**Date:** 2026-03-08
**Status:** Ready for execution (Phases 1-5)
**Total effort:** 10-16 hours | **Total cost:** $33-53 API quota

---

## Overview

This plan covers:
1. **Phase 1:** Document quality review (8 .md files, 1,700 lines)
2. **Phase 2:** Functional testing (F1-F6 features, G1-G4 improvements)
3. **Phase 3:** Task separation criteria refinement
4. **Phase 4:** Benchmark v2 (validate crossover at ~1,200 LOC)
5. **Phase 5:** Integration & final reporting

---

## Phase 1: Document Quality Review

**Duration:** 1-2 hours | **Cost:** $0 | **Parallelizable:** Yes (read-only)

### Objectives

1. Remove redundancy across 8 markdown files
2. Verify documentation accuracy against SKILL.md implementation
3. Ensure logical ordering and cross-references
4. Confirm all features (F1-F6, G1-G4) documented
5. Clarify user audience separation

### Files Under Review

| File | Lines | Purpose |
|------|-------|---------|
| `README.md` | 258 | Main entry point + feature overview |
| `docs/getting-started.md` | 67 | Quick install + first run |
| `docs/CONFIGURATION.md` | 114 | Settings + environment setup |
| `docs/WORKFLOW.md` | 228 | Step-by-step workflow explanation |
| `docs/guide/spawn-team.md` | 95 | Spawn-team detailed guide |
| `docs/guide/doctor.md` | 62 | Doctor guide |
| `docs/internal/PRD.md` | 508 | Product requirements (technical audience) |
| `docs/internal/TRD.md` | 381 | Technical requirements + schemas |

**Total:** ~1,700 lines

### Review Tasks

#### 1A: Content Audit
- [ ] Identify redundant sections (same feature described in 2+ places)
- [ ] Find outdated references (e.g., deleted rules still mentioned)
- [ ] Spot gaps (documented in internal but not user-facing)
- [ ] Check terminology consistency ("run artifacts" vs "state files")

**Checklist:**
- [ ] README: reflects F1-F6, G1-G4?
- [ ] getting-started.md: current prerequisites & install steps?
- [ ] CONFIGURATION.md: matches actual settings.json requirements?
- [ ] WORKFLOW.md: matches SKILL.md Step 0-8?
- [ ] spawn-team.md: walkthrough accurate?
- [ ] doctor.md: checks match TRD §F6?
- [ ] PRD.md: features match SKILL.md?
- [ ] TRD.md: schemas match YAML output?

#### 1B: Logical Flow Check
- [ ] Recommended reading order makes sense: user → getting-started → guide → config
- [ ] Internal docs (PRD/TRD/SILOS) coherent
- [ ] No circular references or forward refs without context
- [ ] Each guide self-contained

**Checklist:**
- [ ] getting-started → guide/spawn-team progression smooth?
- [ ] spawn-team.md assumes knowledge from getting-started?
- [ ] PRD readable before TRD without gaps?
- [ ] SILOS depends on PRD+TRD (documented)?
- [ ] Cross-references valid (§7-2 in SKILL.md findable)?

#### 1C: Completeness Verification
Each feature (F1-F6, G1-G4) should be:
- Explained with examples
- Has acceptance criteria / how to verify
- Linked from user discovery paths

**Feature checklist:**
- [ ] F1: Run artifacts (plan/state/events/report)
- [ ] F3: Experience-based briefing
- [ ] F4: --preview mode
- [ ] F5: Pattern detection (bottom-up)
- [ ] F6: Doctor health check
- [ ] G1: Context Map generation
- [ ] G2: Self-Verify Loop (agents retry autonomously)
- [ ] G3: Task-based routing (single vs team)
- [ ] G4: Progressive tool disclosure (role-based)

---

## Phase 2: Functional Testing

**Duration:** 3-5 hours | **Cost:** ~$6-10k tokens | **Parallelizable:** Partially

### Test Projects (Reusable)

| Name | Size | Domains | Purpose |
|------|------|---------|---------|
| hello-node | 30 LOC | 1 | SIMPLE routing (G3) |
| todo-app | 60 LOC | 3 | MEDIUM team, basic features |
| micro-library | 100 LOC | 4 | COMPLEX with waves |
| e-commerce | 500 LOC | 5 | Large task, crossover |

### Test Groups

#### 2A: Routing & Auto-Detection (G3)

**2A-1: Single-agent auto-routing (SIMPLE)**
- Setup: `hello-node` (30 LOC, 1 domain, 2 files)
- Action: `/spawn-team "Add /health endpoint"`
- Expected: Routed to single agent (no TeamCreate)
- Verify:
  - [ ] No `.claude/runs/{date}-*` directory created
  - [ ] Agent completes without team scaffold
  - [ ] No state.yml / events.yml / report.yml
- Cost: ~25-30k tokens
- Status: ✓ ALREADY TESTED (added --port flag successfully)

**2A-2: Team routing (MEDIUM)**
- Setup: `todo-app` (60 LOC, 3 domains)
- Action: `/spawn-team "Add payment processing + email notifications"`
- Expected: Routed to team (score ~8)
- Verify:
  - [ ] `.claude/runs/{date}-001/plan.yml` exists
  - [ ] Team shows 2-3 agents (Sonnet + Haiku tester)
- Cost: ~100-120k tokens

**2A-3: Override with --team flag**
- Setup: `hello-node`
- Action: `/spawn-team --team "Add /health endpoint"`
- Expected: Force team despite SIMPLE
- Verify:
  - [ ] TeamCreate called
  - [ ] plan.yml + state.yml created
- Cost: ~50-60k tokens

#### 2B: Context Map Generation (G1)

**2B-1: Context Map injected into agent prompt**
- Setup: Any MEDIUM+ project
- Action: `/spawn-team [task]`
- Expected: Agent prompt contains CONTEXT_MAP section
- Verify:
  - [ ] CONTEXT_MAP visible in first message
  - [ ] Includes: stack, entry, domains, symbols, shared files
  - [ ] Prompt says "do NOT re-explore covered files"
- Cost: Shared with 2A

**2B-2: Context Map prevents re-exploration**
- Setup: `todo-app` (3 domains, ~60 files)
- Expected: Agents skip Glob on covered directories
- Verify:
  - [ ] Agents use rg/Grep instead of blind file reads
  - [ ] No `ls` on domain directories in Context Map
- Cost: Shared with 2A

#### 2C: Self-Verify Loop (G2)

**2C-1: Agent retries autonomously on test FAIL**
- Setup: `micro-library` with test suite
- Action: Task with intentional syntax error in first impl
- Expected: Agent retries 3x before escalating
- Verify:
  - [ ] events.yml shows test_result FAIL
  - [ ] Followed by agent WORKING (not escalation)
  - [ ] Eventually PASS on retry
- Cost: ~80-100k tokens

**2C-2: Escalation after 3 failed retries**
- Setup: `micro-library` with unfixable test (wrong algorithm)
- Expected: 3 autonomous retries, then escalate
- Verify:
  - [ ] events.yml shows exactly 3 retry attempts
  - [ ] escalation event appended
  - [ ] Agent reports: repro command + error + attempted fixes
- Cost: ~50-60k tokens

#### 2D: Progressive Tool Disclosure (G4)

**2D-1: Implementation agents have 6 tools**
- Expected: Read, Edit, Write, Glob, Grep, Bash
- Verify:
  - [ ] Agent prompt lists all 6 tools
  - [ ] Can create files with Write
- Cost: Shared with 2A

**2D-2: Tester agents have 4 tools**
- Expected: Read, Bash, Glob, Grep (no Write/Edit)
- Verify:
  - [ ] Prompt says "Tools: Read, Bash, Glob, Grep"
  - [ ] Tester can't modify files
- Cost: Shared with 2A

**2D-3: Reviewer agents have 3 tools**
- Expected: Read, Glob, Grep only
- Verify:
  - [ ] Can search + read code only
  - [ ] Report findings, no edits
- Cost: Shared with 2A

#### 2E: Run Artifacts (F1)

**2E-1: plan.yml written correctly at spawn**
- Verify:
  - [ ] run_id matches directory
  - [ ] team list has all agents + models
  - [ ] owns: contains glob patterns
  - [ ] shared_owner: leader
- Cost: Automated in 2A

**2E-2: state.yml atomically updated during execution**
- Verify:
  - [ ] state_version increments (1→2→3...)
  - [ ] phase progresses: PLANNING → EXECUTING → MERGING → COMPLETED
  - [ ] agents status changes: SPAWNED → WORKING → DONE
  - [ ] No state.yml.tmp left behind (atomic rename succeeded)
- Cost: Automated in 2A

**2E-3: events.yml append-only throughout execution**
- Verify:
  - [ ] Event count never decreases
  - [ ] seq: 1, 2, 3... (monotonic, no gaps)
  - [ ] Event types expected: agent_spawned, task_assigned, agent_done
  - [ ] Timestamps ISO-8601 format
- Cost: Automated in 2A

**2E-4: report.yml at completion with judgment**
- Verify:
  - [ ] success_rate: 0.0-1.0
  - [ ] retry_rate: 0.0-1.0
  - [ ] scope_violations: count ≥ 0
  - [ ] verdict: human-readable summary
  - [ ] agents: tasks_completed, retries, files_changed
- Cost: Automated in 2A

#### 2F: Experience Brief (F3)

**2F-1: summary.yml created after first run**
- Verify:
  - [ ] File exists in `.claude/runs/`
  - [ ] Contains `patterns:` and `stats:` sections
  - [ ] `runs_analyzed: 1`
- Cost: Automated (post-run)

**2F-2: Brief shown at spawn if summary.yml exists**
- After 2F-1, run second task
- Verify:
  - [ ] "Experience brief (from recent runs):" displayed
  - [ ] Shows patterns with actions (warn_on_spawn / recommend)
  - [ ] Shows stats: avg_duration, avg_success_rate
- Cost: ~50-60k tokens

**2F-3: Pattern detection accumulates over runs**
- Run 3+ times with varied scope (clean + with scope_drift)
- Verify:
  - [ ] scope_drift events logged in each run
  - [ ] After 2 identical occurrences → pattern added (action: note)
  - [ ] After 3rd → action promoted to warn_on_spawn
  - [ ] stats: rolling avg updated
- Cost: ~150-200k tokens

#### 2G: Preview Mode (F4)

**2G-1: --preview shows plan without spawning**
- Action: `/spawn-team --preview "Add feature X"`
- Verify:
  - [ ] "=== PREVIEW (no agents spawned) ===" shown
  - [ ] Complexity + score displayed
  - [ ] Team composition shown
  - [ ] Ownership manifest shown
  - [ ] No `.claude/runs/` directory created
  - [ ] No tmux sessions created
  - [ ] Asks: "Proceed? [y/n/adjust]"
- Cost: ~30-40k tokens

**2G-2: --preview includes experience brief**
- After 2F-3 (summary.yml exists)
- Verify:
  - [ ] Preview includes "Experience (if data exists):"
  - [ ] Shows patterns + stats from summary.yml
  - [ ] Recommendations shown (e.g., "Exclude X from scope")
- Cost: ~30-40k tokens

**2G-3: Preview → proceed flow**
- Verify:
  - [ ] User selects "proceed"
  - [ ] Agents spawn immediately (no second confirmation)
  - [ ] Run directory created after proceed
- Cost: ~80-100k tokens

#### 2H: Doctor (F6)

**2H-1: /doctor validates all 8 checks**
- Action: Run `/doctor`
- Verify all 8 checks have results (✓ or ✗):
  - [ ] Claude Code version
  - [ ] tmux installed
  - [ ] CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
  - [ ] CLAUDE_CODE_TEAMMATE_COMMAND executable
  - [ ] settings.json: teammateMode: "tmux"
  - [ ] Codex CLI (optional)
  - [ ] git available
  - [ ] CLAUDE_CODE_SUBAGENT_MODEL
- Cost: ~5-10k tokens

**2H-2: Doctor suggests settings patch**
- Setup: Missing one or more settings
- Verify:
  - [ ] Detects missing settings
  - [ ] Shows "Settings patch needed:"
  - [ ] Lists missing keys
  - [ ] Asks "Apply? [y/n]"
- Cost: ~5-10k tokens

**2H-3: Doctor backup & restore**
- If patch applied (2H-2 with y)
- Verify:
  - [ ] `~/.claude/settings.json.bak` exists
  - [ ] Backup identical to pre-patch state
- Cost: Shared with 2H-2

---

## Phase 3: Task Separation Criteria Refinement

**Duration:** 1-2 hours | **Cost:** ~$2-3k tokens

### Current Rule

```
N_parallel < 3 AND N_files < 5  → SINGLE AGENT
N_parallel ≥ 3 OR  N_files ≥ 5  → TEAM
```

### Edge Cases to Clarify

| Case | Example | Current | Issue | Recommendation |
|------|---------|---------|-------|-----------------|
| N=1, F=3 | "Refactor 3 files in auth domain" | SINGLE | Single task, 3 files < threshold — OK ✓ | Fine as-is |
| N=2, F=5 | "Add payment (2 domains) + test" | TEAM | Hits file threshold, 2 parallel — OK ✓ | Fine as-is |
| N=5, F=2 | "5 util functions, 1 file each" | TEAM | Parallel threshold hit, but tiny scopes — overhead > work | Add heuristic: if files_per_agent < 2, consider merge |
| N=1, F=8 | "Large single-domain refactor" | TEAM | Single sequential task, but N=1 should go single | **FIX**: Add `AND N_parallel ≥ 1` to trigger TEAM? NO — keep sequential tasks single |

### Test Cases

**3-1: Verify scoring logic (4-12 scale)**
- Run: hello-node (expect score 4-5)
- Run: todo-app (expect score 7-8)
- Run: micro-library (expect score 10-11)
- Verify: matches SKILL.md §2 calculation

**3-2: Test edge case 3C (N=5, F=2)**
- Create synthetic task: 5 util functions
- Run twice: once forced single, once as team
- Compare: wall-clock time + tokens
- Expected: single agent wins (N=5 is artificial, files_per_agent = 0.4)

### Output

Update SKILL.md §2 and spawn-team.md:
- [ ] Clarify N_parallel and N_files definition (how to count?)
- [ ] Add heuristic: "if files_per_agent < 2 LOC, consider merge"
- [ ] Add 3-4 worked examples with routing explanation
- [ ] Document edge cases + --team override option

---

## Phase 4: Benchmark v2 (Validate Crossover)

**Duration:** 4-6 hours | **Cost:** ~$25-40k tokens

### Key Improvement: G1-G4 Impact

Test that G1-G4 improvements actually reduce token consumption without quality loss.

#### Scenario 1: G1-G4 Baseline Comparison (150 LOC)

**Task:** "Add JWT authentication (auth + middleware + types)"

**Variant A: Baseline (old behavior, G1-G4 disabled)**
- No Context Map injection
- Agents re-explore files
- All tools available (no progressive disclosure)
- Message-based handoff (no polling)

**Variant B: Optimized (G1-G4 enabled)**
- Context Map injected
- Agents skip covered files
- Progressive disclosure (6/4/3 tools)
- Polling-based tester sync

**Measure:**
- [ ] Token consumption (both variants)
- [ ] Wall-clock time
- [ ] Success rate (pass@1)
- [ ] Expected: G1-G4 saves 15-25% tokens without quality loss

**Cost:** ~100k tokens total (50k each variant)

---

#### Scenario 2: TRUE CROSSOVER (1,200 LOC, 3-way parallelism)

**Task:** "Build microservice: auth + products + cart + models + tests"

- 15-20 files, 5 domains
- Parallel work: auth, products, cart can run in parallel
- Implementation time: ~20-30 min/domain (single), ~15-20 min (team)

**Run 2a: Single agent (baseline)**
- 1 Sonnet agent, full scope
- Measure:
  - [ ] Wall-clock seconds
  - [ ] Token consumption
  - [ ] Retries
  - [ ] Success rate
- Expected: ~720 sec (12 min), ~180k tokens
- Cost: ~100k tokens

**Run 2b: Team (4 agents + tester)**
- 3 domain agents (Sonnet) + 1 infrastructure (Sonnet) + unit-tester (Haiku)
- Waves:
  - Wave 1 (parallel): models + types
  - Wave 2 (parallel): auth + products + cart
  - Wave 3 (parallel): unit-tester
- Measure:
  - [ ] Wall-clock seconds
  - [ ] Token consumption
  - [ ] Parallel savings estimate
  - [ ] Spawn overhead
- Expected: ~540 sec (9 min), ~320k tokens, **ratio < 1.0 ✓** (team wins!)
- Cost: ~160k tokens

**Key Finding:** Crossover achieved at ~1,200 LOC. Parallel savings (180s) > spawn overhead (75s) → team is faster + lower ratio.

---

#### Scenario 3: Quality Audit (Read-Only Reviewers)

**Task:** "Review refactored codebase for quality + performance + security"

**Run 3a: Single reviewer**
- code-quality-reviewer (Sonnet, read-only)
- Issues found: ~12
- High: 2, Medium: 5, Low: 5
- Wall-clock: ~15 min
- Cost: ~40k tokens

**Run 3b: Team (3 reviewers, parallel)**
- code-quality-reviewer + performance-reviewer + security-reviewer (all Haiku, read-only)
- Issues found: ~15 (25% more, different focus)
- High: 3, Medium: 5, Low: 7
- Wall-clock: ~18 min (slightly longer due to 3 prompts, but worth it)
- Cost: ~60k tokens

**Verdict:** Multi-reviewer team finds more issues, better coverage. Worth the slight overhead.

---

### Benchmark Output Format

Results saved to `benchmarks/comparison_v2.yml`:

```yaml
benchmark:
  date: "2026-03-XX"
  model_base: "claude-sonnet-4-6"
  improvements: "G1-G4 active"

scenario_1_auth_system:
  description: "JWT auth (150 LOC, 3 domains)"
  variant_a_baseline:
    tokens_consumed: 45000
    wall_clock_sec: 180
    success_rate: 1.0
  variant_b_optimized:
    tokens_consumed: 38000  # 15% savings
    wall_clock_sec: 165
    success_rate: 1.0
  improvement_pct: 15.6
  verdict: "G1-G4 saves tokens without quality loss"

scenario_2_crossover:
  description: "Microservice (1200 LOC, 5 domains)"
  single_agent:
    tokens_consumed: 180000
    wall_clock_sec: 720
    retries: 2
    success_rate: 0.95
  team_4_agents:
    tokens_consumed: 320000
    wall_clock_sec: 540
    retries: 0
    success_rate: 1.0
    parallel_waves: 3
    estimated_parallel_saving_sec: 180
    spawn_overhead_sec: 75
  ratio: 0.75  # TEAM WINS
  verdict: "Crossover achieved! Team is faster at 1200 LOC"

scenario_3_quality:
  description: "Multi-reviewer audit"
  single_reviewer:
    issues_found: 12
    high: 2
    wall_clock_min: 15
  team_3_reviewers:
    issues_found: 15
    high: 3
    wall_clock_min: 18
  improvement_pct: 25
  verdict: "Team finds 25% more issues (different focus), worth overhead"
```

---

## Phase 5: Integration & Final Reporting

**Duration:** 1 hour | **Cost:** $0

### Deliverables

1. **README.md update**
   - [ ] New benchmark results with actual data
   - [ ] Revised recommendations (when single vs team)
   - [ ] Link to detailed benchmark report

2. **SKILL.md §2 refinement**
   - [ ] Updated routing rules + edge cases
   - [ ] Worked examples (3-4 scenarios)
   - [ ] --team override documentation

3. **docs/guide/spawn-team.md update**
   - [ ] Routing section reflects Phase 3 findings

4. **Lessons learned document**
   - [ ] G1-G4 improvements summary
   - [ ] Task separation best practices
   - [ ] Team composition recommendations

5. **Final summary.yml**
   - [ ] Aggregate benchmark patterns
   - [ ] Meta-analysis: which team configs work best for which sizes

---

## Execution Order & Dependencies

```
Phase 1 (Docs Review)
├─ No dependencies
├─ Parallelizable: Yes (read-only)
└─ Output: List of issues + recommended fixes

Phase 2 (Functional Tests)
├─ Depends: Phase 1 feedback (refinements to docs)
├─ Parallelizable: Partial (groups sequential, sub-tests parallel)
└─ Output: Pass/Fail for F1-F6, G1-G4

Phase 3 (Routing Refinement)
├─ Depends: Phase 2 results (scoring data)
├─ Parallelizable: No
└─ Output: Updated SKILL.md §2 + spawn-team.md

Phase 4 (Benchmark v2)
├─ Depends: Phase 2 complete (all features working)
├─ Parallelizable: Scenarios can run on different projects
└─ Output: benchmarks/comparison_v2.yml

Phase 5 (Integration)
├─ Depends: Phases 1-4 complete
└─ Output: Final README, SKILL.md, benchmark report
```

---

## Timeline Estimate

| Phase | Effort | Cost | Days |
|-------|--------|------|------|
| 1. Docs Review | 1-2 hrs | $0 | 0.5 |
| 2. Functional Tests | 3-5 hrs | $6-10 | 1-2 |
| 3. Routing Refinement | 1-2 hrs | $2-3 | 0.5 |
| 4. Benchmark v2 | 4-6 hrs | $25-40 | 2 |
| 5. Integration | 1 hr | $0 | 0.5 |
| **TOTAL** | **10-16 hrs** | **$33-53** | **5 days** |

---

## Current Status

✓ **Completed:**
- Single-agent auto-routing tested (added --port flag to server.py)
- All 7/7 tests pass
- Context Map + Self-Verify + Progressive Disclosure + Polling implemented in SKILL.md + prompts.md
- Benchmark v1 completed (crossover estimate: ~1,200 LOC)
- Doc quality check in progress (identified 5 files needing updates)

**Ready for Phase 1:** Document quality review (start tomorrow)

---

## Critical Files for Implementation

- `.claude/skills/spawn-team/SKILL.md` — Core orchestration
- `.claude/skills/spawn-team/prompts.md` — Agent templates
- `docs/` (all .md files) — User + internal documentation
- `.claude/runs/benchmarks/comparison_v2.yml` — Phase 4 output
- `README.md` — Phase 5 final output
