# Team Orchestrator v1.0 — Technical Requirements Document

> Implementation-level spec. Read PRD first for context.
> TRD answers: "정확히 어떻게 만드는가"

---

## Project Boundary

| Scope | Project 1 (this repo) | Project 2 (future) |
|-------|----------------------|---------------------|
| Technology | Shell + SKILL.md (no servers, no DBs) | GraphDB + Vector DB + LLM API |
| Memory | YAML files in `.claude/runs/` | Cross-run retrieval + embedding |
| Anti-pattern | Per-run detection + logging | FP rate tracking + auto-retirement |
| Skill lifecycle | None | Promotion, routing, retirement |
| Learning | Human-reviewed verdict field | Automated utility scoring |

---

## F1: Run Artifacts — Canonical Schemas

### Directory convention
```
{project-root}/.claude/runs/{YYYY-MM-DD-NNN}/
├── plan.yml
├── events.yml
├── report.yml
└── decisions.yml
```

`NNN` = zero-padded sequence per day (001, 002, ...). Leader creates dir at spawn time.
`latest` symlink: `ln -sfn {run-id} .claude/runs/latest`

### plan.yml (written once at spawn)
```yaml
run_id: "2026-03-08-001"
timestamp: "2026-03-08T14:30:00Z"
project: "/home/user/my-app"
task: "Add JWT authentication"
complexity: MEDIUM          # SIMPLE | MEDIUM | COMPLEX
score: 8                    # 4-12

team:
  - name: auth-be
    role: backend
    model: sonnet
    owns: ["src/auth/**", "src/middleware/auth.ts"]
  - name: unit-tester
    role: tester
    model: haiku
    owns: []

ownership_manifest:
  "src/auth/**": auth-be
  "src/middleware/auth.ts": auth-be
  shared: ["src/types/auth.ts"]
  shared_owner: leader
```

### events.yml (append-only, flush immediately per event)
```yaml
events:
  - ts: "14:30:05"
    type: agent_spawned        # agent_spawned | task_assigned | agent_done |
    agent: auth-be             # scope_violation | anti_pattern | test_result |
    model: sonnet              # escalation | debate_triggered | wave_complete

  - ts: "14:46:00"
    type: scope_violation
    agent: auth-be
    file: "src/config/database.ts"
    action: reverted

  - ts: "14:47:00"
    type: anti_pattern
    rule: AP007
    agent: auth-be
    severity: pause
    detail: "Added .skip() to 2 test cases"
    action: escalated_to_leader
    verdict: null              # filled post-run: true_positive | false_positive | accepted_risk

  - ts: "14:50:00"
    type: test_result
    agent: unit-tester
    target: auth-be
    result: PASS               # PASS | FAIL
    retry: 0
```

**Flush rule**: each event appended immediately (not batched). Enables future real-time UI via file watch.

### report.yml (written at completion)
```yaml
run_id: "2026-03-08-001"
duration_minutes: 28
status: COMPLETED              # COMPLETED | FAILED | ABORTED

agents:
  - name: auth-be
    tasks_completed: 3
    tasks_failed: 0
    retries: 1
    files_changed: ["src/auth/jwt.ts", "src/middleware/auth.ts"]
  - name: unit-tester
    tests_run: 12
    tests_passed: 12
    tests_failed: 0

scope_violations: 1
anti_pattern_hits: 1
debate_triggered: false
escalations: 0

confidence:
  score: 82                    # 0-100
  grade: B                     # A(90+) B(75+) C(60+) D(40+) F(<40)
  breakdown:
    scope_compliance: 95
    test_evidence: 100
    build_integrity: 100
    retry_burden: 70
    escalations: 100
  flags:
    - "auth-be: AP007 hit (test evasion) — verdict pending"
  verdict: "Ship with review of auth-be changes"
```

### decisions.yml (written when decisions occur)
```yaml
decisions:
  - ts: "14:35:00"
    type: scope_lock           # scope_lock | scope_violation_revert | debate_result | escalation
    detail: "IN: auth module. OUT: registration, OAuth."

  - ts: "14:46:00"
    type: scope_violation_revert
    agent: auth-be
    file: "src/config/database.ts"
    reason: "Outside owned scope"
```

---

## F2: Confidence Scoring — Algorithm

### Weights
| Check | Weight | Max score |
|-------|--------|-----------|
| scope_compliance | 0.30 | 30 |
| test_evidence | 0.25 | 25 |
| build_integrity | 0.25 | 25 |
| retry_burden | 0.12 | 12 |
| escalations | 0.08 | 8 |

### Formulas

**scope_compliance** (0-100):
```
violations = count(events where type=scope_violation)
score = max(0, 100 - violations * 20)
```

**test_evidence** (0-100):
```
tasks_with_accepts = count(tasks that have accepts criteria)
tasks_with_pass = count(tasks where test_result.result=PASS exists)
score = (tasks_with_pass / tasks_with_accepts) * 100   # 0 if no tasks
```

**build_integrity** (0-100):
```
score = 100 if post-merge build passed, else 0
```

**retry_burden** (0-100):
```
total_retries = sum(agent.retries for all agents)
score = max(0, 100 - total_retries * 15)
```

**escalations** (0-100):
```
score = max(0, 100 - escalations * 25)
```

**Final score**:
```
weighted_sum = Σ(check_score * weight)
anti_pattern_penalty = count(anti_pattern events where severity=block) * 5
                     + count(anti_pattern events where severity=pause) * 2
final_score = max(0, weighted_sum - anti_pattern_penalty)
```

**Grade boundaries**: A≥90, B≥75, C≥60, D≥40, F<40

---

## F3: Impact & Risk Brief — Git Analysis

### Commands (run before spawn)
```bash
# Changed files in last PR/branch
git diff --name-only main

# File hotspots (contributors in 30 days)
git log --since="30 days ago" --format="%H" -- {file} | wc -l

# Recent failures on file (from events.yml history)
grep -r "scope_violation\|anti_pattern" .claude/runs/*/events.yml | grep {file}

# Import depth (how many files import this file)
grep -r "import.*{module}" src/ | wc -l
```

### Output format
```
Impact & Risk Brief:
  Impacted modules: src/auth/**, src/middleware/**
  Likely test areas: tests/auth/**, tests/e2e/login.spec.ts
  Risk factors:
    - src/middleware/auth.ts: 8 contributors in 30 days (hotspot)
    - tests/auth/ had 2 scope_violations in recent runs
  Recommended team: 2 sonnet (be + fe) + 1 haiku (tester)
  Estimated scope: ~150 LOC across 6 files
  Risk level: MEDIUM
```

---

## F5: Anti-Pattern Detection — Shell Specs

### Detection commands per AP rule

```bash
# AP001: Out-of-scope edit
git -C "$wt" diff --name-only "$base" | grep -vE "$owned_pattern"

# AP002: Shared file touched without decisions.yml entry
shared_files=("src/types/" "prisma/schema" "openapi/")
git -C "$wt" diff --name-only "$base" | grep -E "$(IFS='|'; echo "${shared_files[*]}")"
# → check if matching entry exists in decisions.yml

# AP003: Role leakage (tester/read-only agent edits files)
# check agent role from plan.yml, then:
git -C "$wt" diff --name-only "$base" | wc -l  # > 0 for read-only = violation

# AP005: Done without evidence
# check events.yml for PASS event matching task accepts criteria

# AP007: Test evasion
git -C "$wt" diff -U0 "$base" | grep -E '^\+.*(\.skip\(|describe\.only\(|xdescribe\(|eslint-disable|@ts-ignore|\|\| true)'

# AP008: Stale merge (agent behind leader)
git merge-base --is-ancestor "$agent_head" "$leader_head"
```

### Hook points
| Hook | Checks run |
|------|-----------|
| on_checkpoint (30-60s in worktree) | AP001, AP002, AP007 |
| on_agent_done | AP001, AP002, AP003, AP005, AP007 |
| on_test_result | AP006 |
| pre_merge | AP001, AP002, AP005, AP008 |

---

## F6: Doctor — Check List

```bash
# 1. Claude Code version
claude --version

# 2. tmux
tmux -V

# 3. CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS

# 4. TEAMMATE_COMMAND file exists and is executable
test -x "$CLAUDE_CODE_TEAMMATE_COMMAND"

# 5. teammateMode in settings.json
jq '.teammateMode' ~/.claude/settings.json

# 6. Codex CLI (optional)
which codex && codex --version

# 7. git available
git --version

# 8. CLAUDE_CODE_SUBAGENT_MODEL
jq '.env.CLAUDE_CODE_SUBAGENT_MODEL' ~/.claude/settings.json
```

Settings patch: read `~/.claude/settings.json` → merge required keys → backup original → write.

---

## Worktree Gap Fixes (Wave 1C)

Three gaps in current spawn-team/SKILL.md:

### Gap 1: §7-1 — Add `isolation: "worktree"` to Agent spawn
Current §7-1 template lacks `isolation: "worktree"` when 3+ agents.
Fix: add conditional in spawn template.

### Gap 2: §8-4 — Merge mechanics
Add explicit merge sequence:
```
For each agent branch (in merge order):
  1. git fetch worktree branch
  2. git merge --no-ff {branch} -m "merge: {agent} work"
  3. resolve conflicts (AskUserQuestion if same file)
  4. run build check
  5. git worktree remove {wt-path}  # cleanup
```

### Gap 3: §8-5 — Worktree cleanup
After all merges complete: `git worktree prune` + remove stale branches.
