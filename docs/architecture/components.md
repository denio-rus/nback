# Architecture Components

> A component-level guide to the current application. Read this together with [Architecture Overview](overview.md): that document explains the system shape; this one explains the responsibilities and interactions of the main components.

This document describes the implementation currently present in the repository. It is not a target architecture, and it does not authorize new abstractions or features.

## 1. Component Map

The application is a Rails monolith. Components are organized primarily by Rails conventions and domain namespaces, not by separately deployed services.

| Area | Main components | Responsibility |
|---|---|---|
| HTTP and page flow | `ApplicationController`, feature controllers, routes | Request handling, orchestration, access checks, response rendering |
| Authentication context | `Authentication`, `Session`, `Current` | Resume the signed-in user context for a request |
| User and context data | `User`, `CheckIn` | Account data and optional self-reported session context |
| Game catalog | `Game`, `Games::Registry` | Persisted game catalog and mapping from system names to strategies |
| Game domain | `Games::BaseStrategy`, concrete strategies, `Games::Stats` | Setup, result contract, validation, scoring, and game metrics |
| Browser game runtime | `app/javascript/controllers/games/*` | Stimulus-driven interaction and collection of trial input |
| Game presentation | `app/views/games/*`, `app/views/game_sessions/*` | Render game instructions, controls, and session pages |
| Personal trends | `InsightsController`, `Insights::Series` | Load and group one user's completed sessions for a game |
| Content | `Article`, `ArticleTranslation`, article controllers/views | Localized informational content |
| Shared presentation | ERB partials, I18n locale files, layout and helpers | Server-rendered interface and translated text |

The table is a navigation aid, not a strict dependency diagram. Most components run in the same Rails process and share the application's Active Record models and request context.

## 2. HTTP and Request Layer

### 2.1. ApplicationController

`ApplicationController` is the common controller base. It:
- includes the authentication concern;
- applies the modern-browser requirement;
- switches to the locale selected by the route;
- adds the active locale to generated URLs.

Feature controllers should keep HTTP-specific work here or in their own controller actions: parameter handling, authorization, orchestration, and choosing a response. Do not move domain rules into controllers when they belong to a game strategy or model.

### 2.2. Feature Controllers

| Controller | Main responsibility |
|---|---|
| `GameSessionsController` | Create a game session, show its play page, accept a submitted result, and show an owner's completed-session breakdown |
| `InsightsController` | List active games with personal data and display a selected game's trend series |
| Registration, session, password, and account controllers | Account lifecycle and authentication-related flows |
| Admin controllers | Role-protected management of administrative content and feedback |

Controllers are the orchestration boundary between routes, models/domain objects, and views. The current application does not use a universal application-service layer. Follow the established Rails pattern unless a concrete change demonstrates that a new boundary is needed.

### 2.3. Access Boundaries

Authentication is the default through the `Authentication` concern. Controllers can explicitly allow unauthenticated access for selected actions.

For game sessions:
- starting and playing may be anonymous;
- a session created by a signed-in user is associated with that user;
- a session belonging to another user is not accessible by guessing its ID;
- the breakdown page is restricted to the owner and completed sessions;
- the game ID and session ID are checked together when resolving a session.

For insights, the controller starts from `Current.user`; the series object also scopes its query to the supplied user. Preserve this ownership boundary in new queries and tests. An ID is not an authorization mechanism.

## 3. Authentication Context

The request-level authentication flow is implemented by:
- `Authentication` — controller concern that resumes a session, requires authentication, and starts or terminates a session;
- `Session` — persisted application session associated with a user;
- `Current` — request-local holder for the current session and user;
- signed permanent HTTP-only cookie — carries the application session identifier between requests.

Controllers should use `Current.user` rather than independently resolving a user from request parameters or cookies. Changes to cookie behavior, session lifecycle, or authentication filters affect every protected controller and should be covered by authentication and access-control tests.

## 4. User and Check-in Data

### 4.1. User

`User` is the account and ownership root for personal data. It owns or is associated with sessions, check-ins, and game sessions. Identity and recovery details are described in [Architecture Overview](overview.md); consult the model and migrations before changing persistence or account lifecycle behavior.

### 4.2. CheckIn

`CheckIn` stores optional context supplied by a user before a game:
- sleep duration;
- day phase;
- a fixed set of boolean flags (currently alcohol, medication use, illness, hunger, and feeling rested).

The model validates allowed values and normalizes checkbox values. It does not interpret the answers or produce health conclusions.

A check-in belongs to a user and can be associated with multiple game sessions. Deleting a check-in nullifies the association on those sessions rather than deleting the sessions.

The check-in form is optional. `GameSessionsController` skips it for anonymous visitors and when the user skips or submits an empty form. Keep this optionality intact: game play must not depend on completing a check-in.

## 5. Game Catalog and Strategy Components

### 5.1. Game

A `Game` record is the persisted catalog entry. Its `system_name` identifies the strategy and the corresponding localized text. The model delegates game setup to the resolved strategy and reads the title and description from I18n.

The database record also carries catalog state such as category and whether the game is active. The catalog controls which games are offered and which games can be started.

### 5.2. Games::Registry

`Games::Registry` discovers strategy files matching `app/models/games/*_strategy.rb`, excludes the base strategy, and resolves a known system name to its strategy class.

The registry is also responsible for synchronizing strategy metadata into `Game` records. Existing `active` values are preserved during synchronization; newly created records start active.

Important constraint: external input must not be passed directly to `constantize`. Resolve a requested game through the registry's discovered allow-list.

### 5.3. Games::BaseStrategy

`Games::BaseStrategy` defines the shared strategy contract and the common result-processing template.

Required strategy hooks currently include:
- category and rules/specification version;
- setup generation;
- permitted top-level result keys;
- primary metric unit;
- a sample payload used by contract tests.

Optional hooks include:
- article slug;
- additional per-trial keys;
- phases and switch-cost phases;
- result validation and server-side scoring;
- primary and secondary metric extraction and units;
- trial outcome presentation.

The shared `handle_result` flow:
1. filters raw client input through the strategy's permitted-key definition;
2. rejects payloads with more than the shared maximum number of trials;
3. calls the strategy's validation against the persisted setup;
4. merges server-computed score fields;
5. stamps the stored result with the shared result format version.

The base class also provides a common reader for the stored `trials` array. Use this method when consuming trial data so the storage shape is interpreted consistently.

### 5.4. Concrete Strategies

Each concrete strategy owns the rules specific to one game. Current examples include:
- `Games::NbackStrategy`;
- `Games::ReactionTimeStrategy`;
- `Games::StroopTestStrategy`.

A strategy is responsible for defining what setup is issued, what the browser is allowed to submit, how that submission is validated, which values are recomputed by the server, and how the resulting metrics are derived.

Do not trust client-supplied correctness flags or aggregate metrics when they can be derived from the persisted setup and submitted answers. The server-side strategy is the authority for validated results.

### 5.5. Games::Stats

`Games::Stats` contains shared numeric/statistical helpers used by strategies and insights (for example, median calculation). Keep game-specific scoring in the game strategy; place a helper here only when it is genuinely shared.

## 6. Game Session Persistence and Lifecycle

`GameSession` is the persisted record connecting a game, an optional user, and an optional check-in. It stores:
- the setup generated for this particular play-through;
- the submitted and server-processed result;
- completion time (`played_at`);
- primary and secondary metrics.

The main flow is:

1. **Start request:** `GameSessionsController` resolves an active game.
2. **Optional context:** for an authenticated user, the controller builds a check-in unless it is skipped or empty.
3. **Setup:** the game strategy generates the setup. The setup is persisted with the new game session before the play page is rendered.
4. **Play page:** Rails renders the game-specific partial with the setup, localized messages, and result-submission URL exposed as Stimulus values.
5. **Browser interaction:** the Stimulus controller runs the game and collects trial-level input.
6. **Submission:** the browser posts the collected result to the session's result endpoint.
7. **Server processing:** the controller resolves the same game/session pair and invokes `handle_result` on that game's strategy.
8. **Persistence:** the processed result, completion time, and derived metrics are saved.
9. **Read:** the owner can view the completed-session breakdown; personal trends load completed sessions for the selected game.

The persisted setup is essential: it is the reference against which the server validates and scores the submission. Do not regenerate it when processing a result.

### 6.1. Result Submission Contract

The browser submits trial-level data, not an authoritative final score. The strategy filters the payload and recomputes deterministic values. The stored result includes a format version so readers can distinguish the result layout used at the time it was created.

Changes to setup structure, trial fields, scoring, or result format can affect:
- the browser/server contract;
- historical results;
- session breakdown rendering;
- trend metrics;
- contract, request, and system tests.

Treat such changes as cross-component changes. Review existing stored-result readers and tests before changing the contract.

### 6.2. Completion and Failure Semantics

The session endpoint rejects a submission when the session is already marked completed. The browser helper `submitResult` returns a structured success/failure response rather than throwing, so the game controller is responsible for handling that outcome.

When modifying this flow, explicitly verify:
- what the UI displays while submission is pending;
- what happens when the request fails or times out;
- whether a retry can safely submit the same result;
- whether duplicate or concurrent submissions can persist more than once;
- whether a saved result remains accessible if later result rendering fails.

Do not assume that cancelling a browser request means the server did not process it. Any retry design needs a server-side idempotency/concurrency guarantee appropriate to the operation. These are review points for changes, not claims that every failure mode is already handled.

## 7. Browser Game Runtime and Views

### 7.1. Game Partials

Game-specific ERB partials under `app/views/games/` provide the markup for a game. They connect the server-generated setup and localized messages to the corresponding Stimulus controller through `data-*-value` attributes and define the controller targets and actions.

The play page renders the partial selected by the session's game system name. When adding a game, ensure the partial name matches the registered system name and inspect the existing partials for the expected data contract.

### 7.2. Stimulus Controllers

A game controller under `app/javascript/controllers/games/` owns browser interaction:
- rendering the current stimulus and updating controls;
- tracking user input and trial timing;
- maintaining temporary in-browser session state;
- submitting the collected payload to the Rails endpoint.

It should not be treated as an authority for correctness or final metrics. The server validates and scores the result.

### 7.3. Shared JavaScript Helpers

`app/javascript/controllers/games/base.js` contains shared helpers used by game controllers, including:
- localized message lookup and placeholder substitution;
- locale-aware number formatting;
- cancellable timers;
- the JSON result-submission helper.

This module intentionally has no Stimulus controller suffix and no DOM access at module load time, allowing selected helpers to be tested with Node's built-in test runner. Keep shared browser helpers independent of individual game rules.

### 7.4. Browser Lifecycle

Stimulus controllers can connect and disconnect as page content changes. Timers and other asynchronous work created by a game controller must be cleaned up on disconnect. When changing a game flow, consider navigation away, refresh, duplicate input, delayed callbacks, and a request that completes after the UI has moved on.

## 8. Personal Insights Components

### 8.1. InsightsController

`InsightsController#index` prepares the active game catalog grouped by category and counts the signed-in user's completed sessions with a primary metric.

`InsightsController#show` resolves an active game and constructs an `Insights::Series` for `Current.user` and that game.

### 8.2. Insights::Series

`Insights::Series` loads completed sessions for one user and one game, includes their check-ins, and maps them to points ordered by play time.

It provides groupings for:
- one selected check-in flag (with/without);
- day phase.

The grouping helper always returns a count. Median, minimum, and maximum are only calculated when the group reaches `Insights::MIN_POINTS`. Groups for a flag include only sessions with a check-in, because a session without a check-in is not an answer to that flag question.

Insights describe the user's own observations. They should not be presented as population norms, diagnoses, or proof that a recorded circumstance caused a metric to change.

## 9. Content and Localization

Article content is represented by `Article` and `ArticleTranslation`. Translation records hold locale-specific titles and bodies. Article bodies are rendered from Markdown with raw HTML disabled and sanitized output.

I18n locale files provide interface text, game descriptions, instructions, and game-controller messages. Game partials pass the relevant translated messages to Stimulus rather than hard-coding user-facing strings in JavaScript.

When adding or changing visible text, update the relevant locale files and preserve the configured locale fallback behavior.

## 10. Extension Workflows

### 10.1. Adding a Game

A typical game addition touches several components:

1. Add a concrete strategy under `app/models/games/` implementing the base contract.
2. Add the matching Stimulus controller and game partial.
3. Add locale strings for the game title, description, instructions, and runtime messages.
4. Add or update tests for setup, payload filtering, validation, scoring, metrics, and the browser interaction.
5. Run the registry synchronization path so the catalog record reflects the strategy metadata.
6. Update product or architecture documentation only when the supported product behavior or shared architecture changes.

The registry discovers strategy files, so a new game should not require a hand-maintained strategy mapping. Still, verify the system name, partial, controller identifier, locale keys, and catalog record agree.

### 10.2. Changing a Shared Game Contract

Changes to `Games::BaseStrategy`, trial structure, result format, or shared browser helpers affect multiple games. Before editing:
- inspect every concrete strategy;
- inspect all readers of stored results;
- review existing contract and request tests;
- decide how historical results remain readable;
- update tests for every affected strategy and flow.

Do not change a shared contract based only on one game's implementation.

### 10.3. Changing Personal Trends

A change to trend grouping or metrics should be reviewed across:
- the source session query and user scoping;
- check-in association semantics;
- minimum sample-size behavior;
- metric units and missing values;
- chart labels and explanatory copy;
- tests for groups with and without context.

Avoid introducing cross-user comparisons or causal interpretations without an explicit product decision.

## 11. Testing Boundaries

Use tests at the layer that owns the behavior:

| Component | Useful test level |
|---|---|
| Concrete strategy and shared strategy contract | Active Support unit tests |
| Registry and game catalog synchronization | Model/integration tests |
| Session creation, ownership, submission, and HTTP responses | Controller/request integration tests |
| Stimulus-independent JavaScript helpers | Node tests |
| Browser interaction and full game flow | Rails system tests |
| Insights grouping and user scoping | Model tests plus controller/request tests |

For a cross-layer change, test the contract at both sides of the boundary. For example, a new result field may need strategy validation tests, request tests, JavaScript tests, and a browser-level test.

See the project's test strategy documentation when available; this table identifies ownership boundaries, not a replacement for the detailed test commands or release checks.

## 12. Source of Truth and Maintenance

This document is a guide to component responsibilities, not a substitute for source code. For exact behavior, consult the implementation and tests.

When code and this document disagree:
1. inspect the current implementation, migrations, and tests;
2. determine whether the difference is an intentional change, incomplete work, or documentation drift;
3. update the relevant document in the same change when the architecture or component contract has changed.

Keep this file focused on component responsibilities and their interactions. Put product intent in `docs/product/overview.md`, system-wide structure in `docs/architecture/overview.md`, detailed schema relationships in a future data-model reference, and significant historical decisions in ADRs.
