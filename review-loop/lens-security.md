# Lens: security and operations

Can the change leak a secret, let one tenant or user act on another's data, fail for want of a
permission, lose data, or cost more to operate than it saves? Your id prefix is `SEC`.

## Reading list

`DIFF_PATCH`, `CHANGED_FILES`, the post-deploy or release-steps section of `TICKET_FILE` (if any), then
any infrastructure, permission, CI or migration files the diff touches or references.

## Questions (starting points, not the boundary)

1. **Secrets.** Can a credential reach a log line, a URL or query string, an error message, an edge or
   firewall log, a test fixture, or a committed file? New environment variables: where is each one
   configured, and is there exactly one source?
2. **Authorisation.** Every client-supplied id (record, tenant, user, resource): is ownership checked
   before reading or writing with it? Any authentication bypass, new public route, or role/permission
   change?
3. **Permissions for new calls.** Every new call to a cloud or third-party API: name the file that grants
   its permission or holds its credential. Infrastructure, network, firewall or role changes: what is the
   blast radius?
4. **Schema and data.** Migrations: does the rollback restore the prior state; is data lost; is an
   irreversible step marked as such; is numbering or ordering correct against `BASE_BRANCH`? Writes:
   idempotent on retry; safe on partial failure?
5. **Operating cost.** For any alarm, guard, retry or reaper added or changed: how often will it fire,
   what does the responder do, and what happens if what it catches leaks anyway? A change that makes a
   safeguard less sensitive must say what it stops catching.
6. **After deploy.** Manual steps the diff implies (secret, env var, permission grant, backfill, alarm
   wiring, dependency install) that nothing writes down.

## Signals

| Signal | What it looks like |
| --- | --- |
| Credential reachable | A secret can end up somewhere a log reader, browser or repository reader sees it. |
| Missing ownership check | A client-supplied id is used without checking it belongs to the caller. |
| Missing permission | A new API call has no grant in the infrastructure code; it fails only in deployed environments. |
| Unsafe migration | Rollback does not restore the prior state, data is dropped, or irreversibility is unmarked. |
| Quieter safeguard | Threshold raised, window widened, check skipped, with no statement of what stops being caught. |
| Undocumented manual step | Production needs a human action after deploy that no ticket or PR section lists. |
