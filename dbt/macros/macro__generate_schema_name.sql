{# -----------------------------------------------------------------------------
   generate_schema_name
   Purpose:
     Disables dbt's default schema concatenation logic
     (target.schema + '_' + custom_schema_name).

     If +schema is defined for a model, that exact value is used.
     Otherwise, target.schema is used as a fallback.

   Used to implement a clean DWH architecture:
     raw / stg / core / dm
----------------------------------------------------------------------------- #}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is not none -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ target.schema }}
    {%- endif -%}
{%- endmacro %}
