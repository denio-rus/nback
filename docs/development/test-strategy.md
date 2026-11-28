# Test Strategy

> This document defines how changes to Mind at Play are verified. It describes the current test stack and the expected testing approach for new work; it does not claim that every scenario listed below is already implemented or that every reliability gap is solved.

## 1. Goals

The test suite must provide confidence that:

- game rules and scoring are correct and reproducible against the setup issued by the server;
- user data is isolated by ownership and anonymous play remains possible where intended;
- browser interactions produce the expected trial payloads;
- network failures, repeated requests, navigation, and browser lifecycle events do not silently corrupt or lose completed work;
- historical results remain readable when result contracts evolve;
- user-visible behavior remains consistent across supported locales;
- security and operational checks run as part of CI.

Tests should protect observable behavior and important contracts, not mirror every implementation detail.

## 2. Test Stack and Repository Layout

The current stack is:

| Area | Tooling | Responsibility |
|---|---|---|
| Ruby / Rails | Minitest, Active Support tests | Models, strategies, domain rules, and Rails integration behavior |
| HTTP | Action Dispatch integration tests | Routes, authentication, authorization, validation, status codes, persistence |
| Browser | Capybara, Selenium, Rails system tests | Real user flows and interaction between Rails-rendered pages and JavaScript |
| JavaScript | Node.js built-in test runner | Browser-independent JavaScript helpers and pure logic |
| Style and static checks | RuboCop, Brakeman, bundler-audit, Importmap audit | Style, common Ruby security issues, vulnerable dependencies, import-map dependency audit |
| CI | GitHub Actions | Runs checks and test groups on pushes to `main` and pull requests |

Tests live under `test/`; JavaScript tests live under `test/javascript/`. Rails test setup is in `test/test_helper.rb`. The Active Support test suite runs in parallel using the available processor count. System tests are a separate Rails test task and are not included in `bin/rails test`.

The authoritative commands are the workflow in `.github/workflows/ci.yml` and the current repository scripts. If this document and CI differ, verify the workflow before changing the documented commands.

## 3. Testing Principles

### 3.1. Test Behavior at the Owning Boundary

Choose the narrowest test layer that can prove the behavior, then add a higher-level test when the behavior crosses a meaningful boundary.

- Test calculations and validation directly on strategies.
- Test persistence and associations at the model/integration layer.
- Test HTTP contracts and access control through Rails integration tests.
- Test browser behavior in system tests when DOM, timing, navigation, or browser APIs matter.
- Test pure JavaScript functions in Node without requiring a browser.

Avoid testing private implementation details unless they encode a critical invariant that cannot be observed otherwise.

### 3.2. Server Is Authoritative

The browser is an untrusted client. It may submit answers and measurements needed by a game, but must not be trusted to provide final correctness, aggregate scores, ownership, or other server-controlled facts.

Tests should verify that:
- unknown and disallowed payload keys are filtered;
- malformed or impossible submissions are rejected;
- the server validates answers against the persisted setup;
- deterministic scores and metrics are recalculated on the server;
- users cannot read or modify another user's data;
- anonymous requests cannot access sessions owned by authenticated users.

### 3.3. Test Contracts, Not Only Examples

Shared contracts deserve explicit tests:
- every concrete game strategy satisfies the `Games::BaseStrategy` contract;
- each game accepts the expected number and shape of trials;
- result format and required fields are stable;
- the browser payload matches the server's permitted input;
- localized values needed by the browser are present.

When a shared contract changes, run the contract tests for all strategies and inspect every reader of stored results.

### 3.4. Keep Tests Deterministic

- Prefer fixed setups and explicit input data over random values.
- Stub or inject randomness when the behavior under test depends on generated sequences.
- Control time where time boundaries matter.
- Do not use arbitrary `sleep` calls to wait for browser behavior. Wait for a meaningful DOM state, request completion, or observable condition.
- Do not make correctness depend on test execution order.
- Use isolated records and the existing fixtures/factories conventions.

## 4. TDD Workflow

For implementation work, use the following loop:

1. **Understand the contract.** Read the relevant product and architecture documentation, implementation, and nearby tests.
2. **Write a failing test.** Express the desired behavior or reproduce the defect with the smallest useful test.
3. **Run the focused test.** Confirm that it fails for the expected reason. A syntax error or unrelated setup failure is not a useful red test.
4. **Implement the smallest change.** Avoid unrelated cleanup while establishing the behavior.
5. **Run the focused test again.** Confirm it passes.
6. **Run adjacent tests.** Include other strategies, callers, and readers affected by the change.
7. **Run the appropriate broader suite and static checks.**
8. **Review the diff.** Check for accidental changes, weakened assertions, skipped tests, debug code, and stale comments/docs.

TDD is the default for:
- business rules and scoring;
- validation and authorization;
- bug fixes;
- persistence, state transitions, and request behavior;
- shared interfaces and result-format changes.

For exploratory research, spikes, visual styling, or work where a useful automated test cannot reasonably be written first, document the reason and add appropriate verification before considering the task complete. Do not write tests that merely restate the implementation.

A test that fails before the change should fail because the expected behavior is missing. A test that passes after the change should prove the behavior, not just exercise the code.

## 5. Ruby and Rails Tests

### 5.1. Unit and Model Tests

Use Active Support tests for:
- strategy setup, validation, scoring, and metrics;
- shared strategy behavior and contract requirements;
- statistical helpers and edge cases;
- model validations, associations, callbacks, and state transitions;
- insight grouping, minimum sample sizes, and missing context;
- registry discovery and catalog synchronization.

For every game strategy, cover normal, boundary, invalid, and missing input. Include empty data, one item, maximum allowed items, and values just outside accepted ranges where applicable.

### 5.2. Integration / Request Tests

Use `ActionDispatch::IntegrationTest` to verify the complete HTTP contract:
- route and parameter behavior;
- authentication and anonymous access;
- ownership and role restrictions;
- accepted and rejected payloads;
- HTTP status and response body;
- database state after success and failure;
- duplicate and concurrent submissions;
- CSRF-sensitive behavior where the test environment permits meaningful coverage.

Assert persisted state as well as the response. A success response alone does not prove that the correct result was stored; an error response alone does not prove that no partial write occurred.

### 5.3. Transactions and Database Constraints

When correctness depends on uniqueness, ownership, or one-time transitions, prefer database-enforced invariants where appropriate. Test the invariant through the public operation and, where useful, at the database boundary.

Do not assume a model-level validation or a Ruby check is sufficient under concurrent requests. Two requests can both pass a read-before-write check. Concurrency-sensitive behavior needs an atomic database operation, a suitable lock/constraint, or another explicitly justified serialization mechanism.

## 6. JavaScript Tests

Run JavaScript unit tests with:

```sh
node --test test/javascript/
```

Use Node tests for browser-independent helpers and logic, including:
- message lookup and placeholder substitution;
- number formatting when the required environment is provided or stubbed;
- timer scheduling and cancellation;
- payload construction and pure scoring helpers;
- result-submission helper behavior with mocked `fetch` responses.

Test asynchronous behavior by awaiting promises and controlling callbacks/responses. Avoid real network calls and wall-clock delays in unit tests.

A Node test does not prove that a Stimulus controller is wired correctly in the page. Use a Rails system test for behavior that depends on Stimulus registration, data attributes, DOM targets/actions, browser timing, keyboard/mouse input, or navigation.

## 7. System and End-to-End Tests

Run system tests separately:

```sh
bin/rails test:system
```

System tests should cover the important user journeys rather than every low-level branch. At minimum, maintain coverage for:

- a visitor opening a game and completing an anonymous session;
- a signed-in user starting a game with a check-in;
- skipping or leaving the check-in empty and still starting the game;
- completing a game and seeing the persisted result;
- opening a completed session breakdown as its owner;
- viewing personal trends after multiple sessions;
- preventing access to another user's session and insights;
- navigating away from a running game and returning or starting a new session according to the defined product behavior;
- localized game instructions and controls for supported locales.

For interactive games, verify meaningful state transitions (ready, running, submitting, completed, failure) through visible UI state. Avoid assertions tied to incidental CSS classes or exact animation timing unless those are the behavior being tested.

Use stable selectors such as explicit test IDs or semantic roles where practical. Prefer Capybara's waiting matchers over manual sleeps. Capture screenshots and relevant logs when a system test fails; CI currently uploads `tmp/screenshots` on system-test failure.

## 8. Network and Submission Reliability

Game completion is a distributed interaction between a browser and the Rails server. The browser cannot always know whether a request failed before reaching the server or whether the server committed the result but the response was lost.

Tests must distinguish these cases.

### 8.1. Client-Side Submission States

A game controller should expose and handle explicit states appropriate to its flow, typically:

`ready → running → submitting → completed`

with a recoverable failure state such as `submission_failed`.

Verify that:
- the submit action happens once when a game ends;
- controls cannot accidentally trigger multiple submissions while one is pending;
- a pending state is visible and interaction is appropriately disabled;
- a non-success response is not presented as a successfully saved result;
- network errors and timeouts are visible and do not silently discard the collected payload;
- the user can retry or otherwise recover according to a safe server contract;
- navigation/disconnect does not allow stale callbacks to corrupt a later controller state.

The shared `submitResult` helper currently returns `{ ok, status, body }` and converts network exceptions into a result with status `0`; callers must inspect that return value. A caller that simply awaits it and ignores the result cannot distinguish a successful save from a failed request. Keep this distinction covered by tests.

### 8.2. Server-Side Validation and Atomicity

For every result endpoint, test:
- a valid first submission is persisted;
- an invalid submission leaves the session unfinished and does not persist a partial result;
- a later duplicate is rejected without replacing the first result;
- two overlapping requests cannot both complete the same session;
- the final persisted result and metrics correspond to exactly one accepted submission.

A sequential duplicate-request test is useful but does not prove concurrency safety. Add a concurrency-focused test when changing one-time submission behavior. The implementation must use an atomic state transition or database locking/constraint appropriate to the data model; a separate `played_at` check followed by an ordinary update is vulnerable to a race between concurrent requests.

### 8.3. Idempotency and Safe Retry

A timeout is ambiguous: the server may have committed the result even though the browser did not receive the response. Do not automatically retry a POST merely because the client timed out.

Before enabling automatic or user-triggered retries, define the server contract. Options include:
- an idempotency key persisted with the operation and scoped to the session;
- a conditional atomic transition that allows only one accepted result;
- a status/read endpoint that lets the client reconcile the outcome;
- a combination of these mechanisms.

The chosen mechanism must define what happens when the same key is replayed with the same payload and when it is replayed with a different payload. Tests should verify that retries cannot overwrite a previously accepted result or create duplicate side effects.

An HTTP cancellation or browser `AbortController` does not prove that the server cancelled or rolled back the operation.

## 9. Refresh, Interruption, and Recovery

Recovery behavior must be explicit. A browser refresh, tab close, navigation, network loss, or process restart can occur at any point in a game session.

Test the lifecycle by interruption point:

| Interruption point | Required question / behavior to define |
|---|---|
| Before a session is created | Can the user simply start again without orphaned records? |
| After setup is persisted, before play starts | Is the unused session abandoned, reusable, or expired? |
| During play, before submission | Is progress intentionally lost, locally recoverable, or resumable? |
| While submission is pending | How does the client reconcile an unknown server outcome? |
| After server commit, before response reaches the browser | Can the client discover that the result was saved without overwriting it? |
| After successful save, before result display | Can the user reload and view the saved result? |
| After completion | Does refresh show the persisted result rather than starting a duplicate completion flow? |

For any recovery feature, test both the browser behavior and the server persistence contract. If a session is resumable, define which state is authoritative, how stale sessions expire, and how simultaneous tabs are handled. If it is not resumable, communicate that clearly and ensure a lost in-progress session does not masquerade as a completed result.

Do not add client-side persistence of sensitive or significant data without a product and privacy review. Local browser storage is not a substitute for server-side durability or idempotency.

These are required design and verification questions, not a statement that all recovery behavior is currently implemented.

## 10. Historical Results and Compatibility

Game results are persisted data, not disposable request payloads. When changing a strategy's setup, trial structure, scoring, or result format:

- identify which fields are stored and which code reads them;
- preserve readers for existing format versions or provide an explicit migration;
- do not silently reinterpret historical values using new rules;
- test representative old-format results as well as new results;
- verify breakdown pages and personal trends against both formats;
- keep the strategy's rules/specification version meaningful and update it when the game rules change.

A format version should describe the stored result layout. A game specification version should describe the game rules/setup contract. Do not conflate the two.

## 11. Test Groups and Execution

Use the following conceptual groups to balance feedback speed and coverage:

| Group | When | Contents |
|---|---|---|
| Focused | During TDD | One test or one test file directly related to the change |
| Fast | Frequently | Relevant unit/model tests and JavaScript tests |
| Standard | Before review or commit | Full Rails test suite, JavaScript tests, and RuboCop |
| Full / CI-equivalent | Before merge or release | Standard checks, security/dependency audits, import-map audit, and system tests |

Current useful commands:

```sh
# Rails tests (does not include system tests)
bin/rails test

# One Rails test file
bin/rails test test/models/games/base_strategy_test.rb

# One test by line number
bin/rails test test/models/games/base_strategy_test.rb:42

# JavaScript tests
node --test test/javascript/

# Browser system tests
bin/rails test:system

# Ruby lint
bin/rubocop

# Security and dependency checks
bin/brakeman --no-pager
bin/bundler-audit

# Import-map dependency audit
bin/importmap audit
```

The current CI runs Rails tests, JavaScript tests, system tests, RuboCop, Brakeman, bundler-audit, and Importmap audit in separate jobs. Keep local verification aligned with CI.

The local `AGENTS.md` contains machine-specific timing and background-run guidance for the current development environment. Follow it when running long commands locally, but do not copy machine-specific paths or timeout assumptions into this general test strategy.

Do not run two full Rails test suites against the same local test databases simultaneously. The suite uses parallel workers and creates worker-specific test databases.

## 12. Flaky Tests and Failure Diagnosis

A flaky test is a defect in the test, the application, or an uncontrolled dependency until understood. Do not permanently skip, quarantine, or add broad retries to hide it.

When a test is intermittent:
1. record the exact command, environment, and failure;
2. inspect logs, screenshots, browser console output, and server output;
3. identify timing, shared state, random input, parallel execution, or external dependency as possible causes;
4. reproduce with controlled input and the narrowest useful test;
5. fix the underlying nondeterminism;
6. rerun the focused test repeatedly for diagnosis, then run the relevant broader suite.

Retries may help establish intermittency during diagnosis. They must not be used as evidence that the underlying problem is fixed.

Avoid arbitrary waits. Synchronize on application state, use deterministic fixtures, and isolate tests that truly require concurrency or shared external resources.

## 13. Definition of Done

A change is not considered verified until:

- [ ] Tests cover the new behavior and relevant failure/boundary cases.
- [ ] Bug fixes include a regression test that fails without the fix.
- [ ] Relevant Ruby, JavaScript, request, and system tests have been run.
- [ ] Relevant lint, security, and dependency checks have been run.
- [ ] No test was weakened, skipped, or removed merely to make the suite pass.
- [ ] Network failure, duplicate request, and recovery implications have been considered for state-changing browser flows.
- [ ] Historical result compatibility has been considered when stored contracts change.
- [ ] The final report lists the exact checks run and any checks not run, with reasons.

Not every change requires every test group. Select the checks based on the components and contracts affected, and state explicitly what was not exercised.

## 14. Maintaining This Document

Update this document when the test stack, CI commands, test boundaries, or reliability guarantees change.

Keep machine-specific instructions in `AGENTS.md`; keep component responsibilities in `docs/architecture/components.md`; keep product behavior and user-facing requirements in `docs/product/overview.md`.

When documenting a reliability guarantee, verify that it is enforced by code and covered by tests. A requirement in this document is not proof that the implementation already satisfies it.
