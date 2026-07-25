{# -----------------------------------------------------------------------------
   generate_schema_name
   Назначение:
     Отключает дефолтную логику dbt по склейке схем
     (target.schema + '_' + custom_schema_name).

     Если для модели задан +schema — используется ровно это значение.
     Иначе используется target.schema как fallback.

   Используется для реализации чистой DWH-архитектуры:
     raw / stg / core / dm
----------------------------------------------------------------------------- #}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is not none -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ target.schema }}
    {%- endif -%}
{%- endmacro %}
