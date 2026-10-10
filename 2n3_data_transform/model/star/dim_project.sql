WITH cleaned_projects AS (
    SELECT DISTINCT
        NULLIF(REGEXP_REPLACE(UPPER(TRIM(project_name)), r'\s+', ' '), '') AS project_name,
        NULLIF(UPPER(TRIM(property_type)), '') AS property_type,
        NULLIF(UPPER(TRIM(tenure)), '') AS tenure,
        completion_year,
        NULLIF(UPPER(TRIM(completion_status)), '') AS completion_status
    FROM {{ ref('stg_property_transactions') }}
),
projects AS (
    SELECT *
    FROM cleaned_projects
    WHERE project_name IS NOT NULL
)
SELECT
    FARM_FINGERPRINT(TO_JSON_STRING(STRUCT(
        project_name,
        property_type,
        tenure,
        completion_year,
        completion_status
    ))) AS project_key,
    project_name,
    property_type,
    tenure,
    completion_year,
    completion_status
FROM projects
