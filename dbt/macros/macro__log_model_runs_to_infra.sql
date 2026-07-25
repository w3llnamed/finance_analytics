{% macro log_model_runs_to_infra() %}
  {% if not execute %}
    {{ return('') }}
  {% endif %}

  {% set target_name = target.name %}
  {% set stmts = [] %}

  {% do stmts.append("CREATE SCHEMA IF NOT EXISTS infra") %}

  {% do stmts.append("""
    CREATE TABLE IF NOT EXISTS infra.dbt_model_runs_history (
      target_name          text        NOT NULL,
      invocation_id        text        NOT NULL,
      unique_id            text        NOT NULL,
      model_name           text        NOT NULL,
      schema_name          text        NULL,
      materialization      text        NULL,
      status               text        NOT NULL,
      execution_time_sec   numeric     NULL,
      rows_affected        bigint      NULL,
      generated_at         timestamptz NOT NULL DEFAULT NOW(),
      PRIMARY KEY (target_name, invocation_id, unique_id)
    )
  """) %}

  {% for r in results %}
    {% if r.node is not none and r.node.resource_type == 'model' %}

      {% set materialization = none %}
      {% if r.node.config is not none %}
        {% set materialization = r.node.config.get('materialized') %}
      {% endif %}

      {% set rows_affected = none %}
      {% if r.adapter_response is not none %}
        {% set rows_affected = r.adapter_response.get('rows_affected') %}
      {% endif %}

      {% set model_schema = r.node.schema if r.node.schema is not none else none %}

      {% set ins %}
        INSERT INTO infra.dbt_model_runs_history (
          target_name,
          invocation_id,
          unique_id,
          model_name,
          schema_name,
          materialization,
          status,
          execution_time_sec,
          rows_affected,
          generated_at
        )
        VALUES (
          '{{ target_name | replace("'", "''") }}',
          '{{ invocation_id | replace("'", "''") }}',
          '{{ r.node.unique_id | replace("'", "''") }}',
          '{{ r.node.name | replace("'", "''") }}',
          {% if model_schema is not none %}'{{ model_schema | replace("'", "''") }}'{% else %}NULL{% endif %},
          {% if materialization is not none %}'{{ materialization | replace("'", "''") }}'{% else %}NULL{% endif %},
          '{{ r.status | replace("'", "''") }}',
          {% if r.execution_time is not none %}{{ r.execution_time }}{% else %}NULL{% endif %},
          {% if rows_affected is not none %}{{ rows_affected }}{% else %}NULL{% endif %},
          NOW()
        )
        ON CONFLICT (target_name, invocation_id, unique_id) DO NOTHING
      {% endset %}

      {% do stmts.append(ins) %}

    {% endif %}
  {% endfor %}

  {{ return(stmts | join(';\n') ~ ';') }}
{% endmacro %}
