# ADR 0001: Analytics Data Contract Between Games and Insights

- **Status:** Accepted
- **Date:** 2026-11-28

## Context

Games own game-specific rules, result validation, scoring, and the meaning of their metrics. Insights owns the selection and comparison of sessions, the association of user-provided observations, and the presentation of personal history.

Insights must be able to consume analytics data without depending on the internal structure of game-specific result payloads. At the same time, Games must not become responsible for Insights use cases or chart presentation.

The contract should normalize the shape of analytics data, not the meaning of metrics across different games. Metrics from different tests are not assumed to be comparable.

## Decision

The analytics contract supports two data shapes:

### 1. `point`

A single scalar measurement associated with a game session.

Examples include:
- median reaction time for a session;
- total number of errors;
- final accuracy.

A point contains a metric identifier, a value, and its unit. Session identity and session timestamp are supplied by the session context; they are not duplicated in each metric value.

Illustrative shape:

```ruby
{
  type: :point,
  metric: :median_reaction_time,
  value: 520,
  unit: :ms
}
```

### 2. `series`

An ordered collection of measurements within one game session.

Examples include:
- reaction time by trial;
- cumulative errors by trial;
- accuracy across phases or stages.

Each sample contains an x-coordinate and a value. The coordinate represents the position or measurement coordinate within the test. Its interpretation is defined by the metric provider (for example, trial number or elapsed time), not by the chart implementation.

A sample may include an optional phase label when phase information is meaningful.

Illustrative shape:

```ruby
{
  type: :series,
  metric: :cumulative_errors,
  unit: :count,
  points: [
    { x: 1, value: 0 },
    { x: 2, value: 1 },
    { x: 3, value: 3, phase: "rule_switch" }
  ]
}
```

A game may provide both points and series for the same session.

## Responsibilities

- **Games** owns the meaning and calculation of game-specific metrics and translates its internal result representation into the analytics contract.
- **Insights** consumes the generic contract. It owns session selection, filtering, association with observations, aggregation where appropriate, and presentation.
- **Games** does not define chart types, colors, chart configuration, or which sessions Insights should compare.
- **Insights** does not inspect or depend on game-specific result payload structures.

The contract describes data, not visualization. A `series` may be rendered as a line chart, bars, a table, or another suitable presentation.

## Constraints

- The two supported shapes are `point` and `series`.
- A `point` represents one scalar value for a session.
- A `series` represents an ordered set of values within a session.
- The x-coordinate belongs to the test's internal progression and may represent a trial number, time, or another meaningful coordinate.
- Phase information is optional metadata on a series sample; it does not define a separate data shape.
- Metric identifiers and units describe individual metrics. They do not imply comparability between different games.
- Analytics remains descriptive. Associations with user observations must not be presented as proof of causation.

## Consequences

- Insights can work with a small, stable set of data shapes without knowing game-specific result schemas.
- Each game remains responsible for exposing meaningful metrics in those shapes.
- The contract does not prescribe a universal metric taxonomy or cross-game comparison model.
- A metric catalog/discovery mechanism, additional data shapes, and richer coordinate metadata are deferred until concrete product needs require them.
- Existing result storage and game strategies do not need to be refactored solely to introduce this contract; adapters can be added when Insights begins consuming it.

## Alternatives Considered

### Games provides chart-ready data

Rejected because it would make Games responsible for presentation concerns and Insights use cases.

### Insights reads game-specific result payloads

Rejected because it couples Insights to each game's internal result representation.

### A larger universal analytics model

Deferred because the current requirements need only session-level scalar values and within-session measurement series. More dimensions or data shapes would add complexity without a demonstrated need.
