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

# Spawn Team

Analyze a project to dynamically compose and operate optimized Claude Code Agent Teams based on domain structure.

## Step 0: Intent Classification & Clarification

**Fast — most requests pass without extra questions.**

1. **Pre-scan** (auto): package.json/requirements.txt/go.mod → stack, src/app/lib → scale, .git → worktree availability
2. **Conditional questions** (only if needed): non-standard structure → ask for domain spec / ambiguous request → type selection / clear → straight to Step 1
3. **Output**: `task_type: FEATURE|BUG_FIX|REFACTOR|RESEARCH|AUTO`, `clarity: HIGH|MEDIUM|LOW`

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

**Final output** — each file/directory belongs to exactly 1 entry; shared files owned by Leader:
```
products-be: src/products/**
orders-be:   src/orders/**
shared(Leader): src/types/**, src/utils/**
```

## Step 2: Team Composition Proposal (Dynamic)

**Hard cap: 5 agents. Dynamically tailored to project.**

| Scale | Composition | Worktree |
|-------|-------------|----------|
| Small (1-2) | fullstack(sonnet) + unit-tester(haiku) | shared |
| Medium (3-4) | domain be/fe(sonnet) per domain + unit-tester(haiku) | isolated |
| Large (5 cap) | planner(sonnet) + domain(sonnet, merge to ≤2) + tester(haiku) ×2 | isolated |

> Models above are **scale defaults**. Complexity-based promotion (below) overrides them — e.g. COMPLEX promotes planner to Opus.

Too many domains → merge small ones. Worktree: 3+ agents → isolated, ≤2 → shared.

### Model Selection (complexity-linked)

| Model | Purpose | When |
|-------|---------|------|
| **Opus** | Leader orchestration, planner, architect-agent | COMPLEX only |
| Sonnet | fullstack, {domain}-be/fe, planner (MEDIUM and below) | Default implementation |
| Haiku | unit-tester, scenario-tester, debugger, build-fixer | Test/iteration |
| Codex xhigh | Pre-merge final review (read-only, not a team member) | Review ×1 |

**Complexity-based model promotion:**
- **SIMPLE**: Leader=Sonnet, all agents Sonnet/Haiku. No Opus (5x cost).
- **MEDIUM**: Leader=Sonnet+thinking, planner=Sonnet. Opus unnecessary.
- **COMPLEX**: Leader=**Opus**, planner=**Opus**, architect-agent=**Opus**. Domain agents stay Sonnet.
  - Opus rationale: Wave decomposition + 5-agent coordination + cross-domain dependency judgment requires deep reasoning.
  - Domain agents (implementation) are fine with Sonnet — Opus is for orchestration only.

## Step 2B: Complexity Scoring (Auto)

| Criterion | 1 pt | 2 pts | 3 pts |
|-----------|------|-------|-------|
| Domain count | 1 | 2-3 | 4+ |
| File scale | ≤10 | 11-50 | 51+ |
| Dependencies | Independent | Low | High (mutual) |
| Structure | [A]=1 | [B]=2 | [C]=2 |

```
4-6  → SIMPLE:  straight to Step 4
7-9  → MEDIUM:  Step 2.5 → Step 4
10-11 → COMPLEX: Step 2.5 → Step 3 → Step 4
Auto COMPLEX: explicit "plan this"/"계획해줘"/plan request, structure [C], clarity=LOW
```

User override: "Complexity: {X}. 1) Proceed 2) Plan 3) Adjust scope"

## Step 2.5: Scope Confirmation (MEDIUM/COMPLEX only)

Auto-generated from Step 1 → AskUserQuestion ×1:
- **IN**: detected domains + files + shared / **OUT**: external systems (mock only), CI/CD, performance / **DEFER**: low-priority domains
- After confirmation → **scope locked**. Change attempts → warning + re-confirmation required.

## Step 3: Planning (COMPLEX only)

**SIMPLE/MEDIUM skip this entirely.**

### 3-1. Structured Interview (AskUserQuestion, 3-5 questions)
Q1 core objective (1-2 sentences) / Q2 success criteria ×3 (measurable) / Q3 constraints / Q4 risks / Q5 ordering preference

### 3-2. Wave Decomposition (auto, based on interview + manifest)
```
Wave 1 (parallel): Foundation — types, schemas, shared interfaces
Wave 2 (parallel): Core — independent domain logic per domain
Wave 3 (sequential): Integration — cross-domain connections, shared files
Wave 4 (parallel): Verification — unit + scenario tests
Wave 5: Final — Codex review + merge
```
Each Wave: parallel tasks, dependencies, assigned agent, completion criteria.

### 3-3. Per-Domain Completion Criteria
Distribute Q2 across domains (specific, measurable).

### 3-4. Validation + Confirmation
Auto-check: measurable? circular deps? ≤10 tasks per agent? risks reflected?
Violation → AskUserQuestion. Final approval → Step 4.

## Step 4: User Confirmation

AskUserQuestion ×2:
1. **Team composition** — per-agent scope (COMPLEX: includes Wave summary). Options: as recommended / adjust
2. **Codex activation** — enable pre-merge final review?

## Step 5: Spawn Team

### 5-1. TeamCreate → 5-2. Spawn Agents

Each agent: `subagent_type: "general-purpose"`, `team_name`, `name: "{domain}-{role}"`, `model`, `run_in_background: true`

**⚠ Worktree Rules (verify before spawning):**
1. 3+ agents → **must** set `isolation: "worktree"`. Never omit.
2. ≤2 agents → shared (omit isolation).
3. Pre-spawn: run `git rev-parse --is-inside-work-tree` → failure → fallback to shared + notify user.
4. When using worktree, apply to all agents uniformly (no partial worktree).

Partial spawn failure: TeamDelete rollback → notify → suggest retry.

### 5-3. Agent Prompts

**[Common Header] — inserted into every agent:**
```
Project: {project-path}
Team members: {team-members}

## Assigned Scope (MECE)
Owns: {file-list}
Forbidden: no edits outside scope (read OK)

⚠ Boundaries: shared file edits → Leader approval | out-of-scope edits → revert + report | before starting, send "Scope confirmed: {list}"

## Exploration (token efficiency)
{≤5 files: direct Read+Grep | 6-15: Explore→Grep/sg→Read | 16+: Explore→sg→Grep→Read only needed files}
**Check size before Read**: `wc -l {file}` → 500+ lines → must use offset+limit on Read. No full-file reads.

## Runtime Token Conservation
- No repeat reads of the same file — retain in memory and reuse.
- If tool output is excessively long, extract only the essentials (no full paste).
- When debugging errors, quote only relevant lines, not full stack traces.
- Don't mix exploration (Explore/Grep) and implementation in one turn — finish exploring, then implement.
- **Stop exploring after reading 15+ files** → summarize findings, start implementing. If stuck, report to Leader.

## Peer Communication
Technical details → SendMessage directly to relevant agent. Leader gets completion/issues only. Shared files → via Leader.

## Leader Report Format
DONE: `status: DONE | files: {path-list} | summary: {one-line change description}`
FAIL/BLOCKED: above + `ERR: test:{name} expected:{x} actual:{y} location:{file:line} repro:{cmd}`
```

**[Role-specific — appended after common header]:**

| Role | Prompt |
|------|--------|
| {domain}-be | "You are {domain} BE developer ({name}). Edit only your scope. On completion → TaskUpdate + report. After 2-3 attempts, request Leader help. On tester report → fix → re-report." |
| {domain}-fe | Same as above + "Use Tailwind CSS (if present in project)." |
| unit-tester | "Test framework: {fw}. On Leader instruction → write & run unit tests. Mock externals. PASS → report. FAIL → report to Leader + relevant agent simultaneously (test name / expected vs actual / file:line / repro steps). **No code modifications.**" |
| scenario-tester | "Start on Leader instruction after implementation complete. Verify user scenarios step by step. FAIL → report step / expected / actual / repro steps. **No code modifications.**" |
| fullstack | "Own entire BE+FE scope. On completion → TaskUpdate + report. After 2-3 attempts, request Leader help." |

(COMPLEX) Append Wave info: "Wave {N} assigned: {tasks}. Proceed to next Wave on completion."

## Domain Boundaries & Worktree Merge Protocol

### Plan Mode Approval Gate (3+ agents, high dependencies)
Spawn with `mode: "plan"` → submit plan → Leader checks: edits within scope? no unauthorized shared changes? no API changes? → approve / reject + feedback.

### Worktree Merge (sequential — no parallel merges)
```
Pre-merge: git diff --numstat main → 100+ LOC changed files → inspect hunks directly. git diff --name-only main | grep -vE "{pattern}" → out-of-scope → revert
Order: 1. shared (Leader direct) → 2. independent domains → 3. high-dependency domains → 4. tests
Post-merge: build check → FAIL → build-fixer
Conflicts: auto → Leader resolves / manual → AskUserQuestion
```

### Shared Type/Schema Changes
Analyze change (non-breaking → approve, breaking → consider Debate) → pause affected agents → Leader edits directly → notify → confirm adoption → unit-tester re-run.

## Step 6: Standby

```
Team ready.
Agents: {name}({model}) — {scope} ...
Codex: enabled/disabled | Worktree: isolated/shared
Complexity: {X} | Scope: IN {n} / OUT {n} | Plan: Wave {n} / none
Give your instructions.
```

## Step 7: Execution & Feedback Loop

### 7-1. Task Distribution
SendMessage to assign. Independent = parallel, dependent = blockedBy. (COMPLEX) Follow Wave order.

### 7-1-b. Mid-Run Summary (context management)

**COMPLEX**: required after each Wave completion.
**MEDIUM**: once after all agents complete, before merge.
**SIMPLE**: skip (fast completion, no accumulation).

```
> /tmp/summary-{wave|final}.md (cap: 1500 chars)
Decisions: {decisions made this phase}
Open: {unresolved issues}
Verification: PASS {n} / FAIL {n}
Next: {next phase objective}
```
Prefer this file over prior conversation afterward. Self-check: [ ] ≤1500 chars [ ] all agent statuses included [ ] no missing open items

### 7-2. Implementation → Test Loop
```
Agent done → unit-tester verifies
  PASS → next phase
  FAIL → report to Leader + agent → fix → re-verify
    2× FAIL → spawn debugger (haiku, analysis only, no edits) → relay findings → fix
    post-debugger FAIL → [circuit breaker] AskUserQuestion: "1) Leader intervenes 2) Skip 3) Abort"
```

### 7-2-b. Build Failure
Spawn build-fixer (haiku, scoped to affected domain). Failure → Leader / escalation.

### 7-2-c. Structure [C] — architect-agent (once, before coding)
**Opus** (legacy structure analysis requires deep reasoning), design directory structure → Leader review → user approval → refactor → convert to [A]. Failure → fallback to [B].

### 7-3. All Tests Pass
1. scenario-tester → FAIL → fix → re-verify
2. Worktree merge (per protocol above)
3. Codex review (if enabled, ×1). Failure → skip.
4. Completion report

### 7-4. Shutdown
Conditions (AND): TaskList all completed + unit-tester PASS + scenario-tester PASS + Codex done + (COMPLEX) Wave + criteria met.
→ shutdown_request to all → TeamDelete. Quota threshold → immediate alert → scale down / terminate.

## Debate Mode

Adversarial review of architecture decisions using Codex xhigh. **Details: `.claude/skills/debate/SKILL.md`.**

Entry: hard (irreversible=true / impact=3) or soft (risk 6+). Sum 6-7 → Leader Judge / 8-9 or hard → User Judge.

## Operating Rules

- Idle costs nothing (quota consumed only on message). Keep all agents alive until done.
- Quota: 1 agent ≈ 7×. Hard cap: 5 agents.
- Models: COMPLEX → Leader/planner/architect = **Opus**, MEDIUM and below → Sonnet+thinking. Implementation = Sonnet, tests = Haiku.
- File isolation: own domain only. Shared → Leader. MECE: 1 agent per file. Violation → revert.
- Testers: report only, no edits. Peer comms: technical → direct, decisions → Leader.
- Codex: pre-merge ×1. Failure → skip.
- Tokens: Explore first, no sequential expensive-model reads. No repeat file reads. Extract essentials from tool output.
- Worktree: 3+ agents → **must use isolation: "worktree"**. Sequential merge. No parallel merges. No direct work on main.
- Leader reads: DONE items → git diff --numstat check only. High-risk (public API / auth / payment / 100+ LOC / post-FAIL fix) → inspect hunks directly.
- Planning: SIMPLE = no plan, COMPLEX only = interview. Scope locked after Step 2.5 → change triggers warning.
