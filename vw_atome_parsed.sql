DROP VIEW IF EXISTS all_postgres.atome_parsed;
CREATE VIEW all_postgres.atome_parsed AS 

SELECT
	-- original columns
	ap.*,
	
    -- Top-level fields
    JSON_VALUE(webhook_payload, '$.currency') AS currency,
    JSON_VALUE(webhook_payload, '$.redirectUrl') AS redirectUrl,
    JSON_VALUE(webhook_payload, '$.referenceId') AS referenceId,
    CAST(JSON_VALUE(webhook_payload, '$.refundableAmount') AS INT64) AS refundableAmount,
    JSON_VALUE(webhook_payload, '$.merchantReferenceId') AS merchantReferenceId,

    -- Extracting nested fields from paymentTransaction
    CAST(JSON_VALUE(webhook_payload, '$.paymentTransaction.tenor') AS INT64) AS payment_tenor,
    JSON_VALUE(webhook_payload, '$.paymentTransaction.orderId') AS orderId,
    CAST(JSON_VALUE(webhook_payload, '$.paymentTransaction.createAt') AS INT64) AS payment_createAt,
    JSON_VALUE(webhook_payload, '$.paymentTransaction.transactionId') AS payment_transactionId,

    -- Extracting other JSON fields from summary as before
    CAST(JSON_VALUE(summary, '$.total') AS INT64) AS total,
    CAST(JSON_VALUE(summary, '$.mainTax') AS INT64) AS mainTax,
    CAST(JSON_VALUE(summary, '$.subTotal') AS INT64) AS subTotal,
    CAST(JSON_VALUE(summary, '$.consultFee') AS INT64) AS consultFee,
    CAST(JSON_VALUE(summary, '$.consultTax') AS INT64) AS consultTax,
    CAST(JSON_VALUE(summary, '$.mainBasePrice') AS INT64) AS mainBasePrice,
    CAST(JSON_VALUE(summary, '$.cashbackEarned') AS INT64) AS cashbackEarned,
    CAST(JSON_VALUE(summary, '$.discountAmount') AS INT64) AS discountAmount,
    CAST(JSON_VALUE(summary, '$.cashbackRedeemed') AS INT64) AS cashbackRedeemed,
    CAST(JSON_VALUE(summary, '$.consultBasePrice') AS INT64) AS consultBasePrice,
    CAST(JSON_VALUE(summary, '$.productPriceAmount') AS INT64) AS productPriceAmount,
    CAST(JSON_VALUE(summary, '$.totalAfterCashback') AS INT64) AS totalAfterCashback,
    CAST(JSON_VALUE(summary, '$.paymentIntentAmount') AS INT64) AS paymentIntentAmount,
    CAST(JSON_VALUE(summary, '$.minimalAmountPayment') AS INT64) AS minimalAmountPayment,
    CAST(JSON_VALUE(summary, '$.paymentIntentAmountAfterCashback') AS INT64) AS paymentIntentAmountAfterCashback,

    -- FLOAT values
    CAST(JSON_VALUE(summary, '$.cashbackEarnRate') AS FLOAT64) AS cashbackEarnRate,

    -- Boolean values
    CAST(JSON_VALUE(summary, '$.isConsult') AS BOOL) AS isConsult,
    CAST(JSON_VALUE(summary, '$.shouldChargeConsultFee') AS BOOL) AS shouldChargeConsultFee,

    -- String values
    JSON_VALUE(summary, '$.priceId') AS priceId,
    JSON_VALUE(summary, '$.paymentIntentSummary.Teleconsultation') AS paymentIntent_Teleconsultation,
    JSON_VALUE(summary, '$.paymentIntentSummary.paymentIntentPriceId') AS paymentIntent_PriceId

FROM sg_postgres_rds_public.atome_payments AS ap