---
name: codebase-docs
description: Consult and maintain codebase documentation in docs/. Use when starting work on a feature area (check for relevant docs first), or after completing work that produced lasting insights about how things work, are structured, or should be approached.
---

# Codebase Documentation

The `docs/` directory contains long-lived reference documentation about this codebase — how things work, how they're used, and how we approach problems.

## Philosophy

These docs capture **durable knowledge** — things that are true about the codebase over time, not ephemeral details like current test results or TODO lists.

Good docs content:
- How a system or subsystem works (architecture, data flow, key abstractions)
- How to use internal tools, rake tasks, or workflows
- How we structure or approach recurring problem types
- Non-obvious conventions or decisions that aren't apparent from reading a single file
- Things an agent or developer _could_ learn by reading a lot of source code, but shouldn't have to

Bad docs content:
- Current metrics, test results, or baselines (these change constantly)
- Step-by-step plans for a specific task (use dex for that)
- Brainstorms or proposals (decide first, then document the outcome)
- Anything that duplicates inline code comments
- Descriptions of what specific code does — that's what the code itself is for

**Do not mirror the codebase in prose.** Docs should capture knowledge that sits _above_ the code: why things are the way they are, how systems connect, how to use tools. If a doc would need updating every time a method signature or file changes, it's too tightly coupled to the code. Write about concepts and workflows, not implementations.

## When Starting Work

Before diving into implementation on a feature area, check if relevant docs exist:

1. List `docs/` to see available guides
2. Read any that match the area you're working on
3. Follow conventions and patterns described there

## When to Create or Update Docs

After completing work, ask: "Did I learn something about this codebase that would save time next time?"

Create or update a doc when:
- You built a new tool, harness, or workflow that others will use
- You discovered how a non-obvious system works
- You established a pattern or convention that should be followed going forward
- You solved a problem in a way that reflects a reusable approach

## Writing Style

- **Flat structure**: files live directly in `docs/`, no subdirectories
- **Descriptive filenames**: `recipe-import-corpus.md`, `sqlite-multi-database.md`, not `guide-1.md`
- **Permanent facts over snapshots**: describe how things work, not what the current numbers are
- **Grep-friendly**: use concrete terms, system names, file paths, and command names so agents can find docs via search
- **Concise**: respect the reader's time. No filler introductions. Start with what it is and how to use it.
- **Reference file locations**: include paths to relevant source files, config, and commands
