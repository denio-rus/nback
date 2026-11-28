# Product Overview

> A concise description of the product, its purpose, principles, and boundaries.
> This document answers **"what are we building and why?"**, not how the Rails application is implemented.

## 1. Product at a Glance

**Mind at Play** is a web application for personal self-observation through short interactive cognitive games and voluntary self-reported check-ins.

A user completes a game, optionally records contextual information (such as sleep duration, time of day, or other circumstances), and can later review their history and charts of their own results.

The product helps people notice changes and view them alongside their personal context. It does not explain the causes of those changes or make judgments about a person's condition.

The product's core idea:

**Observe yourself over time rather than evaluate yourself against a norm or other people.**

## 2. Intended Audience

The product is intended for people who are interested in observing their own cognitive performance and how results from individual sessions vary under different circumstances.

A user:
- independently decides whether to play a game or record a check-in;
- can return to games and build a personal history;
- reviews their own results over time;
- interprets the data themselves and decides whether observed differences matter to them.

The product does not assume that users have specialized knowledge of psychology, medicine, or statistics. The interface should be understandable without professional terminology.

## 3. Main User Journey

1. The user selects a cognitive game.
2. If signed in, the user is offered an optional pre-session check-in. It can be skipped.
3. The user plays the game.
4. The result is saved and displayed to the user.
5. For signed-in users, the session is added to their personal history.
6. As data accumulates, the user can open the personal trends section and review results for a particular game by date and selected conditions.

A check-in must not become an obstacle to playing. Users can play without registering; anonymous sessions are not added to an account's personal history.

## 4. What Users Observe

### 4.1. Cognitive Games

Games are the primary source of observations. They may cover different areas:

- perception and attentional limits;
- attention control and executive functions;
- memory and cognitive load;
- metacognition and decision-making;
- vigilance and reaction time.

Categories are used to navigate and group games. They are not ratings of a user's abilities.

Each game should have clear rules, a bounded session flow, and explicitly defined result metrics.

### 4.2. Session Context

Before a game, a signed-in user may voluntarily record:

- sleep duration;
- time of day: morning, afternoon, evening, or night;
- alcohol consumption;
- medication use;
- illness;
- hunger;
- subjective alertness.

This list is not a medical questionnaire or diagnostic tool. Users record only what they choose to include for later review of their own history.

All fields are optional. Skipping them must not restrict access to a game.

### 4.3. Results and Personal Trends

Each game has its own metrics. Depending on the mechanics, these may include reaction time, the proportion of correct answers, or the number of errors.

The product does not combine different metrics into a single universal score. Speed and accuracy can have different meanings and should not be combined using arbitrary weights.

Users may see:
- the result of an individual session;
- a sequence of attempts or blocks, when supported by the game;
- changes in the primary metric over time;
- a secondary metric alongside the primary one;
- their own results under different recorded circumstances, when enough data is available.

Metrics from different games are not compared with one another. Charts describe the data; they do not evaluate the person.

## 5. Product Principles

### 5.1. Self-Comparison Only

The primary value is the user's personal progress and variation over time. Other users' results are not used as a control group, ranking, or benchmark.

### 5.2. Description Instead of Judgment

The interface presents measured values and how they change. It does not label results as good, bad, normal, or abnormal.

Avoid wording that turns an observation into a judgment about a person's identity or condition, such as "you are getting worse," "below normal," or "your brain is tired."

### 5.3. No Medical Conclusions

Games and charts are not intended for diagnosis, disease screening, assessment of mental or physical health, or treatment decisions.

The application must not:
- provide diagnoses;
- give medical recommendations;
- interpret results as signs of a disease;
- suggest treatment or changes to medication use;
- present game metrics as clinically validated measurements.

### 5.4. Voluntary Participation Without Pressure

Session context is optional. Users should not feel obliged to complete questionnaires, play regularly, or achieve particular results.

Avoid streaks, penalties for missed sessions, competitive mechanics, and other forms of pressure.

### 5.5. Personal Data Minimization

The product should collect only the data required by the features a user chooses to use.

In particular:
- sign-in uses a nickname rather than a publicly displayed real name;
- an email address is needed for registration confirmation and account recovery; the database stores its HMAC digest rather than the original address;
- gender and age decade are optional;
- account deletion should remove the personal sessions and check-ins associated with that account.

Data processing, retention periods, backups, and legal grounds must be reviewed separately in technical and legal documentation. Do not promise users privacy properties that have not been verified in the implementation.

### 5.6. Clarity and a Calm Interface

The interface should help users focus on the game and on observing their data. Avoid overwhelming users with complex analytics, pseudo-scientific explanations, or decorative gamification.

## 6. Product Boundaries: Out of Scope

The following are not part of the current product concept:

- comparisons between users;
- rankings, leaderboards, and competitions;
- public profiles, avatars, and social features;
- a universal rating of cognitive abilities;
- medical diagnosis and recommendations;
- automated explanations for changes in results;
- claims of causal relationships between circumstances and results.

If a feature from this list is proposed in the future, it must not be added as an ordinary interface enhancement. The product principles must first be reviewed and the change in direction explicitly approved.

## 7. Current MVP Scope

The MVP is built around the following capabilities:

- registration, email address confirmation, nickname-based sign-in, and password recovery;
- a catalog of cognitive games;
- game sessions for both signed-in and anonymous users;
- an optional pre-session check-in for signed-in users;
- result persistence and personal session history;
- viewing the result of an individual session;
- a personal trends section organized by game;
- interface localization;
- informational articles and news;
- a feedback form and administrative tools for managing content.

The available games and the implementation status of individual flows are determined by the actual application and the documentation for each game. This overview does not replace an implementation review.

## 8. Possible Future Directions

The following may be considered in the future, but agents must not treat them as approved requirements:

- expanding the cognitive game library;
- making personal trend analysis more convenient;
- adding ways to filter and compare a user's own sessions;
- improving the presentation of results and history;
- developing educational material about game mechanics and the limitations of measurements.

Any expansion should preserve the core principles: personal observation, descriptive presentation, voluntary participation, and no medical claims.

## 9. Terminology

| Term | Meaning |
|---|---|
| Game | An interactive task with defined rules and metrics |
| Session | One run of a game by a signed-in user or anonymous visitor |
| Trial | An individual stimulus, question, or action within a session |
| Result | Data produced by a completed session |
| Context / check-in | Voluntary information recorded by the user about circumstances before a session |
| Primary metric | The main metric for a particular game, used to display trends |
| Secondary metric | An additional metric for a particular game, displayed alongside the primary metric |
| Personal trends | A user's own metrics and their changes over time |

## 10. How to Use This Document

This file is a source of product context for developers and AI agents.

Before designing a new user-facing feature, an agent should check that it is consistent with the sections "Product Principles" and "Product Boundaries."

This document does not describe:
- application architecture and software component boundaries;
- database schema and APIs;
- the algorithms used by individual games;
- the testing strategy;
- agent workflows and rules for making changes.

That information belongs in the relevant architecture and development documents.

If the actual implementation differs from this overview, do not automatically assume that either the code or the document is correct. Record the discrepancy and determine whether it represents an unfinished feature, technical debt, or a change in product direction.
