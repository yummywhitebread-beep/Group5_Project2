WITH source_transactions AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            ORDER BY TO_JSON_STRING(STRUCT(
                project_name,
                transacted_price,
                area_sqft,
                unit_price_psf,
                sale_date,
                address,
                type_of_sale,
                type_of_area,
                area_sqm,
                unit_price_psm,
                nett_price,
                property_type,
                number_of_units,
                tenure,
                completion_date,
                purchaser_address_indicator,
                postal_code,
                postal_district,
                postal_sector,
                planning_region,
                planning_area
            ))
        ) AS transaction_row_number
    FROM {{ ref('stg_property_transactions') }}
),
transactions AS (
    SELECT
        *,
        CASE WHEN transacted_price > 0 THEN transacted_price END AS valid_transacted_price,
        CASE WHEN nett_price > 0 THEN nett_price END AS valid_nett_price,
        CASE WHEN area_sqft > 0 THEN area_sqft END AS valid_area_sqft,
        CASE WHEN area_sqm > 0 THEN area_sqm END AS valid_area_sqm,
        CASE WHEN unit_price_psf > 0 THEN unit_price_psf END AS valid_unit_price_psf,
        CASE WHEN unit_price_psm > 0 THEN unit_price_psm END AS valid_unit_price_psm,
        CASE WHEN number_of_units > 0 THEN number_of_units END AS valid_number_of_units
    FROM source_transactions
)
SELECT
    FARM_FINGERPRINT(CONCAT(
        TO_JSON_STRING(STRUCT(
            t.project_name,
            t.transacted_price,
            t.area_sqft,
            t.unit_price_psf,
            t.sale_date,
            t.address,
            t.type_of_sale,
            t.type_of_area,
            t.area_sqm,
            t.unit_price_psm,
            t.nett_price,
            t.property_type,
            t.number_of_units,
            t.tenure,
            t.completion_date,
            t.purchaser_address_indicator,
            t.postal_code,
            t.postal_district,
            t.postal_sector,
            t.planning_region,
            t.planning_area
        )),
        '#',
        CAST(transaction_row_number AS STRING)
    )) AS transaction_key,
    p.project_key,
    l.location_key,
    t.sale_date,
    t.valid_transacted_price AS transacted_price,
    t.valid_nett_price AS nett_price,
    t.valid_area_sqft AS area_sqft,
    t.valid_area_sqm AS area_sqm,
    t.valid_unit_price_psf AS unit_price_psf,
    CAST(t.valid_area_sqft * t.valid_unit_price_psf AS INT64) AS new_trans_price,
    CAST(((t.valid_area_sqft * t.valid_unit_price_psf) - t.valid_transacted_price) AS INT64)/NULLIF(t.valid_transacted_price, 0) AS percentage_difference,
    t.valid_unit_price_psm AS unit_price_psm,
    t.valid_number_of_units AS number_of_units,
    t.type_of_sale,
    t.type_of_area,
    t.purchaser_address_indicator
FROM transactions AS t
LEFT JOIN {{ ref('dim_project') }} AS p
    ON t.project_name = p.project_name
    AND t.property_type IS NOT DISTINCT FROM p.property_type
    AND t.tenure IS NOT DISTINCT FROM p.tenure
    AND t.completion_year IS NOT DISTINCT FROM p.completion_year
    AND t.completion_status IS NOT DISTINCT FROM p.completion_status
LEFT JOIN {{ ref('dim_location') }} AS l
    ON t.address IS NOT DISTINCT FROM l.address
    AND t.postal_code IS NOT DISTINCT FROM l.postal_code
    AND t.postal_district IS NOT DISTINCT FROM l.postal_district
    AND t.postal_sector IS NOT DISTINCT FROM l.postal_sector
    AND t.planning_region IS NOT DISTINCT FROM l.planning_region
    AND t.planning_area IS NOT DISTINCT FROM l.planning_area
