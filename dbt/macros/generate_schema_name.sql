{#
    By default dbt names custom schemas "<target schema>_<custom schema>",
    e.g. main_staging. This override uses the custom schema name as-is
    (staging, intermediate, marts, seeds), and falls back to the target
    schema (main) when a model doesn't set one.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
