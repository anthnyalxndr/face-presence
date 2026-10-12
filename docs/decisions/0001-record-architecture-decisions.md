# 1. Record architecture decisions

- **Status:** accepted
- **Date:** 2026-06-19

## Context

We need a lightweight, durable record of *why* significant choices were made,
so that future-us (and coding agents) don't re-litigate settled decisions or
silently violate constraints whose rationale lives only in someone's head.

## Decision

We use lightweight Architecture Decision Records (ADRs), one Markdown file per
decision in `docs/decisions/`, numbered sequentially. Each ADR captures the
context, the decision, and its consequences. Keep them short.

To add one: copy this file to `000N-short-title.md`, bump the number, write it.

## Consequences

- Decisions are discoverable and reviewable in PRs.
- Agents can read `docs/decisions/` to understand constraints before changing code.
- Superseded decisions are kept (marked `superseded by 000N`) rather than deleted.
