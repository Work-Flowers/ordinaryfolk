SELECT
    -- Original columns
    o.short_id,
    o.sys_id,
    DATE(o.created_at) AS created_date,
    o.status,
    o.phone_number, 
	COALESCE(o.prescription_price_id, o.price_id) AS price_id,
	px.product_id,
	prod.name AS product_name,

    -- Top-level fields
    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.total'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.total')
        ) AS INT64
    ) AS total_amount,

    CAST(
        COALESCE(
            JSON_VALUE(o.prescription_order_calculation, '$.mainTax'),
            JSON_VALUE(JSON_QUERY(o.prescription_order_calculation, '$[0]'), '$.mainTax')
        ) AS INT64
    ) AS mainTax,

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

    o.prescription_order_calculation

FROM all_postgres.order AS o
LEFT JOIN all_stripe.price AS px
	ON COALESCE(o.prescription_price_id, o.price_id) = px.id
LEFT JOIN all_stripe.product AS prod
	ON px.product_id = prod.id
WHERE
	1 = 1
	AND o.payment_provider = 'cod'
	AND o.region = 'hk'
	AND DATE_TRUNC(DATE(o.created_at), MONTH) = '2025-02-01' 