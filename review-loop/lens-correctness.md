# Lens: correctness

Does the changed code do the right thing for every input and state production can produce? Your id
prefix is `CORR`.

## Reading list

`DIFF_PATCH`, then every changed function in full at `REVIEW_REF`, then its callers and the callees it
relies on (within the brief's budget), then only the acceptance-criteria block of `TICKET_FILE`, then
`TESTS`.

## Questions (starting points, not the boundary)

1. **Whole functions.** Read every changed function and every callee it relies on, end to end. Check
   early returns, ordering, query count and cost, and connection or pool behaviour in the unchanged
   lines above and below the hunk.
2. **Silent failures.** Broad `except`/`catch`, swallowed errors, sentinel returns (`0`, `None`, empty),
   retries that run out without surfacing anything, logs at the wrong level. For each: after deploy,
   what observes this failure, and what does the responder see?
3. **Edge cases.** None/empty/missing keys; timezone (aware vs naive, storage vs display); concurrency,
   redelivery and duplicates; idempotency; partial failure halfway through a multi-step write.
4. **Tests.** Does each new behaviour have a test that fails without the change? Does any mock or fixture
   produce a state the real dependency cannot? What regression would the suite not catch? `TESTS` says
   whether tests were touched at all; if it says `not run`, judge the tests by reading them.
5. **Unasked behaviour.** Does the fix change behaviour the ticket did not ask to change, for callers
   outside the ticket's area?

## Signals

| Signal | What it looks like |
| --- | --- |
| Dead error handling | The caller handles an error the callee never raises (it swallows or returns a sentinel). |
| Unreachable mock state | A test fakes a state production cannot produce, so the behaviour is untested. |
| Time mix | Aware and naive datetimes compared, or a display timezone used for storage or comparison. |
| Query in a loop | Per-item queries or calls where one bulk call would do; unbounded result sets. |
| Unobservable failure | A failure path that logs nowhere a responder looks, or at a level nobody alerts on. |
| Collateral change | A shared function's behaviour changes for callers the ticket never mentioned. |
