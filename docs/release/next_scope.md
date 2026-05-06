# Next Release Scope - v0.6.0 (forward look)

**Theme:** Twin intelligence depth + capture hot-path optimization. Builds on v0.5.0 install reach.

## Candidate items

| ID | Title | RICE | Owner | Status |
|----|-------|------|-------|--------|
| H13 | Capture hook perf: persistent PS host (470ms -> <100ms cold) | 4.0 | RA -> OB | Needs feasibility research first |
| H10 | Twin few-shot retrieval: semantic over keyword overlap | 3.2 | RA -> SA+OB | Needs embedding model choice research |
| H12 | v1.0.0 public OSS release | 2.25 | PM+SA | Blocked on H1 (marketplace install) shipping first |

## Pre-conditions

- v0.5.0 H1 must ship to unblock H12
- RA must complete H13 + H10 research files before scope lock

## Likely scope cuts if effort overruns

- H12 (largest E=4.0w; can defer to v0.7.0 without losing momentum)
- H10 (research outcome may downgrade RICE if embedding cost prohibitive)

## Forward signals to watch

- Operator override rate trending up -> deprioritize H10 (current keyword retrieval already finding good exemplars)
- Capture hook timing showing >1s tail -> promote H13 to v0.5.0 patch
- External user requests via OSS release path -> reshape v0.7.0 around community needs
