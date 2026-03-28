# Contributing and Implementation Workflow

## Feature implementation workflow

When adding a new feature:

1. Define the relevant environment variables.
2. Update `README.md` with user-facing configuration details.
3. Add or modify the appropriate init script or service.
4. Add detailed docs for the feature when it needs explanation.
5. Test locally with targeted validation first.
6. Run broader end-to-end validation when the change touches mail flow or startup behavior.
7. Verify backward compatibility with the feature disabled.

## Suggested file roles

| File | Purpose | Recommended content |
| --- | --- | --- |
| `README.md` | User-facing overview and setup | Feature overview, runtime config, basic commands |
| `docs/ARCHITECTURE.md` | System layout and service relationships | Container architecture, init order, service inventory |
| `docs/CONTRIBUTING.md` | Contributor workflow | Feature implementation workflow, file responsibilities |
| `docs/TESTING.md` | Validation and SUT workflow | Test flow, compose commands, feature validation patterns |
| `docs/TROUBLESHOOTING.md` | Operational debugging help | Common issues table, debug checklist |
| `docs/patterns/init-scripts.md` | Reusable init script conventions | Init script template, early-exit rules, logging examples |
| `docs/patterns/services.md` | s6-overlay service conventions | Directory structure, run script examples, dependencies |

## Example feature delivery pattern

For a typical optional feature:

1. Add an env var such as `FEATURE_NAME` or `FEATURE_ENABLED`.
2. Implement startup handling in the correct init script or service.
3. Generate any runtime config from env vars or Docker Secrets.
4. Log configuration and skip paths clearly.
5. Update user-facing docs.
6. Validate disabled, enabled, and invalid-config paths.

## Development priorities

- Keep changes small and easy to review.
- Prefer consistency with nearby code over generic cleanup.
- Preserve backward compatibility.
- Avoid making operator setup harder.

## Documentation priorities

- Write documentation in Markdown.
- Use relative paths in docs.
- Keep documentation free of avoidable lint errors.
- Use headings that match the actual structure of the content.

### Markdown lint rules to watch

When editing docs, pay attention to these common rules:

- `MD022` — blanks around headings
- `MD031` — blanks around fenced code blocks
- `MD032` — blanks around lists
- `MD036` — avoid emphasis as a heading substitute
- `MD040` — fenced code blocks should specify a language; use `text` when needed
- `MD060` — table formatting should use spaces around pipe separators

## Path handling

Do not leak developer-specific absolute paths in documentation. Use repo-relative paths instead.
