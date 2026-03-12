# spawn-team Skill Research Loop

## Goal
Refine SKILL.md so that routing and tool suggestions behave correctly across test scenarios.
Target file: `.claude/skills/spawn-team/SKILL.md`

## Research Loop
1. Read this file + log.md (past experiments)
2. Analyze: what failed and WHY (not just what failed)
3. Form hypothesis: what SKILL.md change would fix it
4. Apply change to SKILL.md
5. Run test scenarios (simulate spawn-team response to each task)
6. Evaluate against criteria
7. Append result to log.md
8. Repeat until all criteria PASS

## Test Scenarios

### T1 — Mechanical routing
**Input:** "server.py의 모든 print를 logging으로 교체해줘"
**Expected:** Suggest `/batch` before spawning a team
**Pass criterion:** Response explicitly mentions `/batch` as a suggestion (not just spawns a team)
**Fail criterion:** Goes straight to team composition without mentioning `/batch`

### T2 — Team spawn + /simplify timing
**Input:** "server.py에 /health, /metrics, /status 엔드포인트 추가해줘"
**Expected:** TEAM routing → agents work → Leader runs `/simplify` once at completion (Step 8-5)
**Pass criterion:** `/simplify` mentioned only at Leader completion step, not per-agent
**Fail criterion:** `/simplify` assigned to each agent, or not mentioned at all

### T3 — Single agent routing
**Input:** "server.py에 /ping 엔드포인트 하나 추가해줘"
**Expected:** SINGLE AGENT routing (small scope)
**Pass criterion:** "Small scope detected" or equivalent single-agent message
**Fail criterion:** Team spawned for this trivial task

## Evaluation Method
Simulate: read SKILL.md carefully, then respond AS spawn-team would to each test input.
Check response against pass/fail criteria.
This is faster than real invocation — ~1 min per experiment vs 10+ min.

## Success Condition (Phase 1 — done)
All 3 tests PASS in the same iteration. ✅

---

## Phase 2: Thinking vs Mechanical Classification

### Goal
For each step in SKILL.md, classify:
- **THINK**: Requires reasoning, judgment, ambiguity resolution → keep in Leader (Sonnet)
- **MECH**: Deterministic, no judgment needed → offload or simplify (Haiku sub-agent, or just bash)

Then estimate token cost per step (rough: THINK=high, MECH=low) and identify top savings.

### Step Classification Table (fill in per experiment)

| Step | Name | Class | Token cost | Notes |
|------|------|-------|------------|-------|
| 0 | Init / cleanup | ? | ? | |
| 1-1 | Tech stack detect | ? | ? | |
| 1-2 | Domain detection | ? | ? | |
| 1-3 | Context Map gen | ? | ? | |
| 1-4 | Ownership manifest | ? | ? | |
| 2-mech | Mechanical detect | ? | ? | |
| 2-route | Routing decision | ? | ? | |
| 3 | Scope confirmation | ? | ? | |
| 4-1 | Structured interview | ? | ? | |
| 4-2 | Wave decomposition | ? | ? | |
| 4-3 | Validation | ? | ? | |
| 5 | Team composition | ? | ? | |
| 6 | User confirmation | ? | ? | |
| 7-0 | Run initialization | ? | ? | |
| 7-1 | Spawn agents | ? | ? | |
| 7-2 | Agent prompts | ? | ? | |
| 8-1 | Task distribution | ? | ? | |
| 8-1.5 | State management | ? | ? | |
| 8-2 | Progress updates | ? | ? | |
| 8-3 | Test loop | ? | ? | |
| 8-4 | Merge protocol | ? | ? | |
| 8-5 | Completion | ? | ? | |

### Test Scenarios (Phase 2)

### T4 — Step classification accuracy
**Input:** Walk through SKILL.md step by step. For each step, classify THINK vs MECH.
**Pass criterion:** Classification table filled. Top 3 MECH steps identified with token savings estimate.
**Metric:** % of steps that are MECH → higher = more optimization opportunity

### T5 — MECH offload impact
**Input:** For top 3 MECH steps, propose concrete SKILL.md changes to simplify/offload them.
**Pass criterion:** Each change reduces step complexity without losing correctness. No THINK step accidentally simplified.

### T6 — Token budget estimate
**Input:** Rough token cost before vs after MECH offloads.
**Pass criterion:** Estimated saving ≥ 15% of Leader token usage.

## Success Condition (Phase 2)
T4 + T5 + T6 all PASS. Classification table complete. SKILL.md updated with MECH simplifications.

## Hypothesis Log Format (append to log.md)
```
## Experiment N — YYYY-MM-DD HH:MM
**Hypothesis:** {what you think will fix the issue}
**Change:** {what was changed in SKILL.md}
**Results:**
  T1: PASS/FAIL — {reason}
  T2: PASS/FAIL — {reason}
  T3: PASS/FAIL — {reason}
**Analysis:** {why it worked or didn't}
**Next hypothesis:** {what to try next}
```
