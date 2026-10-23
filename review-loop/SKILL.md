---
name: review-loop
description: Fresh-context adversarial review of the author's own branch, run from the session that wrote it. Starts reviewer subagents that have never seen the conversation, adjudicates every finding against the code, applies the safe fixes, asks one batched question for the rest, runs one fix-review round, and hands back a short summary plus a retro that curates a per-repo lessons file. Use when asked to "review my branch", "run the review loop", "fresh reviewers on this", "/review-loop", "review-loop retro", or "how do I use review-loop".
argument-hint: "[small|normal|deep] [KEY] [--base ref] [--model m|key=m] [--profile p] [--plan path] [--no-toolkit] | retro [KEY] | help"
---

# Review loop

You are the coordinator, running in the author's session after implementation. You start reviewers,
check their work, adjudicate, fix, and report. You never review the code yourself in round 1: the point
is fresh context, and you have none.

Arguments as typed: `$ARGUMENTS`

## Files

`SKILL_DIR` is the directory holding this file. Resolve it to an absolute, symlink-free path once
(`cd <base directory shown when this skill loaded> && pwd -P`; fallback `cd ~/.claude/skills/review-loop && pwd -P`)
and use that absolute path in every prompt, because reviewers start with no context.

In every command you or a prompt writes, put shas in literally, or brace the variable (`"${REF}:path"`).
In zsh, `$REF:app/x.py` applies the `:a` modifier and reads the wrong path.

| File | Who reads it |
| --- | --- |
| `SKILL_DIR/reviewer-brief.md` | every reviewer, first |
| `SKILL_DIR/lens-conformance.md`, `lens-correctness.md`, `lens-security.md`, `lens-environment.md`, `lens-coherence.md`, `lens-fix.md` | the lens reviewer of that name |
| `SKILL_DIR/snapshot.sh` | you only |
| `SKILL_DIR/profiles/<repo>.md` | you; reviewers read only lens addenda |
| `SKILL_DIR/profiles/README.md` | you, to parse a profile |
| `SKILL_DIR/README.md` | the user; `help` prints its quick reference |

Run files go in `WORK_ROOT/reviews/<KEY>/<YYYY-MM-DD-HHMM>/` (`RUN`). `WORK_ROOT` is the profile's
`work_root`, default `~/.claude/scratchpad/<repo>`. Lessons: `WORK_ROOT/review-lessons.md`.
Nothing goes in the repository tree and nothing in a session temp directory.

## Invariants

- Never commit, push, edit a PR body, write to a tracker or chat tool, or create a ticket without the
  user's explicit yes in this run. Tree snapshots make commits unnecessary.
- Reviewers get a tree sha and files, never the working tree, never MCP, never cloud APIs, never tests.
  Start them as fresh agents, never as a fork (a fork inherits this conversation).
- No code edits while a round is running. All fixes land between rounds.
- A reviewer report without a valid header is "not run", never "no findings".
- Severity labels are for the user's adjudication only. Nothing written into a PR body, ticket or code
  comment carries "blocker", a correction notice, or a list of review decisions.
- Two rounds at most per run. Nothing is held for a third. Never start reviewers outside a run.
- **Full runs at milestones; fix mode between them.** A full run reviews the branch before a PR is
  opened, and again after a round of human review if the fixes changed behaviour or added more than a
  few lines. A batch of fixes in between (answers to review comments from people or bots, or to findings
  of an earlier run) is reviewed with `/review-loop fix` (see Fix mode): one reviewer, one pass. New
  feature work after a milestone gets a full run (see Re-review).

## Arguments

```text
/review-loop [small|normal|deep] [<KEY> ...] [--base <ref>] [--model <m> | --model <key>=<m>,...]
             [--profile <name>] [--plan <path>] [--no-toolkit]
/review-loop fix [<KEY>] [--since <ref>] [--comments <path>] [--base <ref>] [--model <m>]
/review-loop retro [<KEY>]
/review-loop help            (also: --help, "how do I use review-loop")
```

- A depth word becomes the first option of the preflight question; the question is still asked.
- `<KEY>`: ticket keys. The first one names the run directory.
- `<m>` is one of `sonnet`, `opus`, `fable`, `haiku`, `inherit`. `<key>` is one of `conformance`,
  `correctness`, `security`, `environment`, `coherence`, `fix`, `unguided`, `round2`, `toolkit`.
- `--model <m>` sets every reviewer in every round, toolkit agents included. `--model <key>=<m>,...` sets
  only the named keys. Precedence: flag > profile `models:` > built-in table.
- `--profile <name>` uses `SKILL_DIR/profiles/<name>.md` instead of the repo-name lookup. A shared
  profile still contributes only the current repo's `## Repo:` section; if the repo is not in its
  `repos:` list, ask before using it.
- `--plan <path>` names the plan file and skips plan resolution.
- `--no-toolkit` skips every toolkit agent for this run.
- `--base <ref>` names the branch the work merges into (e.g. `origin/dev`), overriding the profile.
- `--since <ref>` (fix mode) is the commit the fixes start from, for example the one a reviewer reviewed.
- `--comments <path>` (fix mode) is a file with the review comments the fixes answer.

**help**: print the block between `<!-- quickref:start -->` and `<!-- quickref:end -->` in
`SKILL_DIR/README.md` verbatim, then stop. Start no agents, run no git commands.

**fix**: run Fix mode (below) instead of Steps 0–4.

**retro**: jump to Step 5 for the newest run of `<KEY>`; with no key, the newest run under `WORK_ROOT/reviews/`
whose State has `retro: pending`.

Unknown flags or values: say which, show the usage block, stop.

## Built-in defaults

### Models

| Key | Default | Notes |
| --- | --- | --- |
| `conformance` | opus | |
| `correctness` | fable | |
| `security` | opus | round 1, and round 2 when triggered |
| `environment` | opus | when relevant (below), round 1 and round 2 |
| `coherence` | opus | when relevant (below) |
| `unguided` | opus | fable at depth small, where it is the only reviewer, unless a flag or profile sets `unguided` |
| `round2` | opus | the round-2 correctness reviewer |
| `fix` | opus | the one reviewer in fix mode |
| `toolkit` | inherit | `inherit` = omit the Agent `model` parameter |

Pass the resolved model as the Agent tool's `model` parameter; it overrides an agent definition's own
model. If every reviewer resolves to `sonnet` (or `haiku`), add the warning line "all reviewers on
<m>: expect fewer confirmed findings" to the preflight question.

### Depth

| Depth | Recommend when | Round 1 | Toolkit adds | Round 2 |
| --- | --- | --- | --- | --- |
| small | ≤ 5 files, ≤ ~150 changed lines, no risk path, no new non-test module | unguided | none | correctness (`round2`) |
| normal | anything else without a risk path | conformance, correctness, security, unguided | `silent-failure-hunter`, `comment-analyzer` when relevant | correctness |
| deep | any risk-path match | same four | normal's two, plus `pr-test-analyzer`, `type-design-analyzer` when relevant | correctness, plus security if an applied fix touched a risk path |

At **every** depth, `small` included, add these lenses when they are relevant. They exist because a small
change to instructions can be wrong in ways no other lens looks for, and size does not predict that.

| Lens | Relevant when | Round 2 |
| --- | --- | --- |
| `coherence` | at least half the changed lines are prose (Markdown, docstrings, comments), or a changed file is instructions for a person or an agent (a skill, runbook, prompt, playbook) | no |
| `environment` | the changed text tells someone to run commands or makes claims about systems outside `REPO_ROOT` (other repos, CI runs, cloud resources, chat, CLIs), **and** `ENVIRONMENT_SOURCES` is not `none` | yes, when an applied fix changed a command or such a claim |

When `environment` is relevant but no source is reachable, it does not run: the preflight question says
so, with what a profile's `environment_sources` would need to name.

### Toolkit relevance

Toolkit agents come from the optional `pr-review-toolkit` plugin. In profiles and file names they go by
short name (`silent-failure-hunter`); the Agent `subagent_type` is `pr-review-toolkit:<short name>`.
Relevance is read from the patch (added and removed lines) and the changed-file list.

| Short name | Relevant when | Depths | Id prefix |
| --- | --- | --- | --- |
| `silent-failure-hunter` | the patch adds or changes `try`/`except`/`catch`, a default or fallback return, a retry, or error logging | normal, deep | `SFH` |
| `comment-analyzer` | the patch touches `docs/**` or any `*.md`, or adds or changes comments or docstrings | normal, deep | `CMT` |
| `pr-test-analyzer` | tests changed, or non-test code changed with no test change | deep | `TEST` |
| `type-design-analyzer` | a new model, dataclass, schema or typed record is added, or a matched profile risk row names it | deep | `TYPE` |
| `code-reviewer` | only when the profile lists it in `toolkit_extra` | as listed | `CR` |

The profile's `toolkit_extra` adds agents and `toolkit_skip` removes them. `toolkit_skip` always wins:
a matched risk row cannot re-add a skipped agent. An agent type missing from this
session's available-agents list, or an Agent call rejected for an unknown `subagent_type`, is recorded
as "not installed, skipped" and the run continues.

### Risk paths without a profile

Changed paths matching these globs (`**` crosses directories): `**/migrations/**`, `**/alembic/**`,
`.github/workflows/**`, `**/infra/**`, `**/terraform/**`, `**/cdk/**`, `**/auth/**`, `**/Dockerfile*`,
`**/requirements*.txt`, `**/pyproject.toml`, `**/go.mod`, `**/Cargo.toml`; `**/package.json` only when
a line inside `dependencies`, `devDependencies` or `peerDependencies` changed. Lockfiles alone do not
count.
Added lines matching this Python `re` expression, case-insensitive. A credential word counts only as an
assignment (followed by `:` or `=` and a value), so `DB_PASSWORD=x` matches and prose such as "keep
secrets out of the report" does not; the key shapes count anywhere:
`(?<![a-z])(secret|password|passwd|api_?key|credential|access_token|private_key|client_secret)s?(?![a-z])\s*[\"']?\s*[:=]\s*[\"']?[^\s\"',;)]|sk_(live|test)_|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|AKIA[0-9A-Z]{16}`.
A profile's `## Risk paths` table replaces this list.

Evaluate every `diff text matching` expression, this default one included, with
`uv run --no-project python` (`re.search(pattern, line, re.I)` over the added lines of the patch:
lines starting `+` but not `+++`). Never with `grep -E`: BSD grep has no lookbehind, and the user's
interactive grep may be a different implementation, so a shell check gives different answers in
different shells.

## Step 0. Preflight (before any reviewer starts)

Hold everything in memory until step 12. Create no directory before then: an aborted preflight must leave
nothing behind, because a leftover run directory would later look like a run to resume.

1. **Repo.** The skill reviews the repository the session's working directory is in:
   `REPO_ROOT=$(git rev-parse --show-toplevel)`. Repo name = basename of
   `git remote get-url origin` without `.git` (no remote: basename of `REPO_ROOT`). Profile =
   `--profile <name>`, else `SKILL_DIR/profiles/<repo>.md`, else the one `SKILL_DIR/profiles/*.md` whose
   `repos:` field lists `<repo>` (more than one → ask). Parse it per `profiles/README.md`; for a shared
   profile, merge the top sections with that repo's `## Repo: <repo>` section into one resolved
   profile. No file → no profile; every default applies and the preflight question says
   "profile: none, defaults".
2. **Base branch.** `--base <ref>`, else the profile's `base_branch`, else ask the user before the
   snapshot (one AskUserQuestion; offer the local and `origin/` branches named `dev`, `main` or
   `master` that exist, with Other for any ref). Never infer it: a repository's default branch is often
   not where work merges (a repo can default to `main` while work merges into `dev`).
3. **Snapshot.** If `git remote get-url origin` succeeds, `git fetch -q origin` (a failure becomes a
   warning in the preflight question, not a stop). Then `SKILL_DIR/snapshot.sh <base>` → `tree`,
   `merge_base`, `head`, counts, and the changed-file list. A non-zero exit: report its message in one
   line and stop. **If `files=0`, stop with one line** ("Nothing to review: no difference between
   <base> and the working tree in <REPO_ROOT> (wrong worktree, merged branch, or unsaved edits?)").
4. **Keys.** First match wins:
   - the keys given as arguments;
   - every match of the profile's `ticket_key_regex` against the branch name, matched case-insensitively
     and upper-cased (if the regex has a capture group, the key is group 1);
   - without a profile: matches of `[A-Z]{2,}[0-9]*-[0-9]+` against the branch name, case-insensitive,
     upper-cased, offered as "detected key, confirm" in the preflight question (branch names such as
     `utf-8-fix` produce false keys);
   - the H1 of the `--plan` file, if one was given.
   No key → key = the branch name with `/` turned into `-`, and `TICKET_FILE=none`; with a detached HEAD,
   key = `detached-<head short sha>`. When the current branch is the base branch itself (common in a
   personal repo worked on `main`), committed work counts as finished: in step 5 a prior run counts only
   if its State `head` equals the current HEAD; otherwise start a new run with no `PRIOR_LEDGER`.
5. **Prior runs.** List `WORK_ROOT/reviews/<KEY>/*/ledger.md`, newest first. If the newest run's State
   `step` is not `done`: **resume** (see Resume) instead of continuing preflight. If it is `done`:
   **re-review** (see Re-review); work out `mode` and the diff base now.
6. **Plan file.** `--plan <path>` always wins. Otherwise, candidates in order: a plan file this session
   was already pointed at (the user often clears context and starts the author session with a pointer to
   the plan); newest `~/.claude/plans/*.md` whose H1 starts `# <KEY>`; newest one mentioning `<KEY>`
   anywhere. Attach the first candidate whose H1 contains one of the keys. If none qualifies,
   `PLAN_FILE=none` and the preflight question shows "plan: none (candidate <path>, H1 '<h1>'; say
   'attach plan' or pass `--plan` to use it)": every reviewer reads the plan, so an unrelated one costs
   each of them its full length and misleads them. Show the attached plan's path and H1 in the preflight
   question.
7. **Ticket and PR.** Per the profile's `tracker` (you only; reviewers never touch the tracker):
   `linear` → load the Linear tools with ToolSearch, then `get_issue` with relations and `list_comments`
   for each key, plus title, state, description and comments of each related ticket. `github` →
   `gh issue view <number> --comments` for each key (strip a leading `#`), plus linked issues it names.
   `none` → skip. Keep the text verbatim with a first line `Fetched: <ISO time> from <tracker>`. A read
   that fails is recorded, never silently skipped. If `gh` works, `gh pr view --json number,title,body,comments,reviews`
   on the current branch; keep it for `pr.md`, else `PR_FILE=none`.
8. **Tests**, once, on the changed files only. Profile `test_cmd`/`lint_cmd` with placeholders filled:
   `{changed_tests}` = changed files matching `test_*.py`, `*_test.py`, `*.test.*`, `*.spec.*`, or under a
   `tests/` or `__tests__/` directory; `{changed_py}` = changed `*.py`; `{changed_files}` = all changed
   files; `{changed_js}` = changed `*.ts`, `*.tsx`, `*.js`, `*.jsx`, `*.mjs`, `*.cjs`. An empty
   placeholder means skip that command and record why. Without a profile: Python with
   `uv.lock` or `pyproject.toml` → `uv run pytest -q {changed_tests}`; anything else → "not run: no
   profile `test_cmd`" (a profile can add one). No test file changed → record "no tests touched". Full
   suite only when the user asks. Record pass/fail counts and failing test names. If a command fails
   because dependencies are missing (command or module not found), stop and ask the user to install
   them, naming the command (`! uv sync`, `! bun install`), then rerun; do not install them yourself
   and do not record it as a test result.
9. **Premise rerun.** If the plan records a rerunnable premise check and the profile has a
   `## Premise rerun` method, rerun it. Record the result, or "not rerun: <reason>". An expired login is
   an ask ("run `! <login command>`"), never a pass.
10. **Depth and reviewers.** Recommend a depth from the table using the risk paths, the counts and
    whether a new non-test module was added. Resolve each reviewer's model. Decide toolkit relevance.
    **Stale-profile check**, on the resolved profile (shared sections plus this repo's): every risk-path
    glob, and every backticked repo path in `## Lens addenda` and `toolkit_notes` (a token containing
    `/`, not starting with `/` or `~`, with no `{` or `<`, and not a git ref such as `origin/dev` per
    `git rev-parse --verify -q`), must match at least one path in
    `git ls-tree -r --name-only <merge_base>` (a directory
    path matches any file under it). Each miss becomes a warning: "profile path `X` matches nothing;
    the profile may be stale".
    **Environment sources**, when the `environment` lens is relevant: take the resolved profile's
    `environment_sources`. Check each one is reachable: for a repo, `git -C <path> fetch -q origin` (you
    fetch, so the reviewer never has to), then confirm its ref resolves (`git -C <path> rev-parse --verify
    <ref>`) and record the sha it resolves to; `gh auth status` succeeds; a cloud profile
    answers a cheap identity or list call; a chat tool is available in this session. Write the reachable
    ones, one per line with how to read them, as `ENVIRONMENT_SOURCES`. An unreachable source becomes a
    warning in the preflight question (an expired login is an ask: "run `! <login command>`"), never a
    silent drop.
11. **The preflight question** (AskUserQuestion). Its first line is `REPO_ROOT` and the current branch
    (`git rev-parse --abbrev-ref HEAD`; `detached` when that prints `HEAD`),
    so a wrong repo or worktree is the first thing the user sees. Then, compactly: profile (or
    "none, defaults"); keys (detected ones marked "confirm"); plan path (or none); base, merge-base and
    snapshot shas; mode (`full`, or `delta` with the reason); changed-file count and list (first 15, then
    "+n more"); test result; premise rerun result; recommended depth with the reason; each reviewer with
    its model, including `environment` and `coherence` when relevant (and why); the environment sources
    reachable; toolkit agents to run, or skipped and why; warnings. Options (at most 4): run at the
    recommended depth; the other two depths, each naming the word that preselects it ("deep (or pass
    `deep` next time)"); abort. Model changes, `--no-toolkit`, key corrections and
    "attach plan" (attach the candidate plan) go through Other.
    If the user passed a depth, still ask: the passed depth is the first option and the question text
    says "as requested". This question is the last chance to catch a wrong worktree or plan before
    reviewers start.
12. **Write the run.** Create `RUN`, then `context.md`, `diff.patch` (`git diff <diff-base> <tree>`),
    `changed-files.txt` (`git diff --name-only <diff-base> <tree>`), `ticket.md` (if read), `pr.md` (if
    read), `plan.md` (a copy, or the word `none`), `profile.md` (the resolved profile, in the
    single-repo format; `PROFILE_FILE` points here, so reviewers never see other repos' sections), and
    `ledger.md` with the State block,
    `step: round-1-pending`.

### `context.md`

One `FIELD: value` per line, every field present, `none` where absent. Absolute paths. Full 40-character
shas.

```text
REVIEW_REF: <tree sha>
BASE_REF: <diff base: merge_base, or the prior run's reviewed snapshot in delta mode>
MERGE_BASE: <merge_base>
HEAD_REF: <head>
BASE_BRANCH: <base branch>
REPO_ROOT: <abs path>
DIFF_PATCH: <RUN>/diff.patch
CHANGED_FILES: <RUN>/changed-files.txt
TICKET_FILE: <RUN>/ticket.md | none
PLAN_FILE: <RUN>/plan.md | none
PR_FILE: <RUN>/pr.md | none
COMMENTS_FILE: <RUN>/comments.md | none (fix mode only)
PROFILE_FILE: <RUN>/profile.md | none
LESSONS_FILE: <WORK_ROOT>/review-lessons.md | none
TESTS: <one line: command, pass/fail counts, failing names, "no tests touched", or "not run: <reason>">
PREMISE_CHECK: <result, "not rerun: <reason>", or none>
ENVIRONMENT_SOURCES: <one source per line, indented, with how to read it> | none
ROUND: 1
PRIOR_ROUND_DIR: none
LEDGER: none
PRIOR_LEDGER: <path> | none
KEYS: <all keys>
MODE: full | delta
MODELS: conformance=<m> correctness=<m> security=<m> environment=<m> coherence=<m> fix=<m> unguided=<m> round2=<m> toolkit=<m>
```

### `ledger.md`

```text
## State
run: <RUN>
step: round-1-pending | round-2-pending | summary | done
depth: small | normal | deep | fix
models: <as in context.md>
merge_base: <sha>
head: <HEAD at the run's snapshot>
snap1: <sha>
snap2: <sha | none>
snap_final: <sha | none>
prior_run: <path | none>
mode: full | delta | fix
retro: none | pending | done | skipped

## Findings
| id | severity / confidence | decision | reason | shape | clarification | applied |
| --- | --- | --- | --- | --- | --- | --- |

## Usage
| round | reviewer | model | tokens | tool uses | duration |
| --- | --- | --- | --- | --- | --- |
```

The **reviewed snapshot** of a run is the last tree a reviewer read: `snap2` when it is not `none`,
else `snap1`. `snap_final` can be newer: it includes the fixes the coordinator applied after the last
reviewer reported, which nobody has reviewed. A later run starts from the reviewed snapshot, never from
`snap_final`, so those fixes get their review.

`step` names the next thing to do. `round-1-pending` covers round 1 and its adjudication;
`round-2-pending` covers round 2 and its adjudication. Write each ledger row as soon as it is decided, so
a resume keeps it.

## Step 1. Round 1

Start every reviewer in **one message** so they run in parallel: each is an Agent call with
`subagent_type: general-purpose` (toolkit agents: `pr-review-toolkit:<short name>`) and the resolved
`model`. The prompt is exactly the following, with nothing about the author's reasoning added:

- Lens reviewer `<x>` ∈ conformance, correctness, security, environment, coherence: "Read `<SKILL_DIR>/reviewer-brief.md`,
  then `<SKILL_DIR>/lens-<x>.md`, then `<RUN>/context.md`. Your output file is
  `<RUN>/round-1/<x>.md`; writing it is required, the coordinator parses it."
- Unguided reviewer: "Read `<SKILL_DIR>/reviewer-brief.md`, then `<RUN>/context.md`. No lens: you are
  the unguided reviewer. Your output file is `<RUN>/round-1/unguided.md`; writing it is required, the
  coordinator parses it."
- Toolkit agent `<short>` with prefix `<P>`:

  ```text
  Review the change described in <RUN>/context.md. Ignore your default of reviewing `git diff` in the
  working tree: the change is the patch at DIFF_PATCH, and you read code only at REVIEW_REF as
  <SKILL_DIR>/reviewer-brief.md describes. Read that brief and follow its Inputs, Hard limits and Output
  sections exactly. Your lens name is <short> and your id prefix is <P>. Your output file is
  <RUN>/round-1/toolkit-<short>.md; writing it is required, the coordinator parses it.
  Ignore the logging helpers, error-id constants and project names in your own instructions; they
  belong to another project. This repository's rules: <profile toolkit_notes, or "see CLAUDE.md /
  AGENTS.md at REVIEW_REF">.
  <agent-specific question>
  ```

  Agent-specific question for `silent-failure-hunter`: "For every failure path the patch adds or
  changes: after deploy, what observes this failure, and what does the responder see?" For
  `comment-analyzer`: "Every quoted log phrase, alarm name, config key and `file:line` in a doc or
  comment must match the code at REVIEW_REF. Comments state a rule plus a pointer, not history or
  dates." Others: none.

Wait for every reviewer to finish. Record each agent's token usage, tool uses and duration from its
completion notice in a `## Usage` section at the end of `ledger.md` as soon as it arrives (a resumed run
has nothing else to recover them from), and the
model you passed in its Agent call (`inherit` means the session model); the notice does not name it.

**Validate before reading any finding.** If a report file is missing but the agent's final message
starts with the header, write that message to the expected path and note "written by coordinator from
final message" in the summary. Then, for each expected report: line 1 starts `# `; a line
`Reviewed: <sha>` exists whose sha equals `REVIEW_REF` in full; a `Could not read:` line exists and is
`none` or gives a reason; a `Findings:` line exists with three counts. On any failure, re-run that
reviewer once with the same prompt. Still failing → "lens not run: <why>", an ask in the summary.

## Step 2. Adjudication

You decide each finding; the reviewer only recommends. Work in severity order. For each id, read the
cited lines at `REVIEW_REF` **and** in the working tree, then write one ledger row:

| Column | Values |
| --- | --- |
| decision | `fix` · `doc` (finding right about the plan or ticket, code stays) · `reject` · `ticket` · `nit-fixed` · `nit-dropped` |
| reason | one line with the citation that settles it (`file:line`, test name, plan line) |
| shape | `as proposed` · `changed: <why>` · `none` |
| clarification | the artifact and section that received a finished sentence, or `none needed: <why>` |
| applied | `yes` · `no` · `pending-gate` |

Rules:

- **Accept** on your own check. **Reject** only with a citation the reviewer could not dispute. A
  rejection usually means an artifact (plan, ticket text, comment) misled the reviewer: name it in
  `clarification` and fix it. When the code itself plainly contradicts the finding, write
  "none needed: reviewer misread `file:line`". When the rejection rests on code that is not in
  `REVIEW_REF` (another branch or worktree, uncommitted work elsewhere), start the reason with
  "rests on <branch>, uncommitted" (or the commit, if it has one) and name the file and lines there;
  the summary lists every such rejection so the two changes land together. Reviewers do not read that
  code, so round 2 can only mark such a rejection plausible.
- **Fix shape is a separate decision.** Write the actual change. If it differs from the reviewer's
  proposed diff, `shape` says why.
- **Duplicates: one row, every part of every fix.** When two or more reviewers report the same problem,
  adjudicate them in one row listing every id, and apply the union of their proposed fixes: each part
  either reviewer proposed goes in unless the row cites why that part is wrong. Taking one reviewer's
  patch and dropping the rest loses whatever only the other one saw.
- **Run every command a fix introduces.** Before applying a fix, or suggesting one to anyone, run each
  command it adds or changes, exactly as written, against the real source: on a current record and on
  a record from each older era the text applies to. A command checked only on the record at hand is
  not checked; fixes are where new mistakes enter. If you cannot run it, the fix is `pending-gate`
  with the reason.
- **Siblings.** After writing each fix, search the changed files for the same command, flag, name,
  pattern or phrase it corrected, and fix every other occurrence in the same row. A wrong flag on one
  call is usually wrong on the call next to it.
- **Not checked.** Read every reviewer's `Not checked` list before the batched question. For each item
  that rests on a fact you can check and the reviewers could not (other repos, CI runs, cloud reads,
  chat, a CLI's `--help`), check it now, read-only, and record the result as a ledger row with id
  `NC-<lens>-<nn>`, adjudicated like a finding. Items you cannot check go in the summary.
- **Gate classes.** Apply immediately (autonomous) when all hold: the finding is confirmed against code,
  the change stays inside files the branch already changes or the ticket names (a new test file for
  that code counts), and the shape is as proposed or is the union of duplicate reviewers' fixes. A risk
  path does not gate a fix: list each such fix in the summary as applied on a risk path, and round 2
  reviews it (security joins, see Step 3). Everything else waits for the batched question: a choice
  between options (two reasonable fixes, a policy trade-off); rejected `blocking` findings; `premise`
  findings; shapes you changed for another reason; fixes outside the ticket's files; PR-body sentences.
- **Nits**, on or off a risk path: one batch, each fixed or dropped with a one-line ledger row, never in
  the question.
- **Out of scope**: default for anything in the ticket's area is `fix`. Genuinely separate work →
  `ticket`: draft `RUN/tickets/<slug>.md` with the profile's ticket template, Evidence citing
  `file:line` at `REVIEW_REF` and the run path. The attack pass runs only after the user says yes.
- **Clarifications.** The plan file: edit in place as a finished sentence in the section a cold reader
  needs (it is the author's private file; no gate). PR body: propose sentences in the batched question;
  after yes, `gh pr view --json body` then `gh pr edit --body-file`. No PR yet → hand the sentences to
  the profile's `pr_create_skill` in the summary. Code comments only when a well-written file would
  carry that comment anyway. Never a review-history list in a shared artifact.
- **The batched question.** Ask only what is the user's to decide; everything else is something you
  do. Print first, as full sentences: "I applied: …" for the autonomous fixes, then "Decide: …" for
  each gated item. Every gated item reads "Decide: <action> or <alternative>. I recommend <X> because
  <Y>." followed by one line of evidence and the finding ids. No fragment or label that could read as a
  description, an instruction or a recommendation ("Dockerfile: both roots"); no item without a
  proposal; no "Group A" labels. Lead with the count of decisions, and make it match the list. Then
  one AskUserQuestion with one question per decision, at most four (more than four: ask in list order,
  four per call). Each option label is a full imperative action ("Add the Dependabot entry for
  certifi"), the recommended one first. Apply the gated fixes the user approves.
- **Second pass.** Re-read every applied change as if all had landed and ask what breaks. Fix that
  before the next snapshot.
- Rerun the tests on the changed files if any code changed. Record the result.
- Set `step: round-2-pending`. If nothing was applied and nothing rejected, skip round 2: set
  `snap_final: <snap1>`, write `final.patch` (Step 3.5) and go to Step 4.

## Step 3. Round 2

1. `snapshot.sh <base>` → `snap2`. If `merge_base` differs from the State's, **stop**: report the count
   of upstream commits (`git rev-list --count <old>..<new>`) and ask; round 2 cannot read a fix diff
   mixed with other people's changes.
2. `RUN/fix.patch = git diff <snap1> <snap2>`, `RUN/round-2/changed-files.txt` from the same diff. Write
   `RUN/round-2/context.md`: the round-1 fields, with `REVIEW_REF: <snap2>`, `BASE_REF: <snap1>`,
   `DIFF_PATCH: <RUN>/fix.patch`, `CHANGED_FILES: <RUN>/round-2/changed-files.txt`, `ROUND: 2`,
   `PRIOR_ROUND_DIR: <RUN>/round-1`, `LEDGER: <RUN>/ledger.md`, and the new `TESTS`. The round-1
   `context.md` stays as it was.
3. Start one fresh correctness reviewer (`round2` model): "Read `<SKILL_DIR>/reviewer-brief.md`, then
   `<SKILL_DIR>/lens-correctness.md`, then `<RUN>/round-2/context.md`. This is round 2. Your output file
   is `<RUN>/round-2/correctness.md`; writing it is required, the coordinator parses it." Add a security
   reviewer of the same shape when an applied fix touched a risk path, and an environment reviewer of
   the same shape when an applied fix changed a command or a claim about an outside system and
   `ENVIRONMENT_SOURCES` is not `none`.
4. Validate as in round 1; adjudicate as in Step 2 with `R2-` ids. Anything still open after this
   adjudication goes to the summary as the user's. **There is no round 3.**
5. If round-2 adjudication changed any file, run `snapshot.sh <base>` again and use that tree as
   `snap_final`; otherwise `snap_final` = `snap2`. Write `RUN/final.patch = git diff <merge_base> <snap_final>`.
   Set `step: summary`.

## Step 4. Summary

Write `RUN/summary.md` and print it. Follow the user's reporting rules:

- **Asks first, counted, most urgent first**, each headed with its verb (`Decide`, `Confirm`, `Run`,
  `Approve ticket`, `Approve PR text`), then one or two lines of evidence inline. The user cannot see
  reviewer output; carry the evidence across.
- Then: what changed (files, ids fixed, shapes changed and why); what was rejected (id, one line, where
  the clarification went); `doc` decisions; drafted tickets awaiting yes; lenses or agents not run;
  everything reviewers listed under `Not checked` that matters; tests before and after; models and token
  usage per reviewer per round; PR-body sentences pending.
- Head no-action items `No action — …`.
- If round-2 adjudication changed any file, those changes have had no review: make the first ask "Run
  `/review-loop fix` to review the <n> changes made after round 2", not a request to accept them
  unreviewed.

Set `step: done` and `retro: pending`, then run Step 5.

## Step 5. Retro

One AskUserQuestion: "Which findings were noise?" Options: all useful; these ids (via Other; offer only
`reject`, `nit-dropped` and unfixed `should-fix` ids, since fixed ones were useful by construction);
skip for now (`/review-loop retro <KEY>` reopens the newest run). Also invite any finding a reviewer
missed.

Draft each lesson as a pattern with a date and run ("do not flag X in Y; <KEY> <date>"). Sort them:

- A repo fact that will stay true → offer it first as an AGENTS.md (or the repo's equivalent) change,
  drafted for the user to put through review; offer it as a profile lens-addenda line (in the
  `## Repo: <repo>` section when the profile is shared) only if it does not belong in the repo. Never
  edit repo files for a lesson yourself.
- Reviewer behaviour true in any repo → offer it as a line for the user's global CLAUDE.md, in chat.
  Never write CLAUDE.md yourself.
- Everything else → `WORK_ROOT/review-lessons.md`.

Show the drafts; write only what the user approves. Keep the lessons file at about 40 lines: when an
addition would exceed that, propose merges or prunes in the same exchange and rewrite the file in
place. Add the retro outcome to `summary.md` and set `retro: done`. "Skip for now" leaves it
`pending`, so `/review-loop retro` finds the run later; set `retro: skipped` only when the user says no
retro is wanted for this run.

## Resume

Same key, newest run's `step` not `done`: continue from `step`.

- `round-N-pending`: keep reports that pass validation and rerun only missing or invalid ones; keep
  ledger rows already written and adjudicate only ids without a row. The `applied` column says which
  fixes landed; re-derive nothing else from directory listings.
- `summary`: write the summary.
- If the working tree no longer matches what the ledger implies (a `yes` fix is absent), say so and ask
  before continuing.

## Fix mode

For a batch of fixes between milestones: answers to review comments from people or bots, or to findings
of an earlier run. One reviewer reads only the fixes and checks each one as new code. No depth, no round
2, no retro; the run is recorded like any other so the next run can start from it.

1. **Preflight, short.** Steps 0.1 to 0.3 (repo, profile, base branch, fetch, snapshot) and 0.4 (keys)
   as usual. Then the diff base, first match wins: `--since <ref>` (for example the commit the reviewer
   reviewed); the newest run for the key with `step: done`, using its reviewed snapshot (see the ledger
   template) if the merge-base is unchanged and `git cat-file -t` still finds it; else ask for it. Never
   its `snap_final`: that includes the previous run's own unreviewed fixes. If the newest run for the key is not
   `done`, say so and stop: finish or resume that run first. Empty diff: stop with one line.
2. **The comments being answered.** `--comments <path>` if given. Otherwise, if `gh pr view` finds a PR
   for the branch, write every review comment, review body and reply created since the diff base's
   commit time to `comments.md` (`gh api` `pulls/<n>/comments` and `pulls/<n>/reviews`, `--paginate`).
   Otherwise `none`. A run reviewing the findings of an earlier run points at that run's ledger instead.
3. **Environment sources** as in Step 0.10, always (the fix reviewer runs commands). Always add one
   local source, even with no profile: `cli: --help of each command-line tool the diff names, and
   local-only commands (git, jq, shell builtins) run in a throwaway directory under <RUN>/scratch, never
   in REPO_ROOT`. Cloud, GitHub and chat reads still come only from the profile.
4. **No question unless something is wrong.** Print the preflight block (repo and branch first, diff
   base and why, changed files, comments source, sources reachable) and start. Ask only for a warning
   (unreachable source, unknown diff base, merge-base moved).
5. **Write the run** as Step 0.12 into `WORK_ROOT/reviews/<KEY>/<YYYY-MM-DD-HHMM>-fix/`, with
   `COMMENTS_FILE` in `context.md` and `mode: fix`, `depth: fix` in the State block.
6. **One reviewer** (`fix` model): "Read `<SKILL_DIR>/reviewer-brief.md`, then `<SKILL_DIR>/lens-fix.md`,
   then `<RUN>/context.md`. Your output file is `<RUN>/round-1/fix.md`; writing it is required, the
   coordinator parses it." Validate as in Step 1.
7. **Adjudicate** as in Step 2, every rule included (gate classes, duplicates, siblings, running every
   command a fix introduces). Apply what passes. There is no round 2: anything still open goes to the
   summary, and fixes made now are reviewed by the next fix-mode run or milestone.
8. **Summary** as in Step 4, short: asks first, then each finding with its decision, then usage. Set
   `snap_final` to the snapshot after adjudication's fixes, write `final.patch`, and set `step: done`,
   `retro: skipped`.

## Re-review

Same key, newest run `done` (the branch changed after the pass), for a full run at a milestone. A
fix-mode run counts as a prior run.

1. Read the prior State: its reviewed snapshot (see the ledger template), `merge_base`, and `ledger.md`.
2. Snapshot now; recompute the merge-base. If the new tree equals the reviewed snapshot, stop with one line
   ("Nothing new since <prior run>; summary at <prior run>/summary.md") and create nothing.
3. If the merge-base is unchanged and `git cat-file -t <reviewed snapshot>` prints `tree`: `mode: delta`,
   diff base = the reviewed snapshot, `PRIOR_LEDGER` = the prior ledger. Recommend a depth from the delta's size and
   risk paths.
4. Otherwise `mode: full`, diff base = the new merge-base, `PRIOR_LEDGER` still set, and the preflight
   question gives the reason ("merge-base moved by <n> commits" or "prior snapshot no longer exists").
5. Rounds and the two-round cap apply per run as usual. `prior_run` in State names the earlier run.

## Ticket creation (after the user says yes to a draft)

1. If the profile names a `ticket_attack_brief`, start a fresh `general-purpose` agent with only that
   brief and the draft: "Read `<brief>`, then attack the draft at `<RUN>/tickets/<slug>.md`. Write your
   report to `<RUN>/tickets/<slug>-attack.md`."
2. Check each attack finding against the code before acting on it; attackers are wrong too.
3. Fix the draft, show the user the changes, create the ticket with the profile's tracker settings, and
   write the URL into the ledger row.

## Checking agent output

Reviewers and attackers get things wrong. Never relay a finding to the user, or act on it, without
reading the cited lines yourself. Anything you could not confirm goes to the user marked unverified.
