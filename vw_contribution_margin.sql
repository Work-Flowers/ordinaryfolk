DROP VIEW IF EXISTS finance_metrics.contribution_margin; 
CREATE VIEW finance_metrics.contribution_margin AS

WITH stripe_data AS(
	SELECT
		'Stripe' AS sales_channel,
		ch.region,
		bt.type,
		CASE 
			WHEN ii.subscription_id IS NULL THEN 'One-Time'
			ELSE 'Subscription'
			END AS purchase_type,
		ch.customer_id,
-- 		ch.id AS charge_id,
		DATE(ch.created) AS purchase_date,
		ch.amount / fx.fx_to_usd / COALESCE(sub.subunits, 100) AS total_charge_amount_usd,
		COALESCE(ch.amount_refunded / ch.amount, 0) AS refund_rate,
		prod.id AS product_id,
		prod.name AS product_name,
		px.id AS price_id,
		JSON_EXTRACT_SCALAR(prod.metadata, '$.condition') AS condition,
		COALESCE(ii.quantity, 1) AS quantity,
		ch.amount / COALESCE(inv.subtotal, ch.amount) * px.unit_amount / fx.fx_to_usd / COALESCE(sub.subunits, 100) AS line_item_amount_usd,
		pc.cogs / fx.fx_to_usd AS cogs,
		pc.cashback,
		pc.gst_vat,
		COALESCE(bt.fee / bt.amount, 0) AS fee_rate,
		pc.packaging / fx.fx_to_usd AS packaging
	FROM all_stripe.charge AS ch
	INNER JOIN all_stripe.payment_intent AS pi
		ON ch.payment_intent_id = pi.id
	INNER JOIN all_stripe.balance_transaction AS bt
		ON ch.balance_transaction_id = bt.id
	INNER JOIN ref.fx_rates AS fx
		ON ch.currency = fx.currency
	LEFT JOIN ref.stripe_currency_subunits AS sub
		ON fx.currency = sub.currency
	LEFT JOIN all_stripe.invoice AS inv
		ON ch.invoice_id = inv.id
	LEFT JOIN all_stripe.invoice_line_item AS ii
		ON ch.invoice_id = ii.invoice_id
	LEFT JOIN all_stripe.price AS px
	-- use price_id from invoice line item if available; otherwise look for price_id in payment_intent metadata
		ON COALESCE(ii.price_id, JSON_EXTRACT_SCALAR(pi.metadata, '$.paymentIntentPriceId'), JSON_EXTRACT_SCALAR(pi.metadata, '$.stripePriceIds')) = px.id
	LEFT JOIN all_stripe.product AS prod
		ON px.product_id = prod.id
	LEFT JOIN google_sheets.stripe_cogs AS pc
		ON px.id = pc.price_id
	WHERE
		ch.status = 'succeeded'
),

tiktok_data AS(

	SELECT	
		'TikTok' AS sales_channel,
		'sg' AS region,
		CAST(NULL AS STRING) AS type,
		'One-Time' AS purchase_type,
		tik.buyer_username AS customer_id,
-- 		CAST(tik.order_id AS STRING) AS charge_id,
		tik.created_time AS purchase_date,
		0 AS total_charge_amount_usd,
		COALESCE(tik.order_refund_amount, 0) / tik.revenue AS refund_rate,
		CAST(tik.sku_id AS STRING) AS product_id,
		tok.product_name,
		CAST(NULL AS STRING) AS price_id,
		CAST(NULL AS STRING) AS condition,
		tik.quantity,
		tik.revenue / fx.fx_to_usd AS line_item_amount_usd,
		tik.quantity * tok.cogs / fx.fx_to_usd AS cogs,
		0 AS cashback,
		0 AS gst_vat,
		-- fees entered as a negative number in TikTok Orders google sheet (https://docs.google.com/spreadsheets/d/1_XWOXag-iUo8BHjDh7-5pgwhv3rcFU1xG62TCRIIO6A/edit?gid=571245014#gid=571245014)
		-COALESCE(tik.payment_gateway_fee / tik.revenue, 0) AS fee_rate,
		tok.packaging / fx.fx_to_usd AS packaging,
	FROM google_sheets.tiktok_orders AS tik
	LEFT JOIN google_sheets.tiktok_cogs AS tok
		ON tik.sku_id = tok.sku_id
	LEFT JOIN ref.fx_rates AS fx
		ON LOWER(tik.currency) = LOWER(fx.currency)
	WHERE
		tik.revenue > 0
),

lazada_data AS (
	SELECT
		o.transaction_date AS purchase_date,
		lc.product_name,
		o.seller_sku,
		lc.cogs / fx.fx_to_usd AS cogs,
		lc.packaging / fx.fx_to_usd AS packaging,
		SUM(CASE WHEN o.transaction_type = 'Orders-Sales' THEN o.amount / fx.fx_to_usd ELSE 0 END) AS line_item_amount_usd,
		SUM(CASE WHEN o.transaction_type LIKE 'Refunds%' THEN -o.amount / fx.fx_to_usd ELSE 0 END) AS refunds,
		SUM(
			CASE 
				WHEN o.transaction_type IN (
					'Orders-Lazada Fees',
					'Orders-Logistics,'
					'Orders-Marketing Fees',
					'Other Services-Marketing Fees'
				) THEN -o.amount / fx.fx_to_usd ELSE 0 END
		) AS fees
		
	FROM google_sheets.lazada_orders AS o
	LEFT JOIN ref.fx_rates AS fx
		ON LOWER(o.currency) = fx.currency
	LEFT JOIN google_sheets.lazada_cogs AS lc
		ON o.seller_sku = lc.seller_sku
	GROUP BY 1,2,3,4,5
),

shopee_data AS (
	SELECT
		'Shopee' AS sales_channel,
		'sg' AS region,
		CAST(NULL AS STRING) AS type,
		'One-Time' AS purchase_type,
		so.username_buyer_ AS customer_id,
		DATE(so.payout_completed_date) AS purchase_date,
		0 AS total_charge_amount_usd,
		so.refund_amount / GREATEST(so.product_price, 1) AS refund_rate,
		CAST(so.product_id AS STRING) AS product_id,
		so.product_name,
		CAST(NULL AS STRING) AS price_id,
		sc.condition,
		COALESCE(q.quantity, 1) AS quantity,
		so.product_price / fx.fx_to_usd AS line_item_amount_usd,
		sc.cogs / fx.fx_to_usd AS cogs,
		0 AS cashback,
		sc.gst_vat,
		-(so.commission_fee_incl_gst_ + so.ps_finance_pdf_income_service_fee_for_sg + so.transaction_fee_incl_gst_ + so.ams_commission_fee) / GREATEST(so.product_price, 1) AS fee_rate,
		sc.packaging / fx.fx_to_usd AS packaging
	FROM google_sheets.shopee_orders AS so
	LEFT JOIN ref.fx_rates AS fx
		ON LOWER(so.currency) = fx.currency
	LEFT JOIN google_sheets.shopee_order_quantities AS q
		ON so.order_id = q.order_id
	LEFT JOIN google_sheets.shopee_cogs AS sc
		ON so.product_id = sc.product_id
		AND q.sku_reference_no_ = sc.sku_reference_no_
),

sg_cod_data AS (
	SELECT
		'SG COD' AS sales_channel,
		'sg' AS region,
		CAST(NULL AS STRING) AS type,
		'One-Time' AS purchase_type,
		o.email AS customer_id,
		o.date AS purchase_date,
		o.purchase_amount / fx.fx_to_usd AS total_charge_amount_usd,
		0 AS refund_rate,
		o.email AS product_id,
		prod.name AS product_name,
		CAST(NULL AS STRING) AS price_id,
		JSON_EXTRACT_SCALAR(prod.metadata, '$.condition') AS condition,
		o.quantity,
		o.purchase_amount / fx.fx_to_usd AS line_item_amount_usd,
		c.cogs / fx.fx_to_usd AS cogs,
		c.cashback,
		c.gst_vat,
		0 AS fee_rate,
		c.packaging / fx.fx_to_usd AS packaging
	FROM finance_metrics.cod_sg_orders_all AS o
	LEFT JOIN ref.fx_rates AS fx
		ON o.currency = fx.currency
	LEFT JOIN google_sheets.cod_sg_cogs AS c
		ON o.product_id = c.product_id
	LEFT JOIN all_stripe.product AS prod
		ON o.product_id = prod.id
)


SELECT * FROM stripe_data

UNION ALL

SELECT * FROM tiktok_data

UNION ALL

SELECT * FROM shopee_data

UNION ALL

SELECT * FROM sg_cod_data

UNION ALL

SELECT
	'Lazada' AS sales_channel,
	'sg' AS region,
	CAST(NULL AS STRING) AS type,
	'One-Time' AS purchase_type,
	CAST(NULL AS STRING) AS customer_id,
	purchase_date,
	0 AS total_charge_amount_usd,
	refunds / line_item_amount_usd AS refund_rate,
	seller_sku AS product_id,
	product_name,
	CAST(NULL AS STRING) AS price_id,
	CAST(NULL AS STRING) AS condition,
	0 AS quantity,
	line_item_amount_usd,
	cogs,
	0 AS cashback,
	0 AS gst_vat,
	fees / line_item_amount_usd AS fee_rate,
	packaging
FROM lazada_data
WHERE line_item_amount_usd > 0