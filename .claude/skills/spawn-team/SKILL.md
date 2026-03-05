---
name: spawn-team
description: This skill should be used when the user asks to "create a team", "spawn a team", "start team agents", "set up a dev team", or wants to begin parallel development with Claude Code Agent Teams. Analyzes the project, detects domains, and spawns an optimized team of agents dynamically.
triggers:
  - "spawn team"
  - "create a team"
  - "set up a team"
  - "start team agents"
  - "팀 구성"
  - "팀 스폰"
  - "팀 만들어"
argument-hint: "[project path]"
allowed-tools: Read, Glob, Grep, Bash(git *), Bash(codex *), Bash(find *), Bash(wc *), Bash(sg *), Task, TaskCreate, TaskUpdate, TaskList, TeamCreate, TeamDelete, SendMessage, AskUserQuestion
---

## Step 0: Intent Classification & Clarification

**Fast — most requests pass without extra questions.**

1. **Pre-scan** (auto): package.json/requirements.txt/go.mod → stack, src/app/lib → scale, .git → worktree availability
2. **Conditional questions** (only if needed): non-standard structure → ask for domain spec / ambiguous request → type selection / clear → straight to Step 1
3. **Output**: `clarity: HIGH|MEDIUM|LOW`, `original_request: {verbatim user request}`

## Step 1: Project Analysis

**1-1 and 1-2 run concurrently.**

### 1-1. Tech Stack
Detect from package.json, requirements.txt, go.mod, Cargo.toml, etc.

### 1-2. Domain Detection + Structure Type

BE: filenames in routes/controllers/services/handlers. FE: filenames in pages/views.

**Structure type → ownership model:**

| Type | Condition | Ownership Model |
|------|-----------|----------------|
| [A] Domain directories (default) | src/auth/**, src/products/** | Directory-level ownership |
| [B] Flat structure (fallback) | src/services/auth.ts etc. by function | File-level MECE manifest |
| [C] Unclear/Legacy | Domain boundaries unidentifiable | architect-agent first → convert to [A] |

Detection failure: AskUserQuestion for manual spec, or assign 1 fullstack agent.

### 1-3. Domain Scale → Ownership Manifest

Scale: small (1-3 files) = merge candidate, medium (4-9) = 1 independent agent, large (10+) = 1 agent (suggest split).

**Final output** — each file/directory belongs to exactly 1 entry; shared files owned by Leader.

## Step 2: Team Composition Proposal (Dynamic)

**Hard cap: 5 agents. Dynamically tailored to project.**

| Scale | Composition | Worktree |
|-------|-------------|----------|
| Small (1-2) | fullstack(sonnet) + unit-tester(haiku) | shared |
| Medium (3-4) | domain be/fe(sonnet) per domain + unit-tester(haiku) | isolated |
| Large (5 cap) | planner(sonnet) + domain(sonnet, merge to ≤2) + tester(haiku) ×2 | isolated |

Too many domains → merge by similarity/dependency until ≤5 slots. If all domains are medium+, split largest. Worktree: 3+ agents → isolated, ≤2 → shared.

### Model Selection

| Model | Purpose | When |
|-------|---------|------|
| Sonnet | All team agents: fullstack, {domain}-be/fe, planner, architect-agent | Default (all complexity levels) |
| Haiku | Sub-agents only: debugger, build-fixer, unit-tester, scenario-tester | Test/iteration, self-spawned by team agents |
| Codex xhigh | Pre-merge final review (read-only, not a team member) | Review ×1 |

**Model policy:**
- Team agents (TeamCreate spawned): always **Sonnet** regardless of complexity.
- Sub-agents (self-spawned by team agents via Agent tool): **Haiku** only.
- No Opus. Sonnet+thinking covers all reasoning needs.

## Step 2B: Complexity Scoring (Auto)

| Criterion | 1 pt | 2 pts | 3 pts |
|-----------|------|-------|-------|
| Domain count | 1 | 2-3 | 4+ |
| File scale | ≤10 | 11-50 | 51+ |
| Dependencies | Independent | Low | High (mutual) |
| Structure | [A]=1 | [B]=2 | [C]=2 |

```
4-6  → SIMPLE:  straight to Step 4 (no override question, no Codex question)
7-9  → MEDIUM:  Step 2.5 → Step 4
10+  → COMPLEX: Step 2.5 → Step 3 → Step 4
Auto COMPLEX: explicit "plan this"/"계획해줘"/plan request, structure [C]
clarity=LOW → AskUserQuestion ×1 to clarify intent → re-run complexity scoring with refined request → continue normal flow.
```

User override (MEDIUM/COMPLEX only): "Complexity: {X}. 1) Proceed 2) Plan 3) Adjust scope"

## Step 2.5: Scope Confirmation (MEDIUM/COMPLEX only)

Auto-generated from Step 1 → AskUserQuestion ×1:
- **IN**: detected domains + files + shared / **OUT**: external systems (mock only), CI/CD, performance / **DEFER**: low-priority domains
- After confirmation → **scope locked**. Change attempts → warning + re-confirmation required.

## Step 3: Planning (COMPLEX only)

### 3-1. Structured Interview (AskUserQuestion, 3-5 questions)
Q1 core objective (1-2 sentences) / Q2 success criteria ×3 (measurable) / Q3 constraints / Q4 risks / Q5 ordering preference

### 3-2. Wave Decomposition (auto, based on interview + manifest)

3–5 waves as needed (not fixed). Typical structure:
```
Wave 1 (parallel): Foundation — types, schemas, shared interfaces
Wave 2 (parallel): Core — domain logic per agent
Wave 3 (sequential): Integration — cross-domain, shared files
Wave N (parallel): Verification — unit + scenario tests
Wave Final: Codex review + merge
```
Each Wave: completion criterion, assigned agents, parallelism flag. Distribute Q2 success criteria across domains.

**Task format (mandatory per task, COMPLEX only):**
```
Task: {action verb} {target file/module} → {expected output}
Accepts: {concrete, testable criterion — no vague "implement X"}
BlockedBy: {task-id | none}
```
Rules: ≤10 tasks per agent. Accepts missing → task not issued. Scope: ≤200 LOC change or 1 module.

### 3-3. Validation + Confirmation

**4-criteria check (all must pass):**
1. **Clarity** — every task has a concrete Accepts criterion
2. **Verifiability** — Accepts is testable/measurable (not "looks good")
3. **Context sufficiency** — agent can execute without asking for missing info
4. **Wave coherence** — Wave order matches dependency direction, no circular deps

Violation → fix before proceeding. ≤10 tasks per agent enforced.

**Gap+Risk Review (Leader self-check before user approval):**
"3 requirements likely missed? 3 ways this plan could fail?"
→ Resolve gaps in plan, surface top risk to user.

## Step 4: User Confirmation

**SIMPLE**: AskUserQuestion ×1 — team composition only. Codex auto-disabled. On confirmation → spawn immediately, start original request automatically.
**MEDIUM/COMPLEX**: AskUserQuestion ×2:
1. **Team composition** — per-agent scope (COMPLEX: includes Wave plan + top risks from Gap+Risk Review). Options: as recommended / adjust (specify changes in free text)
2. **Codex activation** — enable pre-merge final review? (adds one AI code review pass before merge)

## Step 5: Spawn Team

### 5-1. TeamCreate → 5-2. Spawn Agents

Each agent: `subagent_type: "general-purpose"`, `team_name`, `name: "{domain}-{role}"`, `run_in_background: true`

**⚠ Worktree Rules (verify before spawning):**
1. 3+ agents → **must** set `isolation: "worktree"` (requires git). Never omit.
2. ≤2 agents → shared (omit isolation).
3. Pre-spawn: run `git rev-parse --is-inside-work-tree` → failure → fallback to shared (cap: ≤2 agents, keep highest-priority domains) + notify user.
4. When using worktree, apply to all agents uniformly (no partial worktree).

Partial spawn failure: TeamDelete rollback → notify → suggest retry.

### 5-3. Agent Prompts

Read `.claude/skills/spawn-team/prompts.md` → inject Common Header + role-specific prompt for each agent.
(COMPLEX) Append Wave info from prompts.md.

## Domain Boundaries & Worktree Merge Protocol

### Worktree Merge (sequential — no parallel merges)
```
Pre-merge: git diff --numstat main → 100+ LOC changed files → inspect hunks directly. git diff --name-only main | grep -vE "{pattern}" → out-of-scope → revert
Order: 1. shared (Leader direct) → 2. independent domains → 3. high-dependency domains → 4. tests
Post-merge: build check → FAIL → build-fixer
Conflicts: same file → manual (AskUserQuestion) / different files → auto (Leader resolves)
```

### Shared Type/Schema Changes
Analyze change (non-breaking → approve, breaking → consider Debate) → pause affected agents → Leader edits directly → notify → confirm adoption → unit-tester re-run.

## Step 6: Standby

```
Team ready.
Agents: {name}({model}) — {scope} ...
Codex: enabled/disabled | Worktree: isolated/shared
Complexity: {X} | Scope: IN {n} / OUT {n} | Plan: {n} waves / none
```
SIMPLE → auto-start with original request. No further input needed.
MEDIUM/COMPLEX → "Starting: '{original_request}'. Any additions before I begin?"

## Step 7: Execution & Feedback Loop

### 7-1. Task Distribution
SendMessage to assign. COMPLEX: use Task format (Task/Accepts/BlockedBy) from Step 3-2. MEDIUM: include brief Accepts criterion in description. SIMPLE: plain description. Independent = parallel, dependent = blockedBy. (COMPLEX) Follow Wave order — Leader sends "WAVE {N} COMPLETE" to gate next Wave start.

### 7-1-b. Mid-Run Summary (context management)

**COMPLEX**: required after each Wave completion.
**MEDIUM**: once after all agents complete, before merge.
**SIMPLE**: skip (fast completion, no accumulation).

Write `/tmp/summary-{wave|final}.md` (cap: 1500 chars): decisions / open issues / verification PASS·FAIL counts / next objective. Prefer this file over prior conversation afterward.

### 7-1-c. Progress Updates (mandatory)
Leader reports to user at: each agent completion ("✅ {agent} done — {n}/{total} tasks"), Wave transition (COMPLEX), any FAIL escalation.

### 7-2. Implementation → Test Loop
```
Agent done → unit-tester verifies
  PASS → next phase
  FAIL → report to Leader + agent → fix → re-verify
    2× FAIL → agent self-spawns debugger sub-agent (haiku, depth-1, no edits) → relay findings → fix
    post-debugger FAIL → [circuit breaker] AskUserQuestion: "1) Leader intervenes 2) Skip 3) Abort"
```

### 7-2-b. Build Failure
Agent self-spawns build-fixer sub-agent (haiku, depth-1, scoped to domain). Failure → Leader / escalation.

### 7-2-c. Structure [C] — architect-agent (once, before coding)
**Sonnet** (analyze legacy structure, design directory structure) → Leader review → user approval → refactor → convert to [A]. Failure → fallback to [B].

### 7-3. All Tests Pass
1. scenario-tester → FAIL → fix → re-verify
2. Worktree merge (per protocol above)
3. Codex review (if enabled, ×1). Failure → skip.
4. Completion report

### 7-4. Shutdown
Conditions (AND): TaskList all completed + unit-tester PASS + scenario-tester PASS + Codex done + (COMPLEX) all Wave completion criteria from Step 3-3 satisfied.
→ shutdown_request to all → TeamDelete.

## Debate Mode

Adversarial review of architecture decisions using Codex xhigh. **Details: `.claude/skills/debate/SKILL.md`.**

Entry: hard (irreversible=true / impact=3) or soft (risk 6+). Sum 6-7 → Leader Judge / 8-9 or hard → User Judge.

## Operating Rules

- Idle costs nothing (quota consumed only on message). Keep all agents alive until done.
- Quota: 1 agent ≈ 7×. Hard cap: 5 agents.
- Models: All team agents = **Sonnet** (subagent_type: "sonnet-agent"). Sub-agents (debugger/build-fixer/testers) = Haiku only. No Opus.
- File isolation: own domain only. Shared → Leader. MECE: 1 agent per file. Violation → revert.
- Testers: report only, no edits. Peer comms: technical → direct, decisions → Leader.
- Codex: pre-merge ×1. Failure → skip.
- Tokens: Explore first, no sequential expensive-model reads. No repeat file reads. Extract essentials from tool output.
- Worktree: 3+ agents → **must use isolation: "worktree"** (if git available; else cap ≤2 agents, shared). Sequential merge. No parallel merges. No direct work on main.
- Leader reads: DONE items → git diff --numstat check only. High-risk (public API / auth / payment / 100+ LOC / post-FAIL fix) → inspect hunks directly.
- Planning: SIMPLE = no plan, MEDIUM = scope only (Step 2.5), COMPLEX = interview + Wave. Scope locked after Step 2.5 → change triggers warning.
- Sub-agents: depth-1 only (no nesting). ≤2 per agent. Haiku only. debugger=read-only, build-fixer=scoped edits. Sub-agents do NOT count toward the 5-agent cap.
