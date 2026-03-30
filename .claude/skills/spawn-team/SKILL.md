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
allowed-tools: Read, Glob, Grep, Bash(git *), Bash(codex *), Bash(find *), Bash(wc *), Bash(rg *), Bash(echo *), Bash(mkdir *), Bash(ln *), Bash(mv *), Bash(sync *), Bash(cat *), Bash(date *), Bash(printf *), Bash(ls *), Bash(tmux *), Bash(test *), Task, TaskCreate, TaskUpdate, TaskList, TeamCreate, TeamDelete, SendMessage, AskUserQuestion
---

## Language Rules

- **All internal content** (skill logic, agent prompts, state files, events) → English only
- **User-facing output** → match user's language (Korean input → Korean output)
- **MiniMax workers** → always receive English prompts. Never send Korean to MiniMax.
- **Leader↔Agent communication** → English (SendMessage, task descriptions)

---

## Roles

**Leader** = this skill (main Claude session). Orchestrates: propose team → spawn → assign → review → merge.

---

## Step 0: Init

Tool preload:
```
ToolSearch: "select:TeamCreate,TeamDelete,Agent,SendMessage,TaskCreate,TaskUpdate,TaskList,AskUserQuestion"
```

Cleanup (tmux mode): kill orphaned `claude-*` sessions. Preserve current.
Auto-scan: package.json/requirements.txt/go.mod → stack. src/app/lib → scale. .git → worktree.
Ask only if structure undetectable or request ambiguous.

---

## Step 1: Project Analysis + Context Map

Run 1-1 through 1-4 concurrently.

### 1-1. Tech Stack
Detect from package.json, requirements.txt, go.mod, Cargo.toml.

### 1-2. Domain Detection

| Type | Condition | Ownership |
|------|-----------|-----------|
| [A] Domain dirs (default) | src/auth/**, src/products/** | Directory-level |
| [B] Flat (fallback) | src/services/auth.ts | File-level MECE |
| [C] Unclear/Legacy | Can't identify domains | architect-agent first → convert to [A] |

Detection failure → AskUserQuestion or assign 1 fullstack agent.

### 1-3. Context Map

Build ≤40 line codebase snapshot. Generated once, injected into every agent prompt.

```bash
rg --type py "^(class|def |async def )" --with-filename | head -40
rg --type ts "^(export |class |function |interface )" --with-filename | head -40
find . -name "*.py" -o -name "*.ts" | xargs wc -l 2>/dev/null | sort -rn | head -10
```

Format:
```
## Context Map
stack: {lang} + {framework}
domains: {dir}/: {N symbols} — {top classes/functions}
heavy_files: {file}: {N} lines
```

### 1-4. Domain Scale → Ownership Manifest

small (1-3 files): merge candidate. medium (4-9): 1 agent. large (10+): 1 agent (suggest split).
Each file → exactly 1 owner. Shared → Leader.

---

## Step 2: Task-Based Routing

Decompose user request into components. "add login" = BE + FE + DB + middleware + tests.

```
N_parallel < 3 AND N_files < 5  → SINGLE AGENT
N_parallel ≥ 3 AND N_files ≥ 5  → TEAM
reviewer-only / explicit plan    → TEAM
```

**Mechanical transformation** (mass rename, bulk refactor, format enforcement) → suggest `/batch`.
Benchmark: spawn overhead ~16s/agent. Team breaks even at ~200 LOC/domain or ≥5 files.

### Single Agent Route
If SINGLE: inform user → inject Context Map → spawn one Agent (no TeamCreate) → /simplify on completion → done.
Override with `--team` flag.

---

## Step 3: Scope Confirmation (MEDIUM/COMPLEX)

AskUserQuestion ×1: IN (domains + files + shared), OUT (external, CI/CD), DEFER (low-priority).
After confirm → scope locked.

---

## Step 4: Planning (COMPLEX only)

Spawn Opus sub-agent for planning:
```bash
echo "claude-opus-4-6" > /tmp/claude-team-model-planner
```

### 4-1. Interview (3-5 questions)
Core objective / success criteria ×3 / constraints / risks / ordering

### 4-2. Wave Decomposition (3-5 waves)
```
Wave 1 (parallel): Foundation — types, schemas, shared interfaces
Wave 2 (parallel): Core — domain logic per agent
Wave 3 (sequential): Integration — cross-domain
Wave N: Verification — tests
Wave Final: merge
```

Task format: `Task: {verb} {target} → {output}` / `Accepts: {criterion}` / `BlockedBy: {id|none}`
Rules: ≤10 tasks/agent. Scope ≤200 LOC or 1 module.

### 4-3. Validation
4 checks: Clarity (concrete Accepts) / Verifiability (testable) / Context sufficiency / Wave coherence.
Gap+Risk self-check: "3 missed requirements? 3 failure modes?" → resolve.

---

## Step 5: Team Composition

**Hard cap: 5 agents.**

### Model Selection

| Model | Use for |
|-------|---------|
| **Opus** | COMPLEX planning only (sub-agent). Never for implementation. |
| **Sonnet** | Leader orchestration, coordination, judgment |
| **MiniMax M2.7** | All worker agents (implementation, testing). Default. 204K context. RPM 20 → max 4 concurrent with 3s stagger. |
| **Haiku** | MiniMax fallback. Sub-agents (debugger, build-fixer). |
| **Codex** | Zero-context mechanical generation only. `gpt-5.4` |

### MiniMax Routing (default for workers)

```bash
for agent_name in "${worker_agents[@]}"; do
    echo "minimax" > "/tmp/claude-team-model-${agent_name}"
done
```

Fallback: MiniMax unavailable → auto-falls back to Haiku via teammate.sh.
Override: `echo "claude-sonnet-4-6" > "/tmp/claude-team-model-{name}"` for security-critical agents.

**Not MiniMax:** 200K+ context needed, security-critical code, complex cross-domain architecture.

### Typical Compositions

| Task | Team |
|------|------|
| Feature small | fullstack(mm) + unit-tester(mm) |
| Feature medium | domain-be(mm) + domain-fe(mm) + tester(mm) |
| Feature large | planner(sonnet) + domain-a(mm) + domain-b(mm) + tester(mm) ×2 |
| Review/audit | security(sonnet) + perf(mm) + quality(mm) |
| Security-critical | All Sonnet |

### Worktree
3+ agents → `isolation: "worktree"`. ≤2 → shared. Git unavailable → shared, cap ≤2.

---

## Step 6: User Confirmation

SIMPLE: AskUserQuestion ×1 (team only). MEDIUM/COMPLEX: team + Wave plan + top risk.

---

## Step 7: Spawn Team

### 7-pre. Experience Brief (Forge)

```bash
RECOMMEND=$(forge recommend --workspace "$WORKSPACE" --complexity "$COMPLEXITY" 2>/dev/null) || true
BRIEF=$(forge resume --team-brief --workspace "$WORKSPACE" --session-id "team-$(date +%s)" 2>/dev/null) || true
```
Show if data exists, apply to team config. Skip silently if no data.

### 7-0. Run Initialization

```bash
RUN_DATE=$(date +%Y-%m-%d)
NNN=$(printf "%03d" $(($(ls -d .claude/runs/${RUN_DATE}-* 2>/dev/null | wc -l) + 1)))
RUN_ID="${RUN_DATE}-${NNN}"
mkdir -p ".claude/runs/${RUN_ID}"
ln -sfn "${RUN_ID}" .claude/runs/latest
```

Write plan.yml (once, never modified), state.yml (atomically updated), events.yml (append-only).
Archive runs >7 days to .claude/runs/archive/.

### 7-1. Spawn Agents

```
TeamCreate → spawn ALL agents in single message (multiple Agent calls).
Per agent: subagent_type: "general-purpose", run_in_background: true
```

Model signals before spawn. On failure → TeamDelete rollback.
Update state.yml: add agents, set phase: EXECUTING. Append events.

### 7-2. Agent Prompts

Read `${CLAUDE_SKILL_DIR}/prompts.md` → Common Header + role-specific + Wave info (COMPLEX).
Always inject CONTEXT_MAP. Progressive tool disclosure per role.

---

## Step 8: Execution

### 8-1. Task Distribution
COMPLEX: Task/Accepts/BlockedBy format. MEDIUM: brief Accepts. SIMPLE: plain description.
COMPLEX: Wave order enforced — Leader gates with "WAVE {N} COMPLETE".

### 8-1.5. State Management

**state.yml** — atomic write: Write → .tmp → sync → mv. Increment state_version.
**events.yml** — append immediately. Types: agent_spawned, task_assigned, agent_done, wave_complete, scope_drift, test_result, escalation.
**Communication**: SendMessage = ephemeral hint. state.yml = authority. events.yml = audit.

### 8-2. Progress
Report at: each agent completion, Wave transitions, FAIL escalations.
Mid-run summary: COMPLEX after each Wave, MEDIUM once after all complete, SIMPLE skip.

### 8-3. Implementation → Test Loop

```
Agent done → tester verifies
  PASS → next
  FAIL → agent + Leader → fix → re-verify
    2× FAIL → agent spawns debugger (Haiku, depth-1, read-only)
    post-debugger FAIL → AskUserQuestion: "1) Leader intervenes 2) Skip 3) Abort"
```

Build failure → agent spawns build-fixer (Haiku, depth-1, scoped).

### 8-4. Merge

Pre-merge: `git diff --name-only main` scope check. Out-of-scope → revert.
Order: shared(Leader) → independent domains → high-dependency → tests.
Post-merge: build check → FAIL → build-fixer.
Conflicts: same file → AskUserQuestion / different → auto-resolve.

### 8-5. Completion

1. scenario-tester → fix → re-verify
2. Worktree merge
3. /simplify on all changed files. Optional Codex review (AskUserQuestion).
4. Write report.yml + freeze state.yml + forge ingest + lifecycle cleanup

**Shutdown:** individual shutdown_request → 15s timeout → tmux kill-pane fallback → TeamDelete.

**Forge ingest:**
```bash
forge ingest --workspace "$WORKSPACE" --run-dir "$RUN_DIR" 2>/dev/null || true
```

---

## Operating Rules

- **Leader reads**: DONE → `git diff --numstat` check. High-risk (auth/payment/100+ LOC/post-FAIL) → inspect hunks.
- **Messaging**: individual SendMessage. No broadcast.
- **Quota**: 1 agent ≈ 7×. Hard cap: 5. Sub-agents: depth-1, ≤2/agent, Haiku only.
- **File isolation**: own domain only. Shared → Leader. 1 agent/file (MECE). Violation → revert.
- **Testers**: report only, no edits. Technical → direct peer. Decisions → Leader.
- **/batch**: within owned scope only, explicit file list. Opens PRs, doesn't merge.
- **/simplify**: Leader runs once after merge (8-5). Not per-agent.
- **Tokens**: wc -l before Read. 500+ → offset+limit. Grep→Read (needed parts). No repeat reads.
- **Worktree**: sequential merge only. No parallel merges. No direct work on main.
- **Planning**: SIMPLE=none, MEDIUM=scope only, COMPLEX=interview+Wave.
