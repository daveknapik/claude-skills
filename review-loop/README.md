# review-loop

Fresh-context adversarial review of your own branch, run from the session that wrote it. Reviewer
subagents that have never seen your conversation read the change at a frozen snapshot; the session
adjudicates every finding against the code, applies the safe fixes, asks you once about the rest, runs
one fix-review round, and hands back a short summary.

<!-- quickref:start -->
## Quick reference

```text
/review-loop [small|normal|deep] [KEY ...] [options]   review the current branch
/review-loop retro [KEY]                                record which findings were noise (no KEY: newest pending retro)
/review-loop help                                       print this block
```

| Option | Default | Effect |
| --- | --- | --- |
| `small` / `normal` / `deep` | recommended in the preflight question | review depth (table below) |
| `KEY ...` | from the branch name | ticket keys; the first names the run directory |
| `--model <m>` | built-in table | every reviewer in every round on `<m>` (`sonnet`, `opus`, `fable`, `haiku`, `inherit`) |
| `--model <key>=<m>,...` | built-in table | only the named reviewers: `conformance`, `correctness`, `security`, `unguided`, `round2`, `toolkit` |
| `--base <ref>` | profile `base_branch`, else you are asked | branch the work merges into, e.g. `origin/dev` |
| `--profile <name>` | `profiles/<repo>.md`, else the profile whose `repos:` lists the repo | use another profile |
| `--plan <path>` | attached when a candidate plan's H1 names a key; otherwise shown as a candidate | the plan file to review against |
| `--no-toolkit` | toolkit on when relevant | skip all `pr-review-toolkit` agents |
| `--help` | | same as `help` |

| Depth | Recommended when | Round 1 (model) | Toolkit adds (session model by default) | Round 2 (model) |
| --- | --- | --- | --- | --- |
| small | ≤ 5 files, ≤ ~150 lines, no risk path, no new non-test module | unguided (fable) | none | correctness (opus) |
| normal | no risk path | conformance (opus), correctness (fable), security (opus), unguided (opus) | silent-failure-hunter, comment-analyzer when relevant | correctness (opus) |
| deep | any risk path | same four | normal's two, plus pr-test-analyzer, type-design-analyzer when relevant | correctness (opus), plus security (opus) if a fix touched a risk path |

Model precedence: `--model` flag > profile `models:` > this table.

Files: run output in `<work_root>/reviews/<KEY>/<YYYY-MM-DD-HHMM>/` (`summary.md`, `ledger.md`,
`round-1/*.md`, `round-2/*.md`); lessons in `<work_root>/review-lessons.md`. `work_root` comes from the
profile, default `~/.claude/scratchpad/<repo>`.

The preflight question shows all of this before anything runs and lets you change it. A bare
`/review-loop` is the normal invocation.
<!-- quickref:end -->

## What happens in a run

1. **Preflight.** Snapshots the working tree (committed, uncommitted and untracked files) as a git tree
   object without touching your index or branch. Stops at once if there is nothing to review. Finds the
   ticket keys and the ticket text, attaches the plan file if its H1 names a key (otherwise shows it as a
   candidate you can attach), runs the changed tests, reruns the plan's premise check if the profile says
   how, and recommends a depth. One question shows all of it, starting with the repo and branch.
2. **Round 1.** Reviewers start in parallel, each told only to read the brief, its lens and
   `context.md`. Each writes its report header first and appends findings as it goes, so you can open
   `round-1/<lens>.md` mid-run.
3. **Adjudication.** Every finding is checked against the code and gets one ledger row. Confirmed fixes
   inside the ticket's files and off risk paths are applied straight away. Everything else (rejected
   blocking findings, premise challenges, risk-path fixes, fixes shaped differently from the reviewer's
   proposal, PR-body text) comes to you as **one** batched question.
4. **Round 2.** One fresh correctness reviewer reads only the fix diff, attacks every rejection, and
   checks each fix's shape. Security joins when a fix touched a risk path. There is no round 3; anything
   still open is yours.
5. **Summary.** Asks first, counted, then what changed, what was rejected and why, tickets drafted, what
   nobody checked, and models and tokens per reviewer.
6. **Retro.** Which findings were noise? Approved lessons go to the lessons file, which reviewers read at
   the start of the next run. "Skip for now" leaves the retro pending; `/review-loop retro` with no key
   reopens the newest run whose retro is still pending.

## What it never does

Commit, push, post to GitHub, Linear or Slack, edit a PR body, or create a ticket without your yes in
that run. Reviewers never see the working tree, never run tests and never call cloud APIs or MCP tools.

## Re-review after later changes

Run `/review-loop` again on the same branch after PR feedback or more work. If the merge-base has not
moved, only the change since the last reviewed snapshot is reviewed (`mode: delta`), and reviewers get
the previous ledger so settled findings are not raised again without new evidence. If the merge-base
moved, the whole branch is reviewed (`mode: full`) and the preflight question says why. An interrupted
run resumes from where its ledger says it stopped.

## Profiles

Repo-specific settings (base branch, tracker, test commands, risk paths, extra lens rules, models) live
in `profiles/<repo>.md`. See [`profiles/README.md`](profiles/README.md) for the format and
[`profiles/example.md`](profiles/example.md) for a filled-in one. Profiles other than the example are
gitignored. Without a profile the run uses defaults and says so. Several repos of one organisation can
share one profile: name the file as you like (not `README.md` or `example.md`, which are tracked), list
the repos in its `repos:` field, which is how the lookup finds it, and give each a `## Repo: <name>`
section for what differs (see
[Sharing one profile across several repos](profiles/README.md#sharing-one-profile-across-several-repos)).

Keep a profile to settings plus the few repo facts that the repo's own docs (AGENTS.md, CLAUDE.md) do not
hold, and point at files rather than copying their content. Reviewers already load those docs, so a
copied rule only adds something to drift. Each run checks every path the profile names against the
code and warns in the preflight question when one matches nothing, so a stale profile shows itself.

## The lessons file

`<work_root>/review-lessons.md`, about 40 lines, curated at retro. Lessons that are stable repo facts
belong in the repo's AGENTS.md (the retro drafts the change for you to put through review), or in the
profile's lens addenda when they do not belong in the repo; lessons about reviewer behaviour in any repo
belong in your global CLAUDE.md. Prune by running `/review-loop retro` and asking for a merge, or
edit the file directly.

## Examples

```text
/review-loop
```

Normal PR: preflight recommends `normal`, four reviewers plus relevant toolkit agents run, safe fixes
land, one question for the rest, round 2, summary.

```text
/review-loop small --no-toolkit
```

A docs-only fix: one unguided reviewer, no toolkit agents, round 2 only if something was fixed or
rejected.

```text
/review-loop deep --model fable
```

A migration: every reviewer, toolkit agents included, runs on fable; round 2 adds security if a fix
touched the migration.
