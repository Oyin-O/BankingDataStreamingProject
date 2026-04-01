{{ config(
    materialized='incremental',
    unique_key='account_id'
) }}

WITH source AS (
    SELECT * FROM {{ source('bronze', 'accounts') }}

    {% if is_incremental() %}
    WHERE ingested_at > (SELECT MAX(ingested_at) FROM {{ this }})
    {% endif %}
),

deduplicated AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY account_id
            ORDER BY ingested_at DESC
        ) AS row_num
    FROM source
),

final AS (
    SELECT
        account_id,
        customer_id,
        bank_id,
        account_type,
        balance,
        currency,
        account_status,
        TO_TIMESTAMP(opened_at / 1000)      AS account_opened_at,
        TO_TIMESTAMP(updated_at / 1000)     AS account_updated_at,
        cdc_op,
        ingested_at,
        ingestion_date
    FROM deduplicated
    WHERE row_num = 1
      AND cdc_op != 'd'
)

SELECT * FROM final