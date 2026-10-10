WITH cleaned AS (
    SELECT
        NULLIF(REGEXP_REPLACE(UPPER(TRIM(project_name)), r'\s+', ' '), '') AS project_name,
        SAFE_CAST(REGEXP_REPLACE(NULLIF(TRIM(transacted_price), '-'), r'[^0-9.-]', '') AS NUMERIC) AS transacted_price,
        SAFE_CAST(REGEXP_REPLACE(NULLIF(TRIM(area_sqft), '-'), r'[^0-9.-]', '') AS NUMERIC) AS area_sqft,
        SAFE_CAST(REGEXP_REPLACE(NULLIF(TRIM(unit_price_psf), '-'), r'[^0-9.-]', '') AS NUMERIC) AS unit_price_psf,
        SAFE.PARSE_DATE('%d %b %Y', NULLIF(TRIM(sale_date), '')) AS sale_date,
        NULLIF(REGEXP_REPLACE(UPPER(TRIM(address)), r'\s+', ' '), '') AS address,
        NULLIF(UPPER(TRIM(type_of_sale)), '') AS type_of_sale,
        NULLIF(UPPER(TRIM(type_of_area)), '') AS type_of_area,
        SAFE_CAST(REGEXP_REPLACE(NULLIF(TRIM(area_sqm), '-'), r'[^0-9.-]', '') AS NUMERIC) AS area_sqm,
        SAFE_CAST(REGEXP_REPLACE(NULLIF(TRIM(unit_price_psm), '-'), r'[^0-9.-]', '') AS NUMERIC) AS unit_price_psm,
        SAFE_CAST(REGEXP_REPLACE(NULLIF(TRIM(nett_price), '-'), r'[^0-9.-]', '') AS NUMERIC) AS nett_price,
        NULLIF(UPPER(TRIM(property_type)), '') AS property_type,
        SAFE_CAST(NULLIF(TRIM(number_of_units), '-') AS INT64) AS number_of_units,
        NULLIF(UPPER(TRIM(tenure)), '') AS tenure,
        NULLIF(TRIM(completion_date), '') AS completion_date,
        NULLIF(UPPER(TRIM(purchaser_address_indicator)), '') AS purchaser_address_indicator,
        NULLIF(TRIM(postal_code), '') AS postal_code,
        NULLIF(TRIM(postal_district), '') AS postal_district,
        NULLIF(TRIM(postal_sector), '') AS postal_sector,
        NULLIF(UPPER(TRIM(planning_region)), '') AS planning_region,
        NULLIF(UPPER(TRIM(planning_area)), '') AS planning_area
    FROM {{ source('property_transactions', 'raw_property_trans') }}
)
SELECT
    *,
    SAFE_CAST(IF(REGEXP_CONTAINS(completion_date, r'^\d{4}$'), completion_date, NULL) AS INT64) AS completion_year,
    CASE
        WHEN UPPER(completion_date) = 'UNCOMPLETED' THEN 'UNCOMPLETED'
        WHEN REGEXP_CONTAINS(completion_date, r'^\d{4}$') THEN 'COMPLETED'
        WHEN completion_date IS NULL THEN NULL
        ELSE 'UNKNOWN'
    END AS completion_status
FROM cleaned

