---
title:        "ADR-XX: Short Decision Title"
domain:       XX
folder:       XX-name
status:       proposed
date:         YYYY-MM-DD
deciders:     [moritz]    # who made this call
review_after: YYYY-MM-DD  # set 6-12 months out — forces re-evaluation
links:
  guide:   XX-name.md
  modules:
    - modules/XX-name/relevant-module.nix
  supersedes: []          # list ADR filenames this replaces, if any
---

# ADR-XX: Short Decision Title

> **Decision in one sentence.**
> We use X instead of Y because Z.

---

## Context

**What is the problem?**
Describe the situation that forced a decision. Be specific about constraints:
- System constraints (hardware, NixOS version, impermanence setup)
- Operational constraints (single admin, no GUI, remote-only access)
- Dependency constraints (what was already decided that limits options here)

**Why does this matter?**
What breaks or degrades if no decision is made, or if the wrong one is made?

**Forces at play:**
- Performance: ...
- Security: ...
- Maintainability: ...
- Reversibility: ...

---

## Considered Alternatives

### Option A: [Name] ← CHOSEN

**What it is:** Brief description.

**Pros:**
- Concrete, specific advantage
- Another specific advantage

**Cons:**
- Concrete, specific disadvantage (be honest — every option has one)

**Why chosen:** One sentence that directly addresses the dominant force from Context.

---

### Option B: [Name] ← REJECTED

**What it is:** Brief description.

**Pros:**
- Concrete advantage

**Cons:**
- The specific reason it was rejected

**Why rejected:** One sentence. If the answer is "we didn't try it", say so honestly.

---

### Option C: [Name] ← REJECTED
*(Add only if genuinely evaluated — not to pad the ADR)*

---

## Decision

**We choose Option A.**

Explicit scope: This decision applies to [what] and does NOT apply to [what].

Any non-obvious implementation constraint that flows directly from this decision:
- Constraint 1
- Constraint 2

---

## Consequences

**Positive:**
- What becomes easier or better after this decision
- What risk is eliminated

**Negative:**
- What becomes harder (be honest — every real decision has a cost)
- What flexibility is lost

**Risks introduced:**
- Specific risk, with mitigation: [how we address it]

---

## Validation

How will we know this decision is still correct?

- **Metric / signal:** What to observe (log pattern, performance number, failure rate)
- **Review trigger:** Re-evaluate this ADR if [specific condition] occurs
- **Scheduled review:** See `review_after` in frontmatter

---

<!-- SPEC-KIT CONSTRAINT REMINDER (delete before committing)
     This ADR answers WHY. It must NOT contain:
     - Nix code (→ belongs in the module)
     - Step-by-step instructions (→ belongs in the guide)
     - Vague rationale like "it's simpler" without explaining simpler for whom
     If you find yourself writing a how-to, stop and move it to the guide.
-->