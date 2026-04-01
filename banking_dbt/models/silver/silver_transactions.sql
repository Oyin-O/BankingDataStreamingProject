{{ config(
    materialized='incremental',
    unique_key='transaction_id'
) }}

WITH source AS (
    SELECT * FROM {{ source('bronze', 'transactions') }}

    {% if is_incremental() %}
    WHERE ingested_at > (SELECT MAX(ingested_at) FROM {{ this }})
    {% endif %}
),

deduplicated AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY transaction_id
            ORDER BY ingested_at DESC
        ) AS row_num
    FROM source
),

final AS (
    SELECT
        transaction_id,
        account_id,
        type                                        AS transaction_type,
        amount,
        currency,
        exchange_rate,
        amount_in_usd,
        status,
        channel,
        country,
        city,
        description,
        cdc_op,
        TO_TIMESTAMP(created_at / 1000)             AS transaction_created_at,
        TO_TIMESTAMP(updated_at / 1000)             AS transaction_updated_at,
        ingested_at,
        ingestion_date
    FROM deduplicated
    WHERE row_num = 1
      AND cdc_op != 'd'
)

SELECT * FROM final