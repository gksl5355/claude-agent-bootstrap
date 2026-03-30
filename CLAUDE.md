# Team Orchestrator

## Language Rules
- All skill content, agent prompts, state files, events → **English**
- User-facing output → match user's language (Korean in → Korean out)
- MiniMax workers → English only. Never send Korean to MiniMax.
- Leader↔Agent communication → English

## Architecture
- Skills in `.claude/skills/`: spawn-team, debate, doctor, ralph
- Hooks: teammate.sh (model routing), resume.sh, writeback.sh, detect.sh
- Run artifacts: `.claude/runs/{date}-{NNN}/` (plan.yml, state.yml, events.yml, report.yml)
- Learning: Forge integration (ingest → resume → recommend)

## Model Routing
| Role | Model | Reason |
|------|-------|--------|
| Leader | Sonnet | Orchestration, judgment |
| Planner | Opus (COMPLEX only) | Architecture decisions |
| Workers | MiniMax M2.7 (default) | Implementation, testing. Cost-effective. |
| Sub-agents | Haiku | Debugger, build-fixer. Depth-1 only. |
| Fallback | Haiku | When MiniMax unavailable |

## Token Discipline
- Leader: orchestrate only. Delegate all coding to workers.
- Workers on MiniMax: they code directly (MiniMax IS the agent).
- Workers on Claude: use mm_agent MCP tool to delegate coding to MiniMax.
- Context Map generated once → injected into all agents. No re-exploration.
- wc -l before Read. 500+ → offset+limit. No repeat reads.
