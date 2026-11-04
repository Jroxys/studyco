# Orchestra — Task Queue

State machine: `queued -> running -> done | failed`
Ground truth lives in `.orchestra/state.json`; this file is for human reading.

---

## Task Template

```
### TASK-XXX — Task Title

| Field         | Value                                           |
|---------------|-------------------------------------------------|
| ID            | task-slug-here                                  |
| Priority      | p1 (critical) / p2 (normal) / p3 (low)         |
| Agent         | claude / codex / gemini / antigravity           |
| Depends on    | TASK-YYY, TASK-ZZZ  (or —)                     |
| Status        | queued / running / done / failed                |
| Report        | .orchestra/reports/task-slug-agent.md  (or —)  |

**What to do:**
< single, concrete unit of work >

**Completion Criteria:**
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Tests pass: `npm test`

**Notes / Context:**
< handoff note for the next agent >
```

---

## Active Tasks

### TASK-000 - Scaffold project (PLAN phase 0)

| Field | Value |
|---|---|
| ID | be-00-scaffold |
| Agent | codex |
| Depends on | - |
| Status | queued |

See PLAN.md section 9.

### TASK-001 - DB test harness (PLAN phase 1)

| Field | Value |
|---|---|
| ID | be-01-test-harness |
| Agent | codex |
| Depends on | be-00-scaffold |
| Status | queued |

See PLAN.md section 9.

### TASK-002 - Auth, me, refresh tokens (PLAN phase 2)

| Field | Value |
|---|---|
| ID | be-02-auth |
| Agent | codex |
| Depends on | be-01-test-harness |
| Status | queued |

See PLAN.md section 9.

### TASK-003 - Catalog and listings (PLAN phase 3)

| Field | Value |
|---|---|
| ID | be-03-catalog-listings |
| Agent | codex |
| Depends on | be-02-auth |
| Status | queued |

See PLAN.md section 9.

### TASK-004 - Requests lifecycle and wallet (PLAN phase 4)

| Field | Value |
|---|---|
| ID | be-04-requests-wallet |
| Agent | codex |
| Depends on | be-03-catalog-listings |
| Status | queued |

See PLAN.md section 9.

### TASK-005 - Messages and reviews (PLAN phase 5)

| Field | Value |
|---|---|
| ID | be-05-messages-reviews |
| Agent | codex |
| Depends on | be-04-requests-wallet |
| Status | queued |

See PLAN.md section 9.

### TASK-006 - Jobs, readiness, docs (PLAN phase 6)

| Field | Value |
|---|---|
| ID | be-06-jobs-ops |
| Agent | codex |
| Depends on | be-05-messages-reviews |
| Status | queued |

See PLAN.md section 9.

### TASK-007 - End-to-end and hardening (PLAN phase 7)

| Field | Value |
|---|---|
| ID | be-07-e2e-hardening |
| Agent | codex |
| Depends on | be-06-jobs-ops |
| Status | queued |

See PLAN.md section 9.


---

## Completed

_Move finished entries to state.json done array and add a one-line summary here._

---

## Agent Communication Protocol

```
Gemini/agy  analyzes  ->  writes .orchestra/reports/<slug>-analysis.md
Claude      reads it  ->  creates Codex task (updates TASKS.md + state.json)
Codex       implements->  writes .orchestra/reports/<slug>-impl.md
Claude      runs tests->  verifies npm test output
Claude      marks task done/failed in state.json
```

No two agents edit the same source file concurrently.
Each agent reads the report written by the previous agent before starting.
```
