# PAEI questionnaire (Adizes management roles)

**Construct:** Producer (P) · Administrator (A) · Entrepreneur (E) · Integrator (I).
**Items:** 30 (≈8 per role, mixed order to reduce response bias).
**Scale:** 1 = strongly disagree · 7 = strongly agree.
**Note:** Items are construct-targeted (not verbatim from any licensed inventory). Score directionally per role; absolute calibration only meaningful relative to your own retest.

## Items

| # | Statement | Role |
|---|-----------|------|
| 1 | I get more satisfaction from shipping than from designing the perfect plan | P |
| 2 | When something is broken I want to roll up my sleeves and fix it now | P |
| 3 | A short-term win is worth more than a slow architectural cleanup | P |
| 4 | I track concrete output (PRs merged, features shipped) more than process metrics | P |
| 5 | I lose patience when a meeting hasn't produced a decision in 15 minutes | P |
| 6 | I'd rather ship at 80% and iterate than wait for 100% | P |
| 7 | The job isn't done until it's in front of a real user | P |
| 8 | I measure my week by what I closed, not what I planned | P |
| 9 | A clear written process beats verbal coordination every time | A |
| 10 | I want change rolled out in versioned, traceable steps | A |
| 11 | "We've always done it this way" is a valid reason if the way works | A |
| 12 | I check that backups, logs, and rollback plans exist before I ship | A |
| 13 | Documentation that nobody reads still has value as a record | A |
| 14 | I prefer a slower release cadence with fewer regressions to a faster one with more | A |
| 15 | Naming conventions and folder layout deserve real time investment | A |
| 16 | I am drawn to bets that could 10× the product even if most fail | E |
| 17 | I find myself proposing scope expansions more often than scope cuts | E |
| 18 | When I read about a new tool I immediately think how to use it here | E |
| 19 | A mediocre product in a great market beats a great product in a mediocre market | E |
| 20 | I'd kill an existing feature to make room for a more interesting one | E |
| 21 | The best plans don't survive contact with users — so let's get to contact fast | E |
| 22 | I get bored once a feature reaches steady-state maintenance | E |
| 23 | Disagreement in a team means we haven't really aligned yet | I |
| 24 | I check whether the team is happy before I check whether the metric is up | I |
| 25 | I'd rather everyone agree on a B+ plan than win a debate for an A plan | I |
| 26 | Clear ownership matters less than shared context | I |
| 27 | I notice when a quiet teammate hasn't spoken in a while and pull them in | I |
| 28 | Conflict in code review is a smell, not a feature | I |
| 29 | A team that ships slowly together beats one that ships fast and resents each other | I |
| 30 | If a decision splits the team 50/50 I want one more conversation, not a vote | I |

## Scoring

For each role, sum the scores on its items, divide by item count → average 1–7.

```
P_score = avg of items 1-8
A_score = avg of items 9-15
E_score = avg of items 16-22
I_score = avg of items 23-30
```

Output `profile/paei.json`:

```json
{
  "computed_at": "ISO timestamp",
  "items": { "1": 6, "2": 7, ... },
  "scores": { "P": 6.1, "A": 3.4, "E": 5.7, "I": 4.2 },
  "dominant": "P",
  "secondary": "E",
  "code": "PaEi"
}
```

`code` uses uppercase for dominant (≥5), lowercase for present-but-not-dominant (3.5–4.9), absent (<3.5) omitted. Classic Adizes notation.
