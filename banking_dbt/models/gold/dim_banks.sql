WITH source AS (
    SELECT * FROM {{ source('bronze', 'banks') }}
),

deduplicated AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY bank_id
            ORDER BY ingested_at DESC
        ) AS row_num
    FROM source
),

final AS (
    SELECT
        bank_id,
        bank_name,
        country,
        swift_code
    FROM deduplicated
    WHERE row_num = 1
      AND cdc_op != 'd'
)

SELECT * FROM final