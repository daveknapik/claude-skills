# Profiles

A profile holds everything repo-specific: base branch, ticket tracker, test commands, risk paths and
extra rules for each lens. The skill core never names a company, a tracker project or a path.

- Lookup: `profiles/<repo>.md`, where `<repo>` is the basename of `git remote get-url origin` without
  `.git`; else the profile whose `repos:` field lists `<repo>` (a shared profile, below).
  `--profile <name>` overrides the lookup.
- Every file in this directory except `README.md` and `example.md` is gitignored, so work-specific
  profiles stay on the machine. Recreate them after a fresh clone; `example.md` is a starting point.
- No profile is fine: the run uses the defaults below and the preflight question says
  "profile: none, defaults".

## Format

A profile is Markdown with these sections. All are optional; a missing one means "use the default".

### `## Fields`: one fenced `yaml` block

| Field | Meaning | Default without it |
| --- | --- | --- |
| `base_branch` | Ref the branch merges into, e.g. `origin/dev` | none: the run asks (or pass `--base`); a repo's default branch is not assumed |
| `ticket_key_regex` | Pattern (Python `re` syntax) for ticket keys in branch names, matched case-insensitively and upper-cased, e.g. `PROJ-\d+`. With a capture group, the key is group 1 (e.g. `(?:^\|/)(\d+)-` for `123-fix-x` branches) | `[A-Z]{2,}[0-9]*-[0-9]+`, offered for confirmation; else the `--plan` H1; else the branch name |
| `tracker` | `linear`, `github` or `none` | `none` |
| `tracker_settings` | Map: for `linear`, `team_id`, `label`, `assignee`, `state`; for `github`, `repo`, `labels` | none |
| `ticket_template` | Where the ticket template lives (a path and section name) | none: drafts use Problem / Evidence / Outcome / Acceptance Criteria |
| `ticket_attack_brief` | Brief a fresh agent uses to attack a ticket draft before it is filed | none: no attack pass |
| `test_cmd` | Test command; placeholders `{changed_tests}`, `{changed_py}`, `{changed_files}` | detected from `uv.lock`/`pyproject.toml` or `package.json`, else "not run" |
| `lint_cmd` | Lint command, same placeholders | none |
| `pr_create_skill` | Skill that creates PRs in this repo, named when the summary hands over PR text | none |
| `work_root` | Where run files and the lessons file go; `{repo}` expands | `~/.claude/scratchpad/{repo}` |
| `models` | Map of `conformance`, `correctness`, `security`, `environment`, `coherence`, `fix`, `unguided`, `round2`, `toolkit` to `sonnet`/`opus`/`fable`/`haiku`/`inherit`. Set only keys you want to change: setting `unguided` also cancels the built-in "fable at depth small" rule | the built-in table in `SKILL.md` |
| `toolkit_extra` | List of extra `pr-review-toolkit` agents to run, by short name, e.g. `[code-reviewer]` | none |
| `toolkit_skip` | List of toolkit agents never to run here, by short name. Wins over `toolkit_extra` and risk rows | none |
| `toolkit_notes` | Text pasted into every toolkit agent's prompt: the repo's logging and error-handling rules | none |
| `environment_sources` | List of outside sources the environment lens may read, read-only, each a map with `kind` (`repo`, `gh`, `cloud`, `chat`, `cli`) and how to reach it: for `repo`, `path` and `ref` (the deployed ref when the change acts on what is deployed); for `gh`, `repos`; for `cloud`, the read-only `profile` and `region`; for `chat`, the tool names; for `cli`, the commands whose `--help` may be read. The coordinator checks each is reachable before the run | none: the environment lens does not run, and the preflight question says what it would need |

### `## Risk paths`

A table `| Pattern | Why | Extra agent |`. The Pattern cell holds one or more comma-separated globs in
backticks (`**` crosses directories); any changed path matching one makes the recommended depth `deep`.
A Pattern starting `diff text matching` holds a Python `re` expression instead, matched
case-insensitively against added lines; `\|` inside it is the Markdown escape for `|`, so read it as `|`.
`Extra agent` names a toolkit agent by short name to add when that row matches, or `none`. This table
replaces the generic list in `SKILL.md`.

### `## Premise rerun`

Free text: how the coordinator reruns a plan's premise check in this repo (which credentials, which
tools, which tools not to use). Without it, the premise check is recorded as "not rerun: no method in
profile".

### `## Lens addenda`

Subsections `### conformance`, `### correctness`, `### security`, `### environment`, `### coherence`, each a bullet list of repo facts the
lens should check. List only facts the repo's own docs (AGENTS.md, CLAUDE.md) do not hold, since
reviewers load those already; a restated rule only adds something to drift. Every backticked repo path
here and in `toolkit_notes`, and every risk-path glob, is checked at each run, and one that matches
nothing is reported as a stale-profile warning. Each lens reviewer reads only its own subsection; the unguided reviewer reads all
three. Keep them as rules plus a pointer to
the file that holds the detail, not copies of it.

## Sharing one profile across several repos

One organisation's repos usually share a tracker, ticket template and base branch, and differ in test
commands, risk paths and repo facts. Put them in one file instead of copying the shared part:

- `## Fields` gains `repos: [repo-a, repo-b]` and holds the shared fields.
- Top-level `## Risk paths`, `## Premise rerun` and `## Lens addenda` apply to every listed repo.
- One `## Repo: <repo>` section per repo, containing any of `### Fields` (a `yaml` block),
  `### Risk paths`, `### Premise rerun` and `### Lens addenda` (with `#### conformance`, `#### correctness`,
  `#### security`), plus free-text notes.

At each run the coordinator merges the shared sections with that repo's section. A scalar field in the
repo section (`base_branch`, `ticket_key_regex`, `tracker`, `ticket_template`, `ticket_attack_brief`,
`test_cmd`, `lint_cmd`, `pr_create_skill`, `work_root`) replaces the shared one. `toolkit_notes` is the
shared text followed by the repo's. `tracker_settings` and `models` merge key by key, the repo's value
winning. `toolkit_extra`, `toolkit_skip` and `environment_sources` are the union of both lists; a repo section cannot undo a
shared `toolkit_skip` entry (skip wins over `toolkit_extra`), so put a skip that only some repos want in
those repos' sections. Risk-path rows and lens-addenda
bullets are combined; a repo's premise-rerun text is added after the shared one. The result goes to
`RUN/profile.md` in the single-repo format, and reviewers read only that file, so they never see
another repo's rules.

Keep anything true of only one repo in that repo's `## Repo:` section, not in the shared part:

- Backticked repo paths in `## Lens addenda` and `toolkit_notes`, and risk-path globs, are checked
  against the tree of the repo being reviewed. A path that exists in only one listed repo belongs under
  that repo's section; in a shared section it warns "profile path `X` matches nothing; the profile may
  be stale" on every run in the other repos.
- `work_root` must differ per repo (keep `{repo}` in it). Runs live under `work_root/reviews/<KEY>/` and
  lessons in `work_root/review-lessons.md`, so a shared `work_root` makes two repos share a lessons
  file, and a key used in both (one ticket touching two repos, or the same branch name when there is no
  ticket key) makes preflight resume or re-review the other repo's run.
