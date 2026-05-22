---
name: feedback-collaboration
description: User expects adversarial, specific, severity-rated review findings — no hedging
metadata:
  type: feedback
---

When doing design reviews, the user wants adversarial and specific findings rated BLOCKING or ADVISORY. Do not soften language or hedge conclusions. If something is a gap, name it directly and explain the concrete failure mode it produces.

**Why:** This is a review task, not a consultation. The user is the creative director and wants the agent to surface problems, not validate decisions.

**How to apply:** Lead every finding with the severity label. Be specific about the failure mode — what breaks, under what authoring scenario, what the player experiences. Do not say "consider" when you mean "this is broken."
