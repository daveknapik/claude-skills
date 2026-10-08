# Profile: example-service

A minimal profile for a generic Python service with issues on GitHub. Copy to `profiles/<repo>.md`
and edit.

## Fields

```yaml
base_branch: origin/main
ticket_key_regex: '(?:^|/)(\d+)-'   # branches like 123-fix-x or me/123-fix-x; key = issue number
tracker: github
tracker_settings:
  labels: [review-followup]
test_cmd: uv run pytest -q {changed_tests}
lint_cmd: uv run ruff check {changed_py}
work_root: ~/.claude/scratchpad/{repo}
models:
  correctness: opus
toolkit_skip: [pr-test-analyzer]
toolkit_notes: |
  Logging goes through the standard `logging` module; errors are logged with `exc_info=True`.
```

## Risk paths

| Pattern | Why | Extra agent |
| --- | --- | --- |
| `alembic/**` | schema changes, rollback | none |
| `.github/workflows/**` | deploy pipeline | none |
| `src/*/auth/**` | authentication | none |
| `pyproject.toml`, `uv.lock` | dependencies | none |
| `src/*/models.py` | data model | `type-design-analyzer` |
| diff text matching `(?<![a-z])(secret\|password\|api_?key\|private_key)s?(?![a-z])` | credentials | none |

## Lens addenda

### correctness

- All datetimes are timezone-aware UTC; a naive `datetime.now()` is a finding.

### security

- Every route under `src/*/api/` takes the current user from the auth dependency; a route without it is
  a finding.
