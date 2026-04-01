{{ config(
    materialized='incremental',
    unique_key='customer_id'
) }}

WITH source AS (
    SELECT * FROM {{ source('bronze', 'customers') }}

    {% if is_incremental() %}
    WHERE ingested_at > (SELECT MAX(ingested_at) FROM {{ this }})
    {% endif %}
),

deduplicated AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY ingested_at DESC
        ) AS row_num
    FROM source
),

final AS (
    SELECT
        customer_id,
        full_name,
        email,
        phone,
        nationality,
        TO_TIMESTAMP(created_at / 1000)     AS customer_created_at,
        TO_TIMESTAMP(updated_at / 1000)     AS customer_updated_at,
        cdc_op,
        ingested_at,
        ingestion_date
    FROM deduplicated
    WHERE row_num = 1
      AND cdc_op != 'd'
)

SELECT * FROM final