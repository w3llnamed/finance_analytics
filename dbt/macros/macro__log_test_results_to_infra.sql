{% macro log_test_results_to_infra() %}
  {% if not execute %}
    {{ return('') }}
  {% endif %}

  {% set target_name = target.name %}
  {% set stmts = [] %}

  {% do stmts.append("CREATE SCHEMA IF NOT EXISTS infra") %}

  {% do stmts.append("""
    CREATE TABLE IF NOT EXISTS infra.dbt_test_results_history (
      target_name       text        NOT NULL,
      invocation_id     text        NOT NULL,
      unique_id         text        NOT NULL,
      test_name         text        NOT NULL,
      model_unique_id   text        NULL,
      status            text        NOT NULL,
      severity          text        NULL,
      failures          bigint      NULL,
      execution_time_s  numeric     NULL,
      message           text        NULL,
      logged_at         timestamptz NOT NULL DEFAULT NOW(),
      PRIMARY KEY (target_name, invocation_id, unique_id)
    )
  """) %}

  {% do stmts.append("""
    CREATE TABLE IF NOT EXISTS infra.dbt_test_results_current (
      target_name       text        NOT NULL,
      invocation_id     text        NOT NULL,
      unique_id         text        NOT NULL,
      test_name         text        NOT NULL,
      model_unique_id   text        NULL,
      status            text        NOT NULL,
      severity          text        NULL,
      failures          bigint      NULL,
      execution_time_s  numeric     NULL,
      message           text        NULL,
      updated_at        timestamptz NOT NULL DEFAULT NOW(),
      PRIMARY KEY (target_name, unique_id)
    )
  """) %}

  {% do stmts.append(
    "DELETE FROM infra.dbt_test_results_current WHERE target_name = '" ~ (target_name | replace("'", "''")) ~ "'"
  ) %}

  {% for r in results %}
    {% if r.node is not none and r.node.resource_type == 'test' %}

      {% set severity = none %}
      {% if r.node.config is not none %}
        {% set severity = r.node.config.get('severity') %}
      {% endif %}

      {% set failures = r.failures if r.failures is not none else none %}
      {% set msg = r.message if r.message is not none else none %}

      {% set model_uid = none %}
      {% if r.node.attached_node is not none %}
        {% set model_uid = r.node.attached_node %}
      {% elif r.node.depends_on is not none and r.node.depends_on.nodes is not none %}
        {% for dep in r.node.depends_on.nodes %}
          {% set dep_txt = dep | string %}
          {% if dep_txt[:6] == 'model.' %}
            {% set model_uid = dep_txt %}
          {% endif %}
        {% endfor %}
      {% endif %}

      {% set common_values %}
        '{{ target_name | replace("'", "''") }}',
        '{{ invocation_id | replace("'", "''") }}',
        '{{ r.node.unique_id | replace("'", "''") }}',
        '{{ r.node.name | replace("'", "''") }}',
        {% if model_uid is not none %}'{{ model_uid | replace("'", "''") }}'{% else %}NULL{% endif %},
        '{{ r.status | replace("'", "''") }}',
        {% if severity is not none %}'{{ severity | replace("'", "''") }}'{% else %}NULL{% endif %},
        {% if failures is not none %}{{ failures }}{% else %}NULL{% endif %},
        {% if r.execution_time is not none %}{{ r.execution_time }}{% else %}NULL{% endif %},
        {% if msg is not none %}'{{ msg | replace("'", "''") }}'{% else %}NULL{% endif %}
      {% endset %}

      {% do stmts.append("""
        INSERT INTO infra.dbt_test_results_history (
          target_name,
          invocation_id,
          unique_id,
          test_name,
          model_unique_id,
          status,
          severity,
          failures,
          execution_time_s,
          message
        )
        VALUES (
          """ ~ common_values ~ """
        )
        ON CONFLICT (target_name, invocation_id, unique_id) DO NOTHING
      """) %}

      {% do stmts.append("""
        INSERT INTO infra.dbt_test_results_current (
          target_name,
          invocation_id,
          unique_id,
          test_name,
          model_unique_id,
          status,
          severity,
          failures,
          execution_time_s,
          message,
          updated_at
        )
        VALUES (
          """ ~ common_values ~ """,
          NOW()
        )
      """) %}

    {% endif %}
  {% endfor %}

  {{ return(stmts | join(';\n') ~ ';') }}
{% endmacro %}
