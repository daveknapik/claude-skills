# Lens: coherence

Does the changed text agree with itself? Instructions, skills, runbooks and docs fail in a way code does
not: a rule stated in three places with three different values, a step one path skips that another path
needs, an output asked for with no way to produce it. Each one sends the reader to a wrong step with no
error to show it. Your id prefix is `COH`.

## Reading list

Every changed file **in full** at `REVIEW_REF`, not only the hunks: the contradiction is usually between
a changed line and an unchanged one. Then every file that points at the changed text (`git grep` for its
headings, step names and file names): README tables and install notes, manifests, indexes, and
`PR_FILE`. Then `DIFF_PATCH`.

## Questions (starting points, not the boundary)

1. **One rule, one value.** List every rule, count, threshold, limit and default the changed text
   states. For each one stated in more than one place, quote every statement. Any two that differ are a
   finding, including a template or example that disagrees with the prose around it.
2. **Every path through.** For each entry point or mode, walk the steps in order. Does any instruction
   say a step "does not apply" or is "replaced" while another says it applies? Does a skipped step
   produce something a later step or the output needs?
3. **Every ask has a how.** For each field, output, value or decision the text asks for, find the step
   that tells the reader how to get it, or what to write when it cannot be found. One without the other
   is a finding.
4. **Every reference resolves.** Step names, section names, `file:line` pointers, "above", "below", "the
   line before", links and anchors: does each point at what it claims, at `REVIEW_REF`?
5. **Everything that describes the change is current.** README rows, counts and install steps, manifest
   descriptions, PR title and body: do they describe the behaviour at `REVIEW_REF`, or an earlier one?
6. **One name per thing.** Is any one thing called by two names, or two things by one name, so that a
   reader would count them wrong?

## Signals

| Signal | What it looks like |
| --- | --- |
| Conflicting values | The same rule, count or default stated differently in two places. |
| Contradictory routing | One place skips or replaces a step that another place requires. |
| Ask without a how | A requested field or output that no step tells the reader how to produce. |
| Dangling reference | A pointer, step name, line note or link that no longer points at what it says. |
| Stale description | A README, manifest or PR body describing behaviour the change replaced. |
| Two names, one thing | Terminology that would make a reader count the wrong number of items. |
