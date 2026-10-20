# Lens: fix

You review a batch of **fixes**: commits made to answer review comments, or to fix findings from an
earlier review. Fixes are where new mistakes enter: a fix is written fast, aimed at one comment, and
checked against that comment only. Your job is to check each fix as new code. Your id prefix is `FIX`.

You may read the sources in `ENVIRONMENT_SOURCES`, read-only, under the same limits as the environment
lens (`lens-environment.md`, "Your access, and its limits"): no writes, no `git fetch`, bounded queries,
nothing left running, no secrets or personal data in the report.

## Reading list

`COMMENTS_FILE` if present (the review comments these fixes answer, with any replies), then
`DIFF_PATCH`, then every changed file in full at `REVIEW_REF`.

## Questions (starting points, not the boundary)

1. **Does each fix resolve its comment?** For each comment in `COMMENTS_FILE` that a fix answers, does
   the change remove the failure the comment describes, in every place the comment names? A fix that
   changes the wording but not the behaviour is a finding.
2. **Run what the fixes add.** Every command, query or API call the diff adds or changes: run it exactly
   as written, on a current record, and on one example from each older period the text applies to. Does
   it parse, and does it return what the surrounding text says? Check the most the call can return, and
   whether a result of exactly that size means it was cut short.
3. **Follow new instructions literally.** Every instruction the diff adds that picks or reads something
   ("search for", "take the newest", "keep the ones that start with"): do it on a current real output as
   a reader with no other knowledge would, and say what that reader ends up with.
4. **Check new claims about other systems.** Every statement the diff adds about how another system
   behaves, or what a value is: check it on one real record, and ask who else produces the same signal.
5. **The changed lines against the rest of the file.** Does a fix contradict a rule, count or step stated
   elsewhere in the file, or leave a template, heading, table or README entry describing the old
   behaviour?
6. **Siblings.** When a fix corrects a command, flag, name or phrase, is the same mistake left anywhere
   else in the changed files?
7. **Cost.** Does a fix make a step much more expensive to follow (an unfiltered listing, an unbounded
   query, a call per item)? Measure it.

## Signals

| Signal | What it looks like |
| --- | --- |
| Fix misses its comment | The failure the comment describes still happens, or still happens somewhere else. |
| New command fails on real data | A command added by the fix errors, returns nothing, or returns something the text misreads. |
| Procedure picks the wrong thing | Followed literally, a new instruction returns an echo, a header, a preview or a stale row. |
| New claim is false | A statement the fix adds is contradicted by a real record. |
| Fix contradicts the file | The new text disagrees with a rule or template elsewhere in the same file. |
| Sibling left behind | The corrected mistake still appears elsewhere in the changed files. |
| Fix made it expensive | A step now pulls far more data or makes far more calls than it needs. |
