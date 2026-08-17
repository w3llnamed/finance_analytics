# finance_analytics — Claude Code Instructions

## 1. Project purpose

`finance_analytics` is an end-to-end personal finance analytics project and portfolio project.

The system ingests transaction data, transforms it through a layered dbt warehouse, orchestrates pipelines with Prefect, and exposes analytical marts to Apache Superset.

Preserve the existing architecture and project conventions. Do not redesign the project merely because another approach might be cleaner or more sophisticated.

Before proposing or making changes, inspect the relevant existing implementation and adjacent code. Identify and follow established project patterns rather than inferring a convention from a single isolated implementation.

The repository is public, so all committed code, documentation, fixtures, and examples must be safe for public exposure.

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

Prefect orchestrates ingestion and dbt pipeline execution.

Operational metadata and data observability tables live in the `infra` schema.

Do not introduce additional architectural layers such as `int`, `intermediate`, or new services without explicit user approval.

---

## 3. Repository structure

Use the existing project documentation as the starting point for understanding the repository structure and component responsibilities.

Relevant documentation includes the root `README.md`, files under `docs/`, and component-specific README files.

Before making changes, inspect the relevant documentation first, then verify it against the actual repository structure and implementation.

Documentation is a guide, not a substitute for inspecting the code. If documentation and the current implementation disagree, report the discrepancy and treat the current repository state as authoritative unless the user explicitly says otherwise.

Do not infer a directory's purpose from its name alone.

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

Normalize source-specific representations in `stg` before they are consumed by `core`, unless the existing implementation has a documented reason to preserve them further downstream.

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

Superset should consume `dm`, `dm_demo`, and explicitly approved `infra` datasets. Do not introduce direct Superset dependencies on `raw`, `stg`, or `core` without explicit user approval.

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

Do not introduce a new model layer without explicit approval.

Use `ref()` and `source()` rather than hard-coded cross-model relations where appropriate.

Raw tables consumed by dbt should be declared as dbt sources unless the existing project has an explicit exception.

Do not declare infrastructure tables as dbt sources merely because they exist. Add them only when dbt actually consumes them.

Add tests appropriate to the semantic importance of the model.

Prefer existing project test patterns before introducing new generic or singular tests.

Prefer the project's existing test patterns, including where applicable:

- `not_null`;
- `unique`;
- `relationships`;
- accepted/controlled values where appropriate;
- singular assertions for cross-model business integrity.

A test should validate a real data contract or business invariant, not exist only to increase test count.

Do not silently change the meaning of an existing metric or field to make a new feature easier to implement.

Preserve the project's YAML formatting conventions.

In dbt YAML files, separate sibling top-level resource entries with two blank lines.

For example, use two blank lines between individual model, source, seed, snapshot, or macro entries.

Do not add extra blank lines between nested fields such as columns, tests, or descriptions unless the existing file uses that pattern.

Use singular nouns for dbt model names.

Model names should represent the entity or fact contained in a single row, for example:

- `dim__account`, not `dim__accounts`;
- `fact__transaction`, not `fact__transactions`.

Preserve established project prefixes and naming patterns. Do not rename existing models solely to enforce this convention without explicit user approval.

---

## 6. Python ingestion conventions

Python ingestion is responsible for acquiring source data, loading source data into raw, and maintaining ingestion-related operational state in infra where required.

Keep ingestion source-oriented.

Ingestion responsibilities may include:

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

When adding or modifying an ingestion path, inspect the existing ingestion implementation first and follow established project patterns. Do not introduce a new ingestion framework or substantially different pattern without explicit user approval.

---

## 7. Prefect / orchestration conventions

Prefect orchestrates ingestion and dbt execution.

Tasks should have clear responsibilities and return explicit outcomes where the existing flow expects them.

Preserve existing retry and concurrency behavior unless the task explicitly requires changing it.

Reuse the existing orchestration path for dbt execution. Do not create a parallel dbt execution flow without explicit user approval.

Before modifying flow behavior, inspect the existing flow implementation and its relevant Prefect deployment configuration.

Do not introduce a second orchestration framework.

---

## 8. Demo and private data

Private and demo data are different concepts.

Private data must never be exposed, copied into public fixtures, committed, or used in documentation examples.

Demo datasets must contain only anonymized or synthetic data suitable for public use.

Demo analytical models should remain semantically consistent with their corresponding production models where applicable.

Do not expose real account identifiers or names, credentials, transaction details, personal data, or production configuration in:

- tests;
- seeds;
- documentation;
- logs;
- examples;
- generated artifacts.

---

## 9. Documentation conventions

Code and architecture changes should be reflected in the relevant documentation when they change how the system works.

Identify the documentation relevant to the changed component before deciding what needs to be updated.

Do not update every README mechanically.

Update only documentation affected by the change.

Documentation should describe the implemented system, not planned behavior presented as already complete.

Keep documentation, architecture diagrams, and data-flow descriptions consistent with the actual implementation.

PostgreSQL raw/infra objects should follow the existing table/column comment conventions where applicable.

---

## 10. Сhange discipline

Before editing:

1. Read the relevant project documentation.
2. Inspect the relevant implementation.
3. Check adjacent code, models, tests, and documentation for established patterns.
4. Identify the expected scope of the change.
5. Explain the intended approach before making a change that requires architectural or semantic judgment.

Prefer small, reviewable changes.

Do not perform unrelated cleanup while implementing a task.

Do not reformat or rewrite unrelated files.

Preserve existing interfaces and behavior unless changing them is part of the requested task.

Do not rename existing models, fields, directories, or public interfaces without explicit user approval, unless the rename is directly requested by the task.

Do not introduce a new dependency, framework, service, database, architectural layer, or deployment mechanism without explicit user approval.

When an existing implementation appears incorrect, report the issue rather than silently redesigning surrounding code.

Do not use a local issue as justification for a broader refactor without explicit user approval.

Do not expand the scope of a task merely because additional improvements are available.

If you identify useful improvements outside the requested scope, report them separately instead of implementing them.

---

## 11. Git and production boundaries

Claude may inspect Git state, history, branches, and diffs when needed.

Claude must not:

- run `git commit`;
- run `git push`;
- rewrite Git history;
- delete branches;
- run destructive Git operations such as `reset --hard` or destructive restore/checkout operations unless the user explicitly requests that exact operation;
- deploy to production;
- access or modify production systems, services, databases, hosts, credentials, or runtime state;
- use SSH, SCP, or other remote-access mechanisms to reach production.

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

## 12. Security boundaries

Treat secret and private data as unavailable.

Do not attempt to bypass configured permission or sandbox restrictions.

If access to a file, environment variable, path, network resource, or command is denied by Claude Code settings or the sandbox, stop and report that the resource is unavailable.

Do not suggest shell tricks or alternative execution paths intended to circumvent a security restriction.

Do not ask the user to weaken security restrictions merely to simplify implementation.

Use `.env.example` and public project configuration to understand expected environment variables instead of attempting to access real `.env` values.

Do not print, log, copy, summarize, or otherwise expose secrets or private values, even if they become visible incidentally during command execution.
Use `.env.example` and public project configuration to understand expected environment variables instead of attempting to access real `.env` values.

---

## 13. Validation

Run checks appropriate to the files and components changed.

Prefer targeted validation while iterating, followed by broader relevant project checks before declaring the task complete.

For dbt validation, use the project's existing documented execution pattern.

Do not attempt to access Docker, Prefect containers, or other execution environments that are unavailable under the configured sandbox restrictions.

If validation requires such an environment, do not attempt to bypass or request weaker sandbox restrictions. Report the validation as not run and provide the exact command the user should execute manually.

Run only validation that is available within the currently permitted environment.

Inspect the existing Docker Compose, dbt profile, orchestration configuration, and project documentation before choosing the validation command.

Use CI-specific commands or fixtures when the change affects CI behavior.

Do not assume `pytest` or another test framework is required unless the project actually uses it for the changed component.

Do not run validation against production systems or databases.

Validation must not use destructive database operations.

Do not install, upgrade, or add dependencies as part of validation without explicit user approval.

If relevant validation cannot be run because the local environment lacks a required dependency, service, configuration, or access, report that clearly instead of claiming the change is validated.

Before declaring work complete:

- inspect the resulting Git status and diff;
- verify that no unrelated files were changed;
- report which checks were run and their results;
- report any relevant checks that could not be run and why.
-
---

## 14. Definition of Done

A task is complete only when all applicable conditions are met:

- the requested behavior is implemented;
- existing behavior is preserved unless the task intentionally changes it;
- relevant tests and validation have been completed successfully;
- relevant documentation is updated and matches the implementation;
- no secrets or private data are introduced or exposed;
- the scope remains limited to the requested task;
- no unrelated files are changed;
- known limitations, failed checks, and unverified assumptions are explicitly reported.

Before declaring the task complete, inspect the final Git status and diff.

Do not commit or push.

Present the resulting changes and validation results for human review.

---

## 15. When uncertain

Do not guess silently when uncertainty could change the architecture, semantics, security boundaries, or externally relied-upon behavior of the project.

Ask for clarification before making a decision that would:

- change the warehouse or system architecture;
- change the meaning of an existing metric, field, model, or data contract;
- change an existing public interface or externally relied-upon behavior;
- introduce a new dependency, framework, service, database, architectural layer, or deployment mechanism;
- affect production systems or deployment;
- weaken security restrictions;
- change public/private data boundaries.

For normal implementation details that are already established by the existing code, documentation, or nearby patterns, follow those patterns without unnecessary questions.

When several implementation options are equivalent within the approved scope, prefer the option most consistent with the existing project.


## 16. File changes and approval

A user request to implement, fix, update, refactor, or otherwise change the project constitutes approval to modify or create files that are reasonably necessary to complete that task within its requested scope.

Do not require separate approval for routine file changes that directly follow from an explicitly requested implementation task.

If the user asks only for analysis, explanation, review, investigation, or recommendations, do not modify files unless they explicitly ask you to do so.

Before making a change that would expand the requested scope or require architectural, semantic, security, dependency, or public-interface decisions, explain the proposed change and obtain explicit user approval.

Do not delete or rename existing files, or create new top-level project structures, unless the task directly requires it or the user explicitly approves it.

Do not modify unrelated files.
