# finance_analytics — Claude Code Instructions

## 1. Project purpose

`finance_analytics` is an end-to-end personal finance analytics project and portfolio project.

The system ingests transaction data, transforms it through a layered dbt warehouse, orchestrates pipelines with Prefect, and exposes analytical marts to Apache Superset.

Preserve the existing architecture and conventions. Do not redesign the project merely because another approach might be cleaner or more sophisticated.

Before making changes, inspect the relevant existing implementation and follow its established patterns.

---

## 2. High-level architecture

The main data flow is:

```text
Money Flow
    ↓
CSV export
    ↓
S3
    ↓
Python ingestion
    ↓
PostgreSQL raw
    ↓
dbt
raw → stg → core → dm
    ↓
Superset
```

Orchestration is handled by Prefect.

Infrastructure and observability data live in the `infra` schema.

The multicurrency feature additionally introduces:

```text
External FX source
    ↓
Python FX ingestion
    ↓
raw.exchange_rates
    ↓
dbt normalization / conversion logic
    ↓
core / dm
    ↓
Superset
```

Do not introduce additional architectural layers such as `int`, `intermediate`, or new services unless explicitly requested.

---

## 3. Repository structure

Important areas:

```text
ingestion/
```

Python source ingestion.

```text
orchestration/
```

Prefect flows and deployment configuration.

```text
dbt/
```

dbt project, models, tests, seeds, macros, and documentation.

```text
infra/bootstrap/
```

PostgreSQL bootstrap SQL: schemas, roles, raw and infrastructure tables, grants, and comments.

```text
infra/deploy/
```

Deployment/runtime configuration templates.

```text
tests/ci/
```

Synthetic CI fixtures used to build and test the dbt project.

```text
docs/
```

Architecture and deployment documentation.

Do not assume a directory's purpose from its name alone. Verify existing patterns before adding new files.

---

## 4. Data warehouse layers

The warehouse architecture is:

```text
raw → stg → core → dm
```

The `infra` schema is separate and is used for operational metadata and observability.

### raw

Purpose:

- preserve ingested source data;
- minimize transformation;
- provide stable input for dbt;
- retain source-specific values where needed for correct downstream interpretation.

Business logic does not belong in `raw`.

Raw ingestion tables are created in `infra/bootstrap/`.

### stg

Materialization:

```text
view
```

Purpose:

- source cleanup;
- parsing;
- type conversion;
- normalization of source-specific representations;
- simple deterministic derived fields required by downstream models.

Staging should not contain reporting-specific business logic.

Source-specific representations should preferably be normalized here before they reach `core`.

### core

Materialization:

```text
table
```

Purpose:

- canonical business entities and facts;
- business rules;
- reusable analytical logic;
- joins between normalized entities;
- classifications used by downstream marts.

`core` is the canonical analytical layer.

Do not move presentation-specific Superset logic into `core`.

### dm

Materialization:

```text
table
```

Purpose:

- consumer-facing analytical marts;
- stable datasets intended for BI;
- fields required by Superset;
- presentation-oriented structures where appropriate.

Superset should primarily consume `dm`, `dm_demo`, and approved `infra` datasets rather than querying `raw`, `stg`, or `core` directly.

### infra

Materialization:

```text
table
```

Purpose:

- ingestion state;
- pipeline status;
- dbt test history;
- freshness;
- volume monitoring;
- other operational metadata.

Do not treat `infra` as another business-data transformation layer.

---

## 5. dbt conventions

Follow existing dbt naming and directory conventions.

Current model areas include:

```text
00_sources
01_stg
02_core
03_dm
04_dm_demo
90_infra
```

Do not introduce a new model layer without explicit approval.

Use `ref()` and `source()` rather than hard-coded cross-model relations where appropriate.

New raw tables consumed by dbt should normally be declared as dbt sources.

Do not declare infrastructure tables as dbt sources merely because they exist. Add them only when dbt actually consumes them.

Add tests appropriate to the semantic importance of the model.

Prefer existing project test patterns before introducing new generic or singular tests.

Existing test patterns include:

- `not_null`;
- `unique`;
- `relationships`;
- accepted/controlled values where appropriate;
- singular assertions for cross-model business integrity.

A test should validate a real data contract or business invariant, not exist only to increase test count.

Do not silently change the meaning of an existing metric or field to make a new feature easier to implement.

---

## 6. Python ingestion conventions

Python ingestion is responsible for acquiring source data and loading the raw/infrastructure schemas.

Keep ingestion source-oriented.

Ingestion code may:

- fetch external/source data;
- validate required configuration;
- parse transport formats;
- preserve source values;
- perform idempotency/upsert handling;
- maintain ingestion state;
- log operational results.

Ingestion code should not implement analytical or BI business logic that belongs in dbt.

Prefer explicit configuration through environment variables.

Never hard-code credentials, secrets, production endpoints, or private data.

`.env.example` documents variable names and safe example/default values. Real secrets must never be added to tracked files.

When adding a new ingestion path, inspect the existing ingestion implementation and reuse project conventions where reasonable rather than creating an unrelated framework.

---

## 7. Exchange-rate / multicurrency conventions

FX ingestion currently supports source-specific raw exchange-rate data.

Raw FX values must preserve enough information to interpret the original source correctly.

In particular:

- do not assume every quoted rate represents one unit of the base currency;
- preserve and correctly handle source nominal/base amounts;
- do not assume CBR and ECB expose rates in the same orientation;
- normalize provider-specific representations before applying conversion logic downstream;
- handle reference-currency identity conversion explicitly where necessary;
- transaction dates may fall on weekends or holidays, so rate lookup must account for dates without a published rate.

Provider-specific FX representation should be normalized in the existing `stg` layer before downstream business logic consumes it.

Do not introduce a new `int` or intermediate layer for FX logic.

Do not hard-code a single reporting currency unless explicitly requested.

The intended product requirement is broader multicurrency reporting, including the ability to represent amounts in a selected target currency.

Do not assume that a fixed reporting currency solves the product requirement.

The final mart shape for target-currency selection must be agreed before implementing reporting-currency-specific structures.

Do not move FX conversion logic into Superset if it belongs in the warehouse.

Preserve original/native transaction amounts and currencies unless an explicitly approved design says otherwise.

---

## 8. Prefect / orchestration conventions

Prefect orchestrates ingestion and dbt execution.

Tasks should have clear responsibilities and return explicit outcomes where the existing flow expects them.

Preserve existing retry and concurrency behavior unless a change is required by the feature.

A data-producing ingestion task should not independently trigger unrelated deployment or production operations.

dbt execution should remain part of the existing orchestration flow rather than being duplicated in new orchestration paths without a concrete reason.

Before modifying flow behavior, inspect both:

```text
orchestration/flows/
```

and the relevant Prefect deployment configuration.

Do not introduce a second orchestration framework.

---

## 9. Demo and private data

Private and demo data are different concepts.

Private data must never be exposed, copied into public fixtures, committed, or used in documentation examples.

The private seed area is intentionally restricted.

Demo datasets must contain only anonymized or synthetic data suitable for public use.

Demo dbt models are enabled conditionally and should remain logically consistent with the corresponding production analytical models where applicable.

Do not expose real account names, credentials, transaction details, personal data, or production configuration in:

- tests;
- seeds;
- documentation;
- logs;
- examples;
- generated artifacts.

---

## 10. Documentation conventions

Code and architecture changes should be reflected in the relevant documentation when they change how the system works.

Possible documentation locations include:

```text
README.md
docs/
ingestion/README.md
orchestration/README.md
infra/README.md
dbt/README.md
```

Do not update every README mechanically.

Update only documentation affected by the change.

Documentation should describe the implemented system, not planned behavior presented as already complete.

Keep architecture diagrams and data-flow descriptions consistent with the actual repository.

PostgreSQL raw/infra objects should follow the existing table/column comment conventions where applicable.

When existing documentation conflicts with actual code, report the discrepancy instead of silently treating the documentation as authoritative.

---

## 11. Change discipline

Before editing:

1. Read the relevant files.
2. Understand the current implementation.
3. Check adjacent models, tests, and docs for established patterns.
4. Explain the intended change when the task requires architectural judgment.

Prefer small, reviewable changes.

Do not perform unrelated cleanup while implementing a feature.

Do not reformat or rewrite unrelated files.

Do not rename existing models, fields, directories, or public interfaces unless explicitly required.

Do not introduce a new dependency, framework, service, database, architectural layer, or deployment mechanism without explicit approval.

When an existing implementation appears incorrect, report the issue rather than silently redesigning surrounding code.

Do not expand the scope of a task merely because additional improvements are available.

---

## 12. Git and production boundaries

Claude may inspect Git state, history, and diffs when needed.

Claude must not:

- run `git commit`;
- run `git push`;
- rewrite Git history;
- deploy to production;
- use SSH or SCP to access production;
- modify production credentials;
- access production databases;
- modify production runtime state.

The human owner performs final review, commit, push, and production deployment.

The expected workflow is:

```text
requirements / architecture
        ↓
Claude Code
        ↓
local changes
        ↓
tests and validation
        ↓
git diff
        ↓
human review
        ↓
human commit / push
        ↓
production
```

---

## 13. Security boundaries

Treat secret and private data as unavailable.

Do not attempt to bypass configured permission or sandbox restrictions.

If access to a file, environment variable, path, network resource, or command is denied by Claude Code settings or the sandbox, stop and report that the resource is unavailable.

Do not suggest shell tricks or alternative execution paths intended to circumvent a security restriction.

Never request that security restrictions be disabled merely to simplify implementation.

Use `.env.example` and public project configuration to understand expected environment variables instead of attempting to access real `.env` values.

---

## 14. Validation

Run checks appropriate to the files changed.

Prefer the narrowest useful validation during development, followed by broader project checks before declaring a feature complete.

Relevant project checks may include:

```bash
dbt build --target dev
```

and:

```bash
pre-commit run --all-files
```

Use CI-specific commands or fixtures where the change affects CI behavior.

Do not assume `pytest` or another test framework is mandatory unless the project actually uses it for the changed component.

Do not run commands against production.

Do not run destructive database commands.

Do not install or upgrade dependencies merely to make a check pass without first explaining why that dependency change is necessary.

If a required validation cannot be run because the local environment lacks a dependency or service, report that clearly instead of claiming the change is validated.

Before declaring work complete, inspect the resulting Git diff and report unrelated changes if any appear.

---

## 15. Definition of Done

A change is complete only when all applicable conditions are met:

- implementation follows the existing architecture;
- the requested behavior is implemented;
- existing behavior is preserved unless intentionally changed;
- relevant tests are added or updated;
- applicable checks pass;
- data contracts and edge cases are considered;
- relevant documentation is updated;
- demo behavior remains consistent where applicable;
- no private data or secrets are introduced;
- no unrelated files are changed;
- the final diff is small enough to review and explain;
- remaining limitations or unverified assumptions are explicitly reported.

Do not commit or push after completing the work.

Present the result for human review.

---

## 16. When uncertain

Do not guess silently.

If a requirement affects:

- warehouse architecture;
- metric semantics;
- data ownership;
- target/reporting currency behavior;
- production deployment;
- security;
- public/private data boundaries;

stop and ask for clarification before implementing the architectural decision.

For normal implementation details that are already established by nearby code, follow the existing pattern without unnecessary questions.
