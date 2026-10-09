---
name: personal-coding-standards
description: Personal cross-project coding standards checklist. Use when implementing features, refactoring, adding constants/config/helpers/hooks, organizing modules, deciding whether to create an abstraction, or reviewing code/diffs in any language or framework.
---

# Personal Coding Standards — detailed guide

The always-on summary is in `~/.claude/CLAUDE.md`. This skill is the detailed checklist.
Project-specific rules override this file (except security).

## Before writing code

1. Read the surrounding code and the project's `CLAUDE.md` / rules / skills.
2. Search for existing constants, helpers, hooks, services, validators that already do the job.
3. Match the project's naming, folder layout and idioms, even where they differ from these defaults.

## Where does a constant/config go?

Choose the smallest scope that is still correct:

| Scope | Use when | Example |
|---|---|---|
| Local (top of file) | Used by one file only | a debounce delay in one component |
| Feature | Shared inside one feature/domain | `orders/constants.ts` with order statuses |
| Shared/domain | Used by several features | roles, permissions, route names |
| Config/environment | Varies per environment or is secret | API base URL, keys, OTP expiry |

Promote scope only when a second real consumer appears.

## What counts as a magic value

Literal strings/numbers carrying business meaning: statuses, states, events, roles, permissions, timeouts, limits, retry counts, routes, API paths, storage paths, pricing/business rules.
Not magic: `0`, `1`, `''`, array indexes, obvious math, UI-only trivial values.

## When to extract a module

Extract only if at least one holds: clear single responsibility, real reuse, or belongs to a specific domain.
Do NOT extract: single-use code with no domain meaning, wrappers that only forward calls, a file created "because the rule says so".
Split a file that has grown into a grab-bag of unrelated functions, by domain.

## Over-engineering guard (ask before adding an abstraction)

- Is there a second concrete use today? If not, keep it inline.
- Does it make the current architecture more complex? If yes, don't.
- Can I explain the reason from the current code, not a hypothetical future?

## Scope discipline

- Touch only what the task needs; no drive-by refactors or renames.
- Note unrelated problems in the reply instead of fixing them.
- Don't alter business behavior; if a fix seems to require it, ask first.

## Review mode

- Report only findings you are confident in, with evidence (file/line, concrete failure scenario).
- Don't edit code during a review unless asked.
- Prioritize: security → correctness → duplication of business logic → maintainability → style.

## Security checklist

- No secrets in source, tests, fixtures, or commits; `.env.example` with placeholders only.
- Server-only keys never reach client bundles (check framework public-env prefixes such as `VITE_`, `NEXT_PUBLIC_`, `EXPO_PUBLIC_`).
- Authorization enforced server-side / at the data layer, not only in UI.
