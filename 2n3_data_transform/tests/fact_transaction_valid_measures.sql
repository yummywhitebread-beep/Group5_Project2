SELECT *
FROM {{ ref('fact_transaction') }}
WHERE transacted_price <= 0
   OR nett_price <= 0
   OR area_sqft <= 0
   OR area_sqm <= 0
   OR unit_price_psf <= 0
   OR unit_price_psm <= 0
   OR number_of_units <= 0
