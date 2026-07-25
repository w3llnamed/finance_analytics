{% macro generate_alias_name(custom_alias_name, node) -%}

    {%- if custom_alias_name is not none -%}

        {{ custom_alias_name | trim }}

    {%- else -%}

        {{ node.name
            | replace('raw__', '')
            | replace('stg__', '')
            | replace('core__', '')
            | replace('dm__', '')
            | replace('dm_demo__', '')
            | replace('seed__', '')
            | replace('infra__', '')
        }}

    {%- endif -%}

{%- endmacro %}
