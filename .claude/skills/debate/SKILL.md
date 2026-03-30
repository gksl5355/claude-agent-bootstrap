---
name: debate
description: Adversarial architecture review using Codex (gpt-5.4). Standalone or auto-triggered within spawn-team. Use on "debate", "architecture review", "design review".
triggers:
  - "debate"
  - "architecture review"
  - "design review"
  - "아키텍처 토론"
  - "설계 검토"
allowed-tools: Read, Glob, Grep, Bash(codex *), Bash(cat > /tmp/debate*), AskUserQuestion
---

# Debate — Adversarial Architecture Review

Submit design to Codex (gpt-5.4) for adversarial critique.

**Invoke:** `/debate "JWT vs Session Auth"` or auto-trigger via spawn-team.

## Step 1: Entry

**Hard trigger (always):** irreversible=true (DB schema, external API, auth) or impact=3 (system-wide).
**Soft trigger (risk 6+):** explicit request or 2+ alternatives with team-wide impact.

Risk score (each 1-3): Uncertainty + Impact scope + Complexity = sum/9.
6-7 → Leader Judge. 8-9 or hard → User Judge.

## Step 2: Draft Proposal (≤3000 chars)

```
Decision subject: {what}
Context: {current state, 3 sentences}
Proposed: {direction + rationale}
Alternatives: {rejection reasons, 1 line each}
Non-functional: perf/cost/security/availability/rollback
Risk: uncertainty:{1-3} impact:{1-3} complexity:{1-3} = {sum}/9 | irreversible:{bool}
Concerns: {self-critique}
```

## Step 3: Codex Critique

```bash
cat > /tmp/debate-input.md << 'EOF'
{proposal}
EOF
codex exec -m gpt-5.4 -s read-only "$(cat /tmp/debate-input.md)" 2>&1
```

Output format: `[BLOCK|TRADEOFF|ACCEPT] {category}: {summary}` with Problem/Impact/Fix.
Non-compliance → 1 retry.

## Step 4: Rounds (max 2 + 1 exception)

R1: no BLOCK → early exit. BLOCK → R2.
R2: address BLOCKs → re-review. Resolved → Judge. Persistent → AskUserQuestion.
R3 (exception): only if new facts change premise.

## Step 5: Judge + Document

```
Debate Result (Round {N})
Adopted: {choice} | Risk: {X}/9 | Judge: Leader/User
Accepted: {critiques + resolutions}
Rebutted: {critiques + rationale}
```

**Codex unavailable:** Soft → Leader self-review. Hard → AskUserQuestion.

## Rules
- Input ≤3000 chars. Max 2+1 rounds. No infinite loops.
- Entry: hard trigger or 6+. Participants: Proposer → Critic(Codex) → Judge.
