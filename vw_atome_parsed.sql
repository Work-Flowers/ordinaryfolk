DROP VIEW IF EXISTS all_postgres.atome_parsed;
CREATE VIEW all_postgres.atome_parsed AS 

SELECT
    -- Original columns
    o.short_id AS external_platform_id,
    DATE(ap.created_at) AS created_at,
    DATE(ap.updated_at) AS updated_at,
    ap.sys_id,
    ap.ordersysid,
    ap.patientsysid,
    ap.status AS atome_status,
    o.status AS order_status,
    ap.amount,

    -- Top-level fields
    CAST(JSON_VALUE(webhook_payload, '$.refundableAmount') AS INT64) AS refundableAmount,
    JSON_VALUE(webhook_payload, '$.merchantReferenceId') AS merchantReferenceId,

    -- Extracting nested fields from paymentTransaction
    CAST(JSON_VALUE(webhook_payload, '$.paymentTransaction.tenor') AS INT64) AS payment_tenor,
    JSON_VALUE(webhook_payload, '$.paymentTransaction.orderId') AS orderId,
    CAST(JSON_VALUE(webhook_payload, '$.paymentTransaction.createAt') AS INT64) AS payment_createAt,
    JSON_VALUE(webhook_payload, '$.paymentTransaction.transactionId') AS payment_transactionId,

    -- Extracting ALL fields from prescription_order_calculation (handling object and array cases)
    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.total'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.total')
        ) AS INT64
    ) AS total,

    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.mainTax'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.mainTax')
        ) AS INT64
    ) AS mainTax,

    JSON_VALUE(
        COALESCE(
            o.prescription_order_calculation,
            JSON_QUERY(o.prescription_order_calculation, '$[0]')
        ), 
        '$.priceId'
    ) AS price_id,

    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.subTotal'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.subTotal')
        ) AS INT64
    ) AS subTotal,

    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.isConsult'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.isConsult')
        ) AS BOOL
    ) AS isConsult,

    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.consultFee'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.consultFee')
        ) AS INT64
    ) AS consultFee,

    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.consultTax'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.consultTax')
        ) AS INT64
    ) AS consultTax,

    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.mainBasePrice'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.mainBasePrice')
        ) AS INT64
    ) AS mainBasePrice,

    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.cashbackEarned'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.cashbackEarned')
        ) AS INT64
    ) AS cashbackEarned,

    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.discountAmount'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.discountAmount')
        ) AS INT64
    ) AS discountAmount,

    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.cashbackEarnRate'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.cashbackEarnRate')
        ) AS FLOAT64
    ) AS cashbackEarnRate,

    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.cashbackRedeemed'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.cashbackRedeemed')
        ) AS INT64
    ) AS cashbackRedeemed,

    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.consultBasePrice'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.consultBasePrice')
        ) AS INT64
    ) AS consultBasePrice,

    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.productPriceAmount'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.productPriceAmount')
        ) AS INT64
    ) AS productPriceAmount,

    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.totalAfterCashback'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.totalAfterCashback')
        ) AS INT64
    ) AS totalAfterCashback,

    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.paymentIntentAmount'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.paymentIntentAmount')
        ) AS INT64
    ) AS paymentIntentAmount,

    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.minimalAmountPayment'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.minimalAmountPayment')
        ) AS INT64
    ) AS minimalAmountPayment,

    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.paymentIntentAmountAfterCashback'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.paymentIntentAmountAfterCashback')
        ) AS INT64
    ) AS paymentIntentAmountAfterCashback,

    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.shouldChargeConsultFee'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.shouldChargeConsultFee')
        ) AS BOOL
    ) AS shouldChargeConsultFee,

    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.consultFeeAfterDiscount'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.consultFeeAfterDiscount')
        ) AS INT64
    ) AS consultFeeAfterDiscount,

    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.productPriceAmountAfterDiscount'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.productPriceAmountAfterDiscount')
        ) AS INT64
    ) AS productPriceAmountAfterDiscount,

    ap.webhook_payload,
    o.prescription_order_calculation

FROM sg_postgres_rds_public.atome_payments AS ap
LEFT JOIN all_postgres.order AS o
    ON ap.ordersysid = o.sys_id
-- QUALIFY ROW_NUMBER() OVER (PARTITION BY ap.ordersysid ORDER BY ap.updated_at DESC) = 1;