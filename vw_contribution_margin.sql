DROP VIEW IF EXISTS finance_metrics.contribution_margin; 
CREATE VIEW finance_metrics.contribution_margin AS

WITH sub_starts AS (
	SELECT DISTINCT
		id AS subscription_id,
		DATE(created) AS create_date
	FROM all_stripe.subscription_history
),

stripe_data AS (
	SELECT
		'Stripe' AS sales_channel,
		ch.region,
		bt.type,
		CASE 
			WHEN ii.subscription_id IS NULL THEN 'One-Time'
			ELSE 'Subscription'
			END AS purchase_type,
		COALESCE(inv.billing_reason, 'manual') AS billing_reason,
		ch.customer_id,
		cust.email,
		ch.id AS charge_id,
		ch.payment_intent_id,
		inv.subscription_id,
		DATE(ch.created) AS purchase_date,
		ch.amount / fx.fx_to_usd / COALESCE(sub.subunits, 100) AS total_charge_amount_usd,
		COALESCE(ch.amount_refunded / ch.amount, 0) AS refund_rate,
		prod.id AS product_id,
		prod.name AS product_name,
		px.id AS price_id,
		JSON_EXTRACT_SCALAR(prod.metadata, '$.condition') AS condition,
		COALESCE(ii.quantity, 1) AS quantity,
		ch.currency,
		ch.amount / (
			CASE 
				WHEN inv.subtotal > 0 THEN inv.subtotal
				ELSE ch.amount
				END
			) * ii.amount / fx.fx_to_usd / COALESCE(sub.subunits, 100) AS line_item_amount_usd,
		pc.cogs / fx.fx_to_usd AS cogs,
		pc.cashback,
		pc.gst_vat,
		COALESCE(bt.fee / bt.amount, 0) AS fee_rate,
		pc.packaging / fx.fx_to_usd AS packaging,
		MIN(DATE(ch.created)) OVER(PARTITION BY ch.customer_id) AS acquisition_date
	FROM all_stripe.charge AS ch
	LEFT JOIN all_stripe.customer AS cust
		ON ch.customer_id = cust.id
	INNER JOIN all_stripe.payment_intent AS pi
		ON ch.payment_intent_id = pi.id
	LEFT JOIN all_postgres.order AS o
		ON ch.payment_intent_id = o.stripe_payment_intent_id
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
	LEFT JOIN all_stripe.product_cost AS pc
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
		'manual' AS billing_reason,
		tik.buyer_username AS customer_id,
		CAST(NULL AS STRING) AS email,
		CAST(tik.order_id AS STRING) AS charge_id,
		CAST(NULL AS STRING) AS payment_intent_id,
		CAST(NULL AS STRING) AS subscription_id,
		tik.created_time AS purchase_date,
		0 AS total_charge_amount_usd,
		COALESCE(tik.order_refund_amount, 0) / tik.revenue AS refund_rate,
		CAST(tik.sku_id AS STRING) AS product_id,
		tok.product_name,
		CAST(NULL AS STRING) AS price_id,
		CAST(NULL AS STRING) AS condition,
		tik.quantity,
		LOWER(tik.currency) AS currency,
		tik.revenue / fx.fx_to_usd AS line_item_amount_usd,
		tik.quantity * tok.cogs / fx.fx_to_usd AS cogs,
		0 AS cashback,
		0 AS gst_vat,
		-- fees entered as a negative number in TikTok Orders google sheet (https://docs.google.com/spreadsheets/d/1_XWOXag-iUo8BHjDh7-5pgwhv3rcFU1xG62TCRIIO6A/edit?gid=571245014#gid=571245014)
		-COALESCE(tik.payment_gateway_fee / tik.revenue, 0) AS fee_rate,
		tok.packaging / fx.fx_to_usd AS packaging,
		MIN(DATE(tik.created_time)) OVER(PARTITION BY tik.buyer_username) AS acquisition_date
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
		LOWER(o.currency) AS currency,
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
	GROUP BY 1,2,3,4,5,6
),

shopee_data AS (
	SELECT
		'Shopee' AS sales_channel,
		'sg' AS region,
		CAST(NULL AS STRING) AS type,
		COALESCE(cttp.purchase_type, 'One-Time') AS purchase_type,
		COALESCE(cttp.billing_reason, 'manual') AS billing_reason,
		so.username_buyer_ AS customer_id,
		CAST(NULL AS STRING) AS email,
		CAST(NULL AS STRING) AS charge_id,
		CAST(NULL AS STRING) AS payment_intent_id,
		CAST(NULL AS STRING) AS subscription_id,
		DATE(so.payout_completed_date) AS purchase_date,
		0 AS total_charge_amount_usd,
		so.refund_amount / GREATEST(so.product_price, 1) AS refund_rate,
		CAST(so.product_id AS STRING) AS product_id,
		so.product_name,
		CAST(NULL AS STRING) AS price_id,
		sc.condition,
		COALESCE(q.quantity, 1) AS quantity,
		LOWER(so.currency) AS currency,
		so.product_price / fx.fx_to_usd AS line_item_amount_usd,
		sc.cogs / fx.fx_to_usd AS cogs,
		0 AS cashback,
		sc.gst_vat,
		-(so.commission_fee_incl_gst_ + so.ps_finance_pdf_income_service_fee_for_sg + so.transaction_fee_incl_gst_ + so.ams_commission_fee) / GREATEST(so.product_price, 1) AS fee_rate,
		sc.packaging / fx.fx_to_usd AS packaging,
		MIN(DATE(so.payout_completed_date)) OVER(PARTITION BY so.username_buyer_) AS acquisition_date
	FROM google_sheets.shopee_orders AS so
	LEFT JOIN ref.fx_rates AS fx
		ON LOWER(so.currency) = fx.currency
	LEFT JOIN google_sheets.shopee_order_quantities AS q
		ON so.order_id = q.order_id
	LEFT JOIN google_sheets.shopee_cogs AS sc
		ON so.product_id = sc.product_id
		AND q.sku_reference_no_ = sc.sku_reference_no_
	LEFT JOIN google_sheets.condition_transaction_type_map AS cttp
		ON sc.condition = cttp.condition
),

sg_cod_data AS (
	SELECT
		'SG COD' AS sales_channel,
		'sg' AS region,
		CAST(NULL AS STRING) AS type,
		COALESCE(cttp.purchase_type, 'One-Time') AS purchase_type,
		COALESCE(cttp.billing_reason, 'manual') AS billing_reason,
		o.email AS customer_id,
		CAST(NULL AS STRING) AS charge_id,
		o.email,
		CAST(NULL AS STRING) AS payment_intent_id,
		CAST(NULL AS STRING) AS subscription_id,
		o.date AS purchase_date,
		o.purchase_amount / fx.fx_to_usd AS total_charge_amount_usd,
		0 AS refund_rate,
		o.email AS product_id,
		prod.name AS product_name,
		CAST(NULL AS STRING) AS price_id,
		JSON_EXTRACT_SCALAR(prod.metadata, '$.condition') AS condition,
		o.quantity,
		o.currency,
		o.purchase_amount / fx.fx_to_usd AS line_item_amount_usd,
		c.cost_box / fx.fx_to_usd AS cogs,
		.02 AS cashback,
		.09 AS gst_vat,
		0 AS fee_rate,
		c.packaging_cost / fx.fx_to_usd AS packaging,
		MIN(o.date) OVER(PARTITION BY o.email) AS acquisition_date
	FROM finance_metrics.cod_sg_orders_all AS o
	LEFT JOIN ref.fx_rates AS fx
		ON o.currency = fx.currency
	LEFT JOIN google_sheets.sg_product_cost_stripe AS c
		ON o.product_id = c.id
	LEFT JOIN all_stripe.product AS prod
		ON o.product_id = prod.id
	LEFT JOIN google_sheets.condition_transaction_type_map AS cttp
		ON JSON_EXTRACT_SCALAR(prod.metadata, '$.condition') = cttp.condition
),

atome_local AS (
	SELECT
		patientsysid AS customer_id,
		CAST(external_platform_id AS STRING) AS charge_id,
		created_at AS purchase_date,
		'sgd' AS currency,
		JSON_VALUE(prod.metadata, '$.condition') AS condition,
		px.product_id,
		prod.name AS product_name,
		px.id AS price_id,
		atome_status,
		amount / 100 AS amount_local,
		CASE 
			WHEN shouldChargeConsultFee IS TRUE THEN `consultFee` / 100 
			ELSE 0
			END AS consult_fee_local
	FROM all_postgres.atome_parsed AS ap
	LEFT JOIN all_stripe.price AS px
		ON ap.price_id = px.id
	LEFT JOIN all_stripe.product AS prod
		ON px.product_id = prod.id
	WHERE 
		ap.atome_status IN ('paid', 'refunded')	
),

atome_usd AS (
	SELECT
		ar.customer_id,
		ar.charge_id,
		ar.purchase_date,
		ar.currency,
		ar.amount_local / fx.fx_to_usd AS total_charge_amount_usd,
		consult_fee_local / fx.fx_to_usd AS consult_fee_usd,
		CASE WHEN atome_status = 'refunded' THEN amount_local ELSE 0 END / amount_local AS refund_rate,
		ar.product_id,
		ar.product_name,
		ar.price_id,
		ar.condition,
		MIN(ar.purchase_date) OVER (PARTITION BY ar.customer_id) AS acquisition_date
	FROM atome_local AS ar
	LEFT JOIN ref.fx_rates AS fx
		ON ar.currency = fx.currency
),

atome_unioned AS (
	
	SELECT
		customer_id,
		charge_id,
		purchase_date,
		currency,
		total_charge_amount_usd - consult_fee_usd AS total_charge_amount_usd,
		refund_rate,
		product_id,
		product_name,
		price_id,
		condition,
		acquisition_date
	FROM atome_usd
	
	UNION ALL
	
	SELECT
		customer_id,
		charge_id,
		purchase_date,
		currency,
		consult_fee_usd AS total_charge_amount_usd,
		refund_rate,
		'prod_JDp75SMVPAOeGB' AS product_id,
		'Teleconsultation' AS product_name,
		price_id,
		'Services' AS condition,
		acquisition_date
	FROM atome_usd
	WHERE consult_fee_usd > 0
	
), 

atome_final AS (
	SELECT
		'Atome' AS sales_channel,
		'sg' AS region,
		CAST(NULL AS STRING) AS type,
		'One-Time' purchase_type,
		'manual' AS billing_reason,
		a.customer_id,
		CAST(NULL AS STRING) AS email,
		a.charge_id,
		CAST(NULL AS STRING) AS payment_intent_id,
		CAST(NULL AS STRING) AS subscription_id,
		a.purchase_date,
		a.total_charge_amount_usd,
		a.refund_rate,
		a.product_id,
		a.product_name,
		a.price_id,
		a.condition,
		1 AS quantity,
		a.currency,
		a.total_charge_amount_usd AS line_item_amount_usd,
		pc.cogs / fx.fx_to_usd AS cogs,
		pc.cashback,
		t.rate AS gst_vat,
		0 AS fee_rate,
		pc.packaging / fx.fx_to_usd AS packaging,
		a.acquisition_date
	FROM atome_unioned AS a
	LEFT JOIN ref.fx_rates AS fx
		ON a.currency = fx.currency
	LEFT JOIN all_stripe.product_cost AS pc
		ON a.price_id = pc.price_id
	LEFT JOIN ref.tax_rate_history AS t
		ON t.region = 'sg'
		AND a.purchase_date BETWEEN t.from_date AND t.to_date
),

unioned_data AS (
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
		'manual' AS billing_reason,
		CAST(NULL AS STRING) AS customer_id,
		CAST(NULL AS STRING) AS email,
		CAST(NULL AS STRING) AS charge_id,
		CAST(NULL AS STRING) AS payment_intent_id,
		CAST(NULL AS STRING) AS subscription_id,
		purchase_date,
		0 AS total_charge_amount_usd,
		refunds / line_item_amount_usd AS refund_rate,
		seller_sku AS product_id,
		product_name,
		CAST(NULL AS STRING) AS price_id,
		CAST(NULL AS STRING) AS condition,
		0 AS quantity,
		currency,
		line_item_amount_usd,
		cogs,
		0 AS cashback,
		0 AS gst_vat,
		fees / line_item_amount_usd AS fee_rate,
		packaging,
		CAST(NULL AS DATE) AS acquisition_date
	FROM lazada_data
	WHERE line_item_amount_usd > 0
	
	UNION ALL
	
	SELECT * FROM atome_final
)

SELECT
	unioned_data.*,
	CASE 
		WHEN purchase_date <= DATE_ADD(acquisition_date, INTERVAL 7 DAY) THEN 'New'
		WHEN acquisition_date IS NOT NULL THEN 'Existing'
		END AS new_existing,
	sub_starts.create_date AS subscription_created_date
FROM unioned_data
LEFT JOIN sub_starts
	ON unioned_data.subscription_id = sub_starts.subscription_id