# Lens: environment

Does the change hold up against the real systems it acts on? A skill, runbook, script or CI step can be
consistent with itself and with its ticket and still be wrong about the world: a tag that sorts first, a
name built from a variable, a job state nobody listed, a flag whose default drops half the results. Your
id prefix is `ENV`.

You are the one reviewer allowed to look outside `REVIEW_REF`, and only at the sources listed in
`ENVIRONMENT_SOURCES`. Everything else in the brief's Hard limits still applies.

## Reading list

`ENVIRONMENT_SOURCES` first, then `DIFF_PATCH`, then every changed file in full at `REVIEW_REF`. Then,
for each command or claim about an outside system, the source that settles it.

## Method: inventory first, then check every row

Before writing any finding, list in your report, under `## Inventory`, **every** item in the changed
files (whole files, not only the hunks; text that runs next to changed text is used together with it)
of these kinds:

- **command**: every command, query or API call the text tells someone to run;
- **claim**: every statement about how an outside system behaves (what a tool returns, how names are
  built, which states exist, what a setting does, what a field contains);
- **signal**: every email, log line, alarm, record or file the text relies on existing.

One row each, changed lines first:

```text
| # | kind | where (file:line) | in diff | source checked | result |
| 1 | command | guide.md:204 | no | `--help` of the CLI; ran it against one real record | finding R1-ENV-03 |
| 2 | claim | guide.md:251 | yes | other-repo infra/alarms.py at 1a2b3c4d | holds |
| 3 | signal | guide.md:217 | yes | other-repo app/notify.py at 1a2b3c4d | not checked: <why> |
```

For every `claim` row that selects, sorts, dates, names or matches, also add a section
`### Population: <row #>` with the variants that exist (question 3), one per line: the variant, how you
found it (the command and its count), the example you tested, and what the rule returned for it. A rule
tested only on the common variant has not been tested.

Then check every row. `result` is `holds` (with what showed it), a finding id, or `not checked: <why>`.
A row left without a result is a review not done. The budget in the brief does not cap this lens: check
every row, cheapest source first, and stop paging once a row is settled. Copy every `not checked` row
into the header's `Not checked:` line.

## Your access, and its limits

- **Read-only, every time.** Only commands that read: `git show`, `git grep`, `git log`, `git tag --list`
  on a listed repo; `gh api` GET requests and `gh run view` / `gh run list`; `--help` and man pages; the
  read-only cloud profile named in `ENVIRONMENT_SOURCES`, with `describe`, `list` and `get` calls and
  log queries; read-only chat or ticket tools when listed. Never a write, a re-run, a deploy, a
  dispatch, a restart, or anything that sends a message. No `git fetch` or `git pull` either: the
  coordinator fetched every listed repo before the run, and a ref still missing goes under
  `Could not read`.
- **Nothing left running.** No background jobs. Every command finishes, or is stopped, before you write
  your last finding.
- **Only the listed sources.** A source not in `ENVIRONMENT_SOURCES` is out of bounds: list it under
  `Could not read` with what it would have settled.
- **Bounded.** Every log or history query has a time window; every list call has a limit or a page cap.
  Stop paging once you have the answer.
- **No secrets or personal data in your report.** Report counts and shapes, not names, tokens, emails
  or message bodies beyond the few words a finding needs.
- **Cite what you ran.** Every claim names the command (or query) and the window, and quotes the part of
  the output that settles it.

## Questions (starting points, not the boundary)

1. **Run what the change tells someone to run** (each `command` row). Run it, or its closest read-only
   form, against the real source with realistic inputs. Does it parse? Does it return what the
   surrounding text says it returns? An empty result is a finding until you show it is empty for the
   right reason.
2. **Defaults and omitted flags** (each `command` row). Read the `--help` or the documentation for every
   flag the command uses, and for every flag it leaves out. "If you omit this parameter, only X are
   returned" is a finding when the text assumes all of them. Compare each command with its siblings: a
   flag one call passes and the next call of the same tool leaves out is a finding until shown harmless.
3. **The real population, then the rule** (each `claim` row that selects, sorts, dates, names or
   matches). First list the variants that actually exist in the source: every tag pattern
   (`git tag --list`), every way the names are built (literal, formatted from a variable, generated per
   facility or environment), every state or conclusion value the records carry (`skipped`, `cancelled`,
   `neutral` as well as success and failure), every environment. Then apply the rule to one example of
   each variant and say what it returns. Also the oldest, newest, empty and very large cases.
4. **Producer conditions** (each `signal` row). Read the code or configuration that produces the
   signal, at the deployed ref, and list every condition under which it is **not** produced: a setting
   or flag that turns it off, an early return, a filter, a rate limit, a retention window, a channel it
   is not sent to. If the text treats the signal's absence as evidence ("no earlier email, so it is
   new"), every such condition is a way that conclusion is wrong.
5. **Silent caps** (each `command` row that lists or searches). Find the most the source returns for
   that call (an API's result cap, a page size, a retention window, a search limit) and what it drops
   when it hits it: the oldest, the newest, or an arbitrary set. Run it on the widest window the text
   implies. A result exactly at the cap is a finding unless the text says to narrow and repeat.
6. **Other producers** (each `signal` row the text counts or matches). Who else writes the same signal
   into the same place: another service, another process, another environment, a test or a backfill?
   The target repo's docs are leads, not proof (they drift): confirm each producer in the data, by the
   field that tells producers apart, and say whether the text tells the reader to filter on it.
7. **Eras** (each `claim` or `command` row applied to past records). Read the history of the code or
   configuration that produced those records across the window the text covers (`git log` of the
   workflow, script or config file), list its eras with dates, and test the rule on one record from each
   era. Test any command a fix introduces on a **current** record too: the newest era is the one readers
   hit first.
8. **Filter values** (each `command` or `claim` row that filters or compares against a value). List every
   value the field actually takes in the source, with counts, before judging the filter. Different
   spellings and suffixes of the same idea count as separate values.
9. **Claims about another codebase.** Where the change says how another repo behaves ("the alarm name is
   a fixed string", "this setting is always on", "every frame maps to the repo"), read that code at the
   ref that is deployed, not only at its default branch.
10. **The same fact elsewhere.** When one command or rule turns out wrong, look for the same command,
   flag or assumption at every other place in the change.
11. **Cost and access of following the text.** How many calls, prompts or pages does each step take on
   real data? Does every tool, connector and permission it needs appear in the prerequisites?

## Signals

| Signal | What it looks like |
| --- | --- |
| Command fails or misleads on real data | It errors, returns nothing, or returns something the text misreads. |
| Default drops results | An omitted flag silently narrows the result (metric alarms only, first page only, public channels only). |
| Pattern assumed, reality differs | Sorting, naming or state rules that hold for the common case and not for the cases that exist. |
| Wrong about the other repo | A claim about another codebase that its code at the deployed ref contradicts. |
| Unbounded or unprompted cost | A step that pages without limit, or triggers prompts or tools the prerequisites never mention. |
| Unlisted dependency | A tool, connector, permission or input the text needs and never names. |
| Absence read as evidence | The text concludes from a missing signal that its producer can suppress. |
| Silent truncation | A list or search that stops at a cap and drops the records the text needs. |
| Mixed producers | A count or match that includes another producer's lines, with no field to filter them out. |
| Rule from one era | A rule that holds for current records and not for older ones, or the reverse. |
| Unlisted filter value | A filter that misses a spelling or variant the field actually takes. |
