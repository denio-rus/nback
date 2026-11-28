# Architecture Overview

> A high-level map of the application's current technical structure.
> This document describes the implementation visible in the repository; it is not a target architecture or a list of future requirements.

## 1. System Context

**Mind at Play** is a server-rendered Ruby on Rails web application. Its main workflow is a browser-based cognitive game session, followed by server-side result validation and persistence, and (for signed-in users) personal history and trend views.

The application is currently structured as a **Rails monolith**:
- Rails handles routing, authentication, page rendering, domain logic, persistence, and result processing.
- PostgreSQL stores application data.
- Stimulus controllers implement the interactive parts of games in the browser.
- Hotwire Turbo enhances navigation and page interactions.
- I18n provides English and Russian interface text.

There is no separately deployed frontend application or public game-processing API in the current structure.

## 2. Technology Stack

| Area | Current implementation |
|---|---|
| Language and framework | Ruby 3.4.4, Rails 8.1 |
| Database | PostgreSQL |
| Web server | Puma |
| HTML rendering | Rails controllers and ERB views |
| Browser interaction | Hotwire Turbo and Stimulus |
| JavaScript delivery | Import Maps (ES modules, no frontend bundler in the main application setup) |
| CSS | Tailwind CSS Rails integration; Propshaft asset pipeline |
| Authentication | Rails authentication components, has_secure_password, application-owned sessions |
| Authorization roles | Rolify |
| Background jobs / cache / cable adapters | Solid Queue, Solid Cache, Solid Cable dependencies and production database configurations |
| Tests | Minitest, Capybara/Selenium system tests, Node's built-in test runner for selected JavaScript modules |
| Deployment | Docker and Kamal configuration |

The presence of an adapter or dependency does not by itself mean that the application currently relies on it for a particular feature. Check the relevant configuration and call sites before introducing architectural assumptions.

## 3. High-Level Structure

The main application code follows conventional Rails boundaries:

- app/controllers/ — HTTP request handling, authentication filters, access checks, and orchestration of application operations.
- app/models/ — Active Record entities and domain logic, including game strategy contracts and insight-series preparation.
- app/views/ — server-rendered ERB pages and partials.
- app/javascript/controllers/ — Stimulus controllers for interactive browser behavior.
- config/locales/ — interface and game text, including locale-specific game descriptions and instructions.
- db/ — migrations, schema, and database-related configuration.
- test/ — Rails tests and JavaScript tests.
- docs/ — product, architecture, development, and decision documentation.

The application does not currently enforce a separate service-layer architecture across all features. Follow existing local conventions rather than adding service objects or new abstraction layers automatically.

## 4. Main Domain Components

### 4.1. Users and Authentication

- User stores the nickname, password digest, email HMAC digest, confirmation state, and optional demographic fields.
- The original email address is treated as a virtual attribute: it is used during registration and mail delivery, while the database stores its HMAC digest.
- Session is an application model associated with a user. The session identifier is stored in a signed, permanent, HTTP-only cookie.
- Current provides request-local access to the current session and user.
- The Authentication controller concern resumes sessions and protects authenticated routes.
- Roles are managed through Rolify; the application includes player and admin role usage.

Registration, email confirmation, password recovery, and account management are handled by Rails controllers and mailers. Review those flows before changing identity, credential, or email-handling behavior.

### 4.2. Games and Strategies

A game is represented by a Game database record. Its system_name connects it to a Ruby strategy class.

The strategy mechanism is organized around:

- Games::BaseStrategy — the shared contract and result-processing template;
- Games::Registry — discovers strategy files and resolves known system names;
- individual strategy classes such as Games::NbackStrategy, Games::ReactionTimeStrategy, and Games::StroopTestStrategy;
- Games::Stats — shared numeric helpers.

A strategy provides game metadata, setup generation, permitted client result fields, validation, server-side scoring, and primary/secondary metric extraction.

The registry checks a requested system name against discovered strategy names before resolving a class. Do not replace this with direct constantization of user-controlled input.

Adding a game generally involves a strategy implementation, its browser controller and view partial, locale text, and tests. Inspect the existing game implementations and their shared contract tests before changing that workflow.

### 4.3. Game Sessions and Check-ins

- GameSession belongs to a game and may belong to a user and a check-in.
- Anonymous sessions have no user_id.
- A session stores the generated game setup, the submitted result payload, the completion timestamp, and the primary and secondary metrics.
- CheckIn belongs to a user and stores optional sleep duration, day phase, and boolean context flags.
- A check-in can be associated with multiple game sessions; deleting a check-in nullifies the session association rather than deleting the sessions.

The session setup is generated on the server and persisted before play begins. This lets the server validate and score the submitted answers against the setup that was issued for that session.

### 4.4. Personal Insights

Insights::Series prepares a user's completed sessions for one game, including associated check-in context. It produces points and grouped summaries for context flags and day phases.

The insights controller scopes queries to Current.user. The current implementation is descriptive: it presents the user's own results and does not compare users or infer causal relationships.

## 5. Game Session Data Flow

The standard game flow is:

1. The browser requests a new game session.
2. For a signed-in user, the user may submit an optional check-in; anonymous visitors skip this step.
3. Rails resolves the active game and asks its strategy to generate a setup.
4. Rails persists a GameSession containing the setup and optional user/check-in association.
5. The browser loads the play page. The game-specific Stimulus controller receives the setup and localized messages through HTML data attributes.
6. The Stimulus controller runs the game and collects trial-level user actions.
7. The browser posts the result payload to the session's submit_result endpoint.
8. The strategy permits the expected input shape, validates it against the persisted setup, and calculates trusted metrics on the server.
9. Rails stores the result, completion timestamp, and extracted metrics.
10. The result page and personal insights read the persisted server-side data.

The browser is responsible for interaction and collecting user actions. It is not the authority for correctness or final metrics where the server can recompute them.

### Result Contract

The shared strategy contract:
- limits the number of trials;
- filters client input through an explicit permitted-key list;
- validates the payload and game-specific invariants;
- computes deterministic scores on the server;
- stores a result format version.

Game-specific result formats are therefore coupled to their strategy implementation and stored setup. When changing a result format, consider existing persisted sessions, breakdown views, metrics, and tests—not only the current browser controller.

## 6. Browser-Side Game Architecture

The main JavaScript entry point loads Turbo and Stimulus through Import Maps.

Game-specific Stimulus controllers live under app/javascript/controllers/games/. They own the interactive lifecycle of a game: starting, advancing stimuli, recording actions, updating the visible state, and submitting results.

app/javascript/controllers/games/base.js contains shared helpers, including:
- localized message lookup and number formatting;
- cancellable timer management;
- the result-submission helper.

The shared helper is deliberately separate from Stimulus controller auto-discovery. It has no DOM access at module load time and can be tested independently with Node.

The server-rendered game views provide the DOM targets, controller identifiers, setup values, localized messages, and Rails-generated submission URLs. Keep the browser/server contract explicit when changing either side.

## 7. Persistence Model

The core relationships are:

```text
User
 ├── has many Sessions (authentication sessions)
 ├── has many GameSessions
 └── has many CheckIns
        └── has many GameSessions (optional association)

Game
 └── has many GameSessions

GameSession
 ├── belongs to Game
 ├── optionally belongs to User
 └── optionally belongs to CheckIn

Article
 └── has many ArticleTranslations
```

Important persistence characteristics:
- PostgreSQL is used in development, test, and production.
- Game-specific setup and result data are stored as JSON/JSONB payloads.
- Check-in flags are stored as a JSONB hash of known boolean keys.
- User email lookup uses a unique HMAC digest rather than a stored plaintext address.
- Nickname uniqueness is enforced case-insensitively at the database index level.
- Foreign keys express the main ownership and association relationships.

The database schema and migrations are authoritative for the exact columns, indexes, constraints, and deletion behavior. Update the schema through migrations, not by editing db/schema.rb directly.

## 8. HTTP and Access Boundaries

- Application pages are locale-prefixed; the available locales are configured in Rails I18n.
- The root route selects a locale and redirects to the localized application.
- Most routes require authentication by default. Public routes opt out explicitly.
- Anonymous users can start and submit game sessions, but only authenticated owners can view a completed session breakdown.
- User profile actions are scoped to the current user.
- Insights are scoped to the current user.
- Administrative controllers are separated under the Admin namespace and use role-based access.
- Rails-generated URLs and CSRF protection are used for browser form and result submissions.

When adding an endpoint, explicitly decide whether it is public, authenticated, owner-scoped, or administrator-only. Do not rely on obscurity of record IDs as an access-control mechanism.

## 9. Content and Localization

Articles and news share the Article model and controller flow. Translated titles and bodies are stored in ArticleTranslation records keyed by locale. Article bodies use Markdown rendering through CommonMarker; raw HTML is disabled and rendered output is sanitized.

Interface and game text are stored in Rails I18n locale files. English is the default locale and Russian is also available, with English fallback configured.

Keep user-visible strings out of game-controller logic where practical. Game controllers receive localized messages from server-rendered views.

## 10. Operational Shape

The repository includes Docker and Kamal deployment configuration. Puma serves the Rails application, and PostgreSQL is required in every environment.

Production database configuration defines separate primary, cache, queue, and cable databases. Solid Cache, Solid Queue, and Solid Cable are included in the dependency set. Before relying on a specific background job, cache, or Action Cable behavior, inspect the current environment configuration and actual usage.

Operational configuration and secrets are supplied through environment variables. In particular, EMAIL_PEPPER is required to derive email digests; changing or losing it prevents lookup of existing email digests and therefore affects email-based account recovery.

## 11. Architectural Constraints and Change Guidance

When modifying the application:

1. Preserve the Rails monolith unless a concrete requirement justifies a new deployable component.
2. Keep game-specific rules in the relevant strategy; keep shared result-contract behavior in Games::BaseStrategy.
3. Treat the persisted game setup and strategy result format as a contract between session creation, browser play, server validation, and historical result rendering.
4. Treat the server as authoritative for result validation and metrics.
5. Keep user-owned data access scoped to the current user and test access-control boundaries.
6. Preserve anonymous play without accidentally exposing authenticated users' history.
7. Keep check-ins optional and separate from the ability to play.
8. Avoid adding abstractions that duplicate the existing Rails and strategy structure without a demonstrated need.
9. Update tests and relevant documentation when changing a contract, data relationship, or cross-layer flow.

## 12. What This Document Does Not Specify

This overview is not a complete specification of:
- every controller, model, callback, or route;
- every game algorithm and its scoring rules;
- every database constraint or migration detail;
- deployment topology, monitoring, backup, or recovery procedures;
- a target architecture for future features.

For implementation work, inspect the relevant source files, tests, migrations, and configuration. If this overview conflicts with the code, verify the current implementation and update this document when the architectural understanding changes.
