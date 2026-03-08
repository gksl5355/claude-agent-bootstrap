# F2-external: Benchmark

Post-v1.0 one-off benchmark for portfolio metrics.

## Purpose

Quantitative comparison: **single agent vs spawn-team** on reproducible tasks.

## Method

1. Select 3-5 public repos with known, reproducible issues
2. Run each task twice: single agent, then spawn-team
3. Record per-run: pass/fail, retries, wall_clock_minutes
4. Generate `comparison.yml`

## Output

```yaml
# comparison.yml
benchmark_date: "2026-03-XX"
tasks:
  - repo: "user/repo"
    issue: "description"
    single_agent:
      result: PASS | FAIL
      retries: N
      wall_clock_min: N
    spawn_team:
      result: PASS | FAIL
      retries: N
      wall_clock_min: N
      agents: N
      team_config: "sonnet:N + haiku:N"

summary:
  single_pass_rate: 0.X
  team_pass_rate: 0.X
  avg_speedup: X.Xx
```

## Candidate Repos

TBD — select repos with:
- Clear issue descriptions
- Reproducible test suites
- Moderate complexity (not trivial, not massive)

## Status

Not yet executed. Run after F1/F3/F4/F5/F6 are stable.
