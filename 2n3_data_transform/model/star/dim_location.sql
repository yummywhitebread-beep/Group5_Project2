WITH cleaned_locations AS (
    SELECT DISTINCT
        NULLIF(REGEXP_REPLACE(UPPER(TRIM(address)), r'\s+', ' '), '') AS address,
        NULLIF(UPPER(TRIM(postal_code)), '') AS postal_code,
        NULLIF(UPPER(TRIM(postal_district)), '') AS postal_district,
        NULLIF(UPPER(TRIM(postal_sector)), '') AS postal_sector,
        NULLIF(UPPER(TRIM(planning_region)), '') AS planning_region,
        NULLIF(UPPER(TRIM(planning_area)), '') AS planning_area
    FROM {{ ref('stg_property_transactions') }}
),
locations AS (
    SELECT *
    FROM cleaned_locations
    WHERE address IS NOT NULL
       OR postal_code IS NOT NULL
       OR postal_district IS NOT NULL
       OR postal_sector IS NOT NULL
       OR planning_region IS NOT NULL
       OR planning_area IS NOT NULL
)
SELECT
    FARM_FINGERPRINT(TO_JSON_STRING(STRUCT(
        address,
        postal_code,
        postal_district,
        postal_sector,
        planning_region,
        planning_area
    ))) AS location_key,
    address,
    postal_code,
    postal_district,
    postal_sector,
    planning_region,
    planning_area
FROM locations
