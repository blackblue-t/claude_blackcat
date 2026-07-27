# Rules
## Structure

Rules are organized into a **common** layer plus **language-specific** directories:

```
rules/
├── common/          # Language-agnostic principles (always installed with --rules)
│   ├── agents.md
│   ├── coding-style.md
│   ├── development-workflow.md
│   ├── git-workflow.md
│   ├── hooks.md
│   ├── patterns.md
│   ├── performance.md
│   ├── security.md
│   └── testing.md
├── typescript/      # TypeScript/JavaScript specific
├── python/          # Python specific
└── rust/            # Rust specific
```

- **common/** contains universal principles — no language-specific code examples.
- **Language directories** extend the common rules with framework-specific patterns, tools, and code examples. Each file references its common counterpart.

## How rules reach the model

**Claude Code does NOT auto-load rules directories.** Dropping files into
`~/.claude/rules/` or `.claude/rules/` does nothing by itself — a rule file
only enters the system prompt when a `CLAUDE.md` imports it with the native
`@path/to/file.md` syntax.

## Installation

Use the project installer (`blackcat` shim or `install-project.sh` directly):

```bash
# From inside the target project:
blackcat --rules python              # common + python
blackcat --lean --rules typescript   # combine with any preset

# Or explicitly:
bash install-project.sh <project-path> --rules python,rust
```

This does two things:

1. Copies `rules/common/` plus each requested language set into the
   project's `.claude/rules/` (existing directories are kept untouched).
2. Appends a marked `@`-import block to the project's `CLAUDE.md`
   (creating the file if needed). The marker (`<!-- blackcat:rules -->`)
   makes the step idempotent — re-running never duplicates the block, and
   existing CLAUDE.md content is never modified.

To drop a single rule, delete its `@` line from CLAUDE.md; to drop them
all, delete the whole marked block. Note that every imported file consumes
context in every session — install only the sets the project needs.

> **Important:** Copy entire directories — do NOT flatten with `/*`.
> Common and language-specific directories contain files with the same names,
> and language-specific files reference their common counterparts via
> relative `../common/` links.

## Rules vs Skills

- **Rules** define standards, conventions, and checklists that apply broadly (e.g., "80% test coverage", "no hardcoded secrets").
- **Skills** (`skills/` directory) provide deep, actionable reference material for specific tasks (e.g., `python-patterns`, `golang-testing`).

Language-specific rule files reference relevant skills where appropriate. Rules tell you *what* to do; skills tell you *how* to do it.

## Adding a New Language

To add support for a new language (e.g., `golang/`):

1. Create a `rules/golang/` directory
2. Add files that extend the common rules:
   - `coding-style.md` — formatting tools, idioms, error handling patterns
   - `testing.md` — test framework, coverage tools, test organization
   - `patterns.md` — language-specific design patterns
   - `hooks.md` — PostToolUse hooks for formatters, linters, type checkers
   - `security.md` — secret management, security scanning tools
3. Each file should start with:
   ```
   > This file extends [common/xxx.md](../common/xxx.md) with <Language> specific content.
   ```
4. Reference existing skills if available, or create new ones under `skills/`.

## Rule Priority

When language-specific rules and common rules conflict, **language-specific rules take precedence** (specific overrides general). This follows the standard layered configuration pattern (similar to CSS specificity or `.gitignore` precedence).

- `rules/common/` defines universal defaults applicable to all projects.
- `rules/python/`, `rules/rust/`, `rules/typescript/`, etc. override those defaults where language idioms differ.

### Example

`common/coding-style.md` recommends immutability as a default principle. A language-specific `golang/coding-style.md` can override this:

> Idiomatic Go uses pointer receivers for struct mutation — see [common/coding-style.md](../common/coding-style.md) for the general principle, but Go-idiomatic mutation is preferred here.

### Common rules with override notes

Rules in `rules/common/` that may be overridden by language-specific files are marked with:

> **Language note**: This rule may be overridden by language-specific rules for languages where this pattern is not idiomatic.
