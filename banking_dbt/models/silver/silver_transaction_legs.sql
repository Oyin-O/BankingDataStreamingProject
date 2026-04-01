{{ config(
    materialized='incremental',
    unique_key='leg_id'
) }}

WITH source AS (
    SELECT * FROM {{ source('bronze', 'transaction_legs') }}

    {% if is_incremental() %}
    WHERE ingested_at > (SELECT MAX(ingested_at) FROM {{ this }})
    {% endif %}
),

deduplicated AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY leg_id
            ORDER BY ingested_at DESC
        ) AS row_num
    FROM source
),

final AS (
    SELECT
        leg_id,
        transaction_id,
        direction,
        account_id,
        bank_id,
        external_account_reference,
        external_account_name,
        amount,
        currency,
        cdc_op,
        ingested_at,
        ingestion_date
    FROM deduplicated
    WHERE row_num = 1
      AND cdc_op != 'd'
)

SELECT * FROM final