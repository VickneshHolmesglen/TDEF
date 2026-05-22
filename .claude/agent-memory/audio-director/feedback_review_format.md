---
name: Review Format — Adversarial Audio Review
description: User provides a full audio spec block and asks for problems found, tagged [BLOCKING] or [RECOMMENDED]
type: feedback
---

When Vicknesh asks for an adversarial audio review, he provides the spec and the challenge questions together. The expected output is:

- A numbered list of issues
- Each tagged [BLOCKING] (prevents correct implementation) or [RECOMMENDED] (should be addressed for quality)
- Each with a concrete explanation of WHY it is a problem, not just what is missing
- A summary table at the end

**Why:** He is doing a review pass on all GDDs before implementation. He wants implementation-blocking gaps separated from polish/quality improvements so he can triage them against scope.

**How to apply:** Do not ask clarifying questions before delivering the review when the spec and challenge questions are already provided. Read the GDD directly to verify claims against the actual text before writing findings.
