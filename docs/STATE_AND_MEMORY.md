# Claude integration state and memory audit

Version 2.0, tested 2026-11-06 on iPod touch 4, iOS 5.1.1, TLSFix 1.1.

## Request lifecycle

`CLAIRequest` has explicit Idle, Running, Completed, Failed and Cancelled states. A new start cancels the prior transport. Response bodies have a 512 KiB limit; partial model output, redirects and malformed plans fail without saving. No request retries automatically. Backgrounding cancels transport. Navigation away cancels without calling a departed controller.

The controller retains the request. The connection retains a forwarding proxy whose owner is an assign reference, avoiding a request/connection/delegate retain cycle. Teardown clears delegates and the proxy owner before cancelling. Delegate callbacks occur only after terminal cleanup, allowing reentrant starts. Every incoming callback checks the active connection identity.

Generators snapshot the options used for validation and disable inputs during requests. Stop, background, navigation and memory-warning teardown are handled explicitly. The review screen alone commits selected plans, atomically; Add is disabled after success. Coaching stores only its last successful note. Handoff opens a reviewed, unsent Claude draft, never an automatic send or tracker mutation.

## Checks and results

- 34 host assertions per app cover malformed/oversized responses, provider credential separation, cancellation, 300 pending-request deallocations, URL validation and plan constraints.
- macOS `leaks --atExit`: zero leaks in each core test process.
- 554 native assertions per app: 50 load/unload/reload cycles each for generator, review, coach and preview; all 200 controllers released, including active-request teardown. After warm-up, heap change was −4,576 bytes for Habits and −1,072 bytes for Sets. The run loop is serviced each iteration so deferred UIKit/connection releases are included.
- Clang static analyzer: no diagnostics in the new shared classes or changed AI/generator/review/store files. Store ID factories follow autoreleased naming conventions; history ignores missing exercise IDs.
- Direct on-device Claude API tests using synthetic goals in isolated audit sandboxes: Habits returned three validated suggestions plus a review; Sets returned two equipment-constrained routines plus a review. No main-app logs were uploaded or changed by these tests.
- Claude handoff tested from cold and warm launch. Cancel creates no chat. Use Draft creates one unsent draft, preserving original chats.

These checks cover the changed integration paths; they are not a claim that every possible app path is leak-free. The test apps use separate bundle IDs and are removed after testing.

## Reproducing

Run `./tests/build.sh` on macOS, then `leaks --atExit -- test-build/core`. Build `./tests/device-build.sh`, install its IPA and launch the audit app; its sandbox contains `Documents/audit.txt`. The normal audit uses a fake NSURLProtocol and a fixture-only key, never a network credential.

For an explicitly authorized live API test, build with `AUDIT_MAIN=tests/live.m ./tests/device-build.sh`, configure `ai_claude_key`, `ai_provider=claude` and `ai_claude_model` in the isolated audit app’s own preferences, and launch it. This sends synthetic goals to Anthropic and incurs API usage. Do not commit preferences or include them in an IPA.
