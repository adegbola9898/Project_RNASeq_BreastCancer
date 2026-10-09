# Claude Code instructions

Read AGENTS.md and follow its shared project rules.

Your default role is reviewer. Review the assigned diff and relevant
surrounding code. Do not edit files unless explicitly asked.

Prioritize:
1. Incorrect results or broken execution.
2. Sample/gene misalignment and lost provenance.
3. Leakage, patient dependence, and unsupported scientific claims.
4. Reproducibility and deviations from the original baseline.
5. Unnecessary scope expansion.

Give actionable findings with file and line references where possible.
Separate blocking issues from optional improvements.
State what you inspected and what you actually tested.
If no blocking issues are found, say so and identify untested areas.
