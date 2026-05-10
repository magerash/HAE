# HEXACO Brief Inventory

**Construct:** 6 personality factors — Honesty-Humility (H), Emotionality (E), eXtraversion (X), Agreeableness (A), Conscientiousness (C), Openness (O).
**Items:** 24 (4 per factor, mixed order, ~half reverse-keyed).
**Scale:** 1 = strongly disagree · 5 = strongly agree.
**Note:** Items are construct-targeted, not verbatim from HEXACO-PI-R or HEXACO-60 (licensed). For research-grade scores, replace items with full 60-item HEXACO-PI-R after obtaining license. This brief inventory is sufficient for twin-prompt persona generation.

## Items

| # | Statement | Factor | Reverse |
|---|-----------|--------|---------|
| 1 | I would not bend the truth to gain a small advantage | H | no |
| 2 | If I were sure no one would catch it, I'd be willing to cut corners | H | yes |
| 3 | I'd refuse a job that paid well but required selling something I didn't believe in | H | no |
| 4 | I think I deserve more recognition than most people get | H | yes |
| 5 | I worry more than the average person about things going wrong | E | no |
| 6 | I am rarely shaken by setbacks others find upsetting | E | yes |
| 7 | I cry more easily than most people I know | E | no |
| 8 | I face physical danger with calm | E | yes |
| 9 | I enjoy being the center of attention in a group | X | no |
| 10 | I prefer one-on-one conversations to large gatherings | X | yes |
| 11 | I make the first move when meeting new people | X | no |
| 12 | At the end of a busy day I want to be alone, not with people | X | yes |
| 13 | I forgive people quickly even after a real wrong | A | no |
| 14 | I hold grudges longer than I'd like to admit | A | yes |
| 15 | I find it easy to keep working with someone after a sharp disagreement | A | no |
| 16 | When someone breaks a promise I lose trust permanently | A | yes |
| 17 | I keep a clean workspace and a tidy file system | C | no |
| 18 | I often start projects I don't finish | C | yes |
| 19 | I plan tasks in advance and stick to the plan | C | no |
| 20 | I make decisions on impulse and figure out the consequences later | C | yes |
| 21 | I'm drawn to ideas from fields I know nothing about | O | no |
| 22 | I prefer familiar routines to new experiences | O | yes |
| 23 | I'll change my mind quickly when shown new evidence | O | no |
| 24 | Abstract theory bores me; I want concrete results | O | yes |

## Scoring

Reverse-keyed items: invert (`6 - response`). Then per factor, sum and divide by 4 → 1–5.

```
H = avg(1, 6-r2, 3, 6-r4)
E = avg(5, 6-r6, 7, 6-r8)
X = avg(9, 6-r10, 11, 6-r12)
A = avg(13, 6-r14, 15, 6-r16)
C = avg(17, 6-r18, 19, 6-r20)
O = avg(21, 6-r22, 23, 6-r24)
```

Output `profile/hexaco.json`:

```json
{
  "computed_at": "ISO timestamp",
  "version": "brief-24",
  "items": { "1": 4, "2": 1, ... },
  "scores": { "H": 4.5, "E": 2.0, "X": 4.0, "A": 3.5, "C": 4.5, "O": 4.8 },
  "high":   ["H", "X", "C", "O"],
  "low":    ["E"]
}
```

`high` = score ≥ 3.75. `low` = score ≤ 2.25.
