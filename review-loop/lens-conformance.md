# Lens: conformance

Does the change do what the ticket and plan asked, only that, and do the ticket and plan themselves
hold up? Your id prefix is `CONF`.

## Reading list

`TICKET_FILE` in full (description, acceptance criteria, testing notes, comments, related tickets), then
`PLAN_FILE`, then `PR_FILE`, then `PREMISE_CHECK`, then `DIFF_PATCH`. If `PLAN_FILE` is `none`, review
against the ticket and say "plan absent" in your header's `Not checked`. If ticket, plan and PR are all
`none`, review against the commit messages (`git log <MERGE_BASE>..<HEAD_REF>`; uncommitted work has
none) and the diff's own stated intent, and say so in `Not checked`.

## Questions (starting points, not the boundary)

1. **Criteria to lines.** For every acceptance criterion, name the line(s) that satisfy it, or say
   "unmet". For every testing note, name the test that covers it, or say "no test".
2. **Silent scope.** What does the diff do that no criterion or plan line asked for? Behaviour changes
   nobody requested are findings even when they look like improvements.
3. **Divergence.** Where do plan, code and ticket disagree? Which one is wrong, by the code?
4. **Does the plan make sense given its premises?** Lines recording an owner's decision ("<name>
   decided X") are premises. Attack one only when code or data shows the premise false; label that
   finding `premise` and propose no alternative design. A decision relitigated without evidence is not
   a finding.
5. **Premise check.** A ticket rests on claims about how the system behaves. If a claim is wrong, the
   change built on it is wrong, and tests written from the same ticket pass anyway. Read
   `PREMISE_CHECK`: is the claim stated, is the check something a reviewer could rerun (a query with its
   source and window, a `file:line`, a command), and does the recorded result support the change? If
   the plan has no premise check and the ticket rests on a runtime claim, name the claim and say it is
   unverified. "Verified" or a restatement of the ticket is not a check.
6. **After deploy.** Which manual steps does the diff need (secret, env var, permission grant, backfill,
   data fix, alarm wiring, config flag) that the ticket or plan does not list?

## Signals

| Signal | What it looks like |
| --- | --- |
| Criterion unmet | An acceptance criterion has no line that satisfies it, or only a test that mocks the behaviour away. |
| Silent scope growth | The diff changes behaviour no criterion or plan line mentions. |
| Premise false | Code or data contradicts a claim the ticket or plan rests on. Label `premise`. |
| Premise unchecked | The change rests on a runtime claim nobody reran. |
| Missing post-deploy step | The diff cannot work in production until someone does something the ticket does not say. |
| Plan absent | No plan file; state it in the header and review against the ticket. |
