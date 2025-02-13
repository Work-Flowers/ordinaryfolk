SELECT
	ch.region,
	bt.type,
	CASE 
		WHEN ii.subscription_id IS NULL THEN 'One-Time'
		ELSE 'Subscription'
		END AS purchase_type,
	ch.customer_id,
	ch.id AS charge_id,
	ch.created AS purchase_date,
	ch.amount / fx.fx_to_usd / 100 AS total_charge_amount_usd,
	COALESCE(ch.amount_refunded / ch.amount, 0) AS refund_rate,
	prod.id AS product_id,
	prod.name AS product_name,
	JSON_EXTRACT_SCALAR(prod.metadata, '$.condition') AS condition,
	COALESCE(ii.quantity, 1) AS quantity,
	px.unit_amount / fx.fx_to_usd / 100 AS line_item_amount_usd,
	pc.cogs / fx.fx_to_usd AS cogs,
	pc.cashback,
	pc.gst_vat,
	COALESCE(bt.fee / bt.amount, 0) AS fee_rate
FROM all_stripe.charge AS ch
INNER JOIN all_stripe.payment_intent AS pi
	ON ch.payment_intent_id = pi.id
INNER JOIN all_stripe.balance_transaction AS bt
	ON ch.balance_transaction_id = bt.id
INNER JOIN ref.fx_rates AS fx
	ON ch.currency = fx.currency
LEFT JOIN all_stripe.invoice_line_item AS ii
	ON ch.invoice_id = ii.invoice_id
LEFT JOIN all_stripe.price AS px
-- use price_id from invoice line item if available; otherwise look for price_id in payment_intent metadata
	ON COALESCE(ii.price_id, JSON_EXTRACT(pi.metadata, '$.paymentIntentPriceId'), JSON_EXTRACT(pi.metadata, '$.stripePriceIds')) = px.id
LEFT JOIN all_stripe.product AS prod
	ON px.product_id = prod.id
LEFT JOIN google_sheets.product_cogs AS pc
	ON px.id = pc.price_id
WHERE
	ch.status = 'succeeded'
ORDER BY ii.quantity desc