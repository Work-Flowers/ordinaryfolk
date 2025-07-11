DROP VIEW IF EXISTS finance_metrics.contribution_margin; 
CREATE VIEW finance_metrics.contribution_margin AS

WITH sub_starts AS (
	SELECT DISTINCT
		id AS subscription_id,
		DATE(created) AS create_date
	FROM all_stripe.subscription_history
),


patient_brand_stripe_ids AS (
	SELECT DISTINCT
		stripe_customer_id,
		from_platform_env AS brand
	FROM all_postgres.patient
),

tel_price AS (

		SELECT
			px.id AS price_id,
			px.product_id,
			pr.name AS product_name,
			COALESCE(JSON_VALUE(pr.metadata, '$.condition'), 'Services') AS condition
		FROM all_stripe.product AS pr
		INNER JOIN all_stripe.price AS px
			ON pr.id = px.product_id
		WHERE LOWER(pr.name) LIKE '%tele%'
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
		pbsi.brand,
		ch.customer_id,
		cust.email,
		ch.id AS charge_id,
		JSON_VALUE(ch.metadata, '$.orderId') AS order_sys_id,
		ch.payment_intent_id,
		inv.subscription_id,
		px.recurring_interval,
		px.recurring_interval_count,
		DATE(ch.created) AS purchase_date,
		ch.amount / fx.fx_to_usd / COALESCE(sub.subunits, 100) AS total_charge_amount_usd,
		COALESCE(ch.amount_refunded / ch.amount, 0) AS refund_rate,
		ch.amount_refunded / fx.fx_to_usd / COALESCE(sub.subunits, 100) AS amount_refunded_usd,
		COALESCE(prod.id, tp.product_id) AS product_id,
		COALESCE(prod.name, tp.product_name) AS product_name,
		COALESCE(px.id, tp.price_id) AS price_id,
		COALESCE(JSON_EXTRACT_SCALAR(prod.metadata, '$.condition'), tp.condition) AS condition,
		COALESCE(ii.quantity, 1) AS quantity,
		ch.currency,
		ch.amount / (
			CASE 
				WHEN inv.subtotal > 0 THEN inv.subtotal
				ELSE ch.amount
				END
			) * ii.amount / fx.fx_to_usd / COALESCE(sub.subunits, 100) AS line_item_amount_usd,
		-- note that all_stripe.product_cost does not include COGS for teleconsults
		-- those are updated manually on a monthly basis in google_sheets.opex
		-- pipeline for finance_metrics.monthly_contribution_margin incorporates teleconsult COGS
		pc.cogs / fx.fx_to_usd AS cogs,
		pc.cashback,
		t.rate AS gst_vat,
		COALESCE(bt.fee / bt.amount, 0) AS fee_rate,
		pc.packaging / fx.fx_to_usd AS packaging,
		MIN(DATE(ch.created)) OVER(PARTITION BY ch.customer_id) AS acquisition_date
	FROM all_stripe.charge AS ch
	LEFT JOIN all_stripe.payment_intent AS pi
		ON ch.payment_intent_id = pi.id
	LEFT JOIN all_stripe.customer AS cust
		ON ch.customer_id = cust.id
	LEFT JOIN patient_brand_stripe_ids AS pbsi
		ON ch.customer_id = pbsi.stripe_customer_id
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
		ON ii.price_id = px.id
	LEFT JOIN all_stripe.product AS prod
		ON px.product_id = prod.id
	LEFT JOIN all_stripe.product_cost AS pc
		ON px.id = pc.price_id
		AND DATE(ch.created) BETWEEN pc.from_date AND pc.to_date
	LEFT JOIN tel_price AS tp
		ON COALESCE(JSON_EXTRACT_SCALAR(pi.metadata, '$.paymentIntentPriceId'), JSON_EXTRACT_SCALAR(pi.metadata, '$.stripePriceIds')) = tp.price_id
	LEFT JOIN ref.tax_rate_history AS t
		ON ch.region = t.region
		AND DATE(ch.created) BETWEEN t.from_date AND t.to_date
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
		'N/A' AS brand,
		tik.buyer_username AS customer_id,
		CAST(NULL AS STRING) AS email,
		CAST(tik.order_id AS STRING) AS charge_id,
		CAST(NULL AS STRING) AS order_sys_id,
		CAST(NULL AS STRING) AS payment_intent_id,
		CAST(NULL AS STRING) AS subscription_id,
		CAST(NULL AS STRING) AS recurring_interval,
		NULL AS recurring_interval_count,
		tik.created_time AS purchase_date,
		0 AS total_charge_amount_usd,
		SAFE_DIVIDE(COALESCE(tik.order_refund_amount, 0), COALESCE(tik.sku_subtotal_after_discount, 1)) AS refund_rate,
		COALESCE(tik.order_refund_amount, 0) / fx.fx_to_usd AS amount_refunded_usd,
		CAST(tik.sku_id AS STRING) AS product_id,
		tok.product_name,
		CAST(NULL AS STRING) AS price_id,
		tok.condition,
		tik.quantity,
		LOWER(tik.currency) AS currency,
		tik.sku_subtotal_after_discount / fx.fx_to_usd AS line_item_amount_usd,
		tik.quantity * tok.cogs / fx.fx_to_usd AS cogs,
		0 AS cashback,
		t.rate AS gst_vat,
		-- fees entered as a negative number in TikTok Orders google sheet (https://docs.google.com/spreadsheets/d/1_XWOXag-iUo8BHjDh7-5pgwhv3rcFU1xG62TCRIIO6A/edit?gid=571245014#gid=571245014)
		-COALESCE(SAFE_DIVIDE(tik.payment_gateway_fee, COALESCE(tik.sku_subtotal_after_discount, 1)), 0) AS fee_rate,
		tok.packaging / fx.fx_to_usd AS packaging,
		MIN(DATE(tik.created_time)) OVER(PARTITION BY tik.buyer_username) AS acquisition_date
	FROM google_sheets.tiktok_orders AS tik
	LEFT JOIN finance_metrics.tiktok_product_costs AS tok
		ON tik.sku_id = tok.sku_id
		AND tik.created_time BETWEEN tok.from_date AND tok.to_date
	LEFT JOIN ref.fx_rates AS fx
		ON LOWER(tik.currency) = LOWER(fx.currency)
	LEFT JOIN ref.tax_rate_history AS t
		ON t.region = 'sg'
		AND tik.created_time BETWEEN t.from_date AND t.to_date
),

lazada_data AS (
	SELECT
		o.transaction_date AS purchase_date,
		lc.product_name,
		o.seller_sku,
		lc.cogs / fx.fx_to_usd AS cogs,
		lc.condition,
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
	LEFT JOIN finance_metrics.lazada_product_costs AS lc
		ON o.seller_sku = lc.seller_sku
		AND o.transaction_date BETWEEN lc.from_date AND lc.to_date
	GROUP BY 1,2,3,4,5,6,7
),

shopee_data AS (
	SELECT
		'Shopee' AS sales_channel,
		'sg' AS region,
		CAST(NULL AS STRING) AS type,
		COALESCE(cttp.purchase_type, 'One-Time') AS purchase_type,
		COALESCE(cttp.billing_reason, 'manual') AS billing_reason,
		'N/A' AS brand,
		so.username_buyer_ AS customer_id,
		CAST(NULL AS STRING) AS email,
		CAST(NULL AS STRING) AS charge_id,
		CAST(NULL AS STRING) AS order_sys_id,
		CAST(NULL AS STRING) AS payment_intent_id,
		CAST(NULL AS STRING) AS subscription_id,
		CAST(NULL AS STRING) AS recurring_interval,
		NULL AS recurring_interval_count,
		DATE(so.payout_completed_date) AS purchase_date,
		0 AS total_charge_amount_usd,
		so.refund_amount / GREATEST(so.product_price, 1) AS refund_rate,
		so.refund_amount / fx.fx_to_usd AS amount_refunded_usd,
		CAST(so.product_id AS STRING) AS product_id,
		so.product_name,
		CAST(NULL AS STRING) AS price_id,
		sc.condition,
		COALESCE(q.quantity, 1) AS quantity,
		LOWER(so.currency) AS currency,
		so.product_price / fx.fx_to_usd AS line_item_amount_usd,
		sc.cogs / fx.fx_to_usd AS cogs,
		0 AS cashback,
		t.rate AS gst_vat,
		-(so.commission_fee_incl_gst_ + so.ps_finance_pdf_income_service_fee_for_sg + so.transaction_fee_incl_gst_ + so.ams_commission_fee) / GREATEST(so.product_price, 1) AS fee_rate,
		sc.packaging / fx.fx_to_usd AS packaging,
		MIN(DATE(so.payout_completed_date)) OVER(PARTITION BY so.username_buyer_) AS acquisition_date
	FROM google_sheets.shopee_orders AS so
	LEFT JOIN ref.fx_rates AS fx
		ON LOWER(so.currency) = fx.currency
	LEFT JOIN google_sheets.shopee_order_quantities AS q
		ON so.order_id = q.order_id
	LEFT JOIN finance_metrics.shopee_product_costs AS sc
		ON so.product_id = sc.product_id
		AND q.sku_reference_no_ = sc.sku_reference_no_
		AND DATE(so.payout_completed_date) BETWEEN sc.from_date AND sc.to_date
	LEFT JOIN google_sheets.condition_transaction_type_map AS cttp
		ON sc.condition = cttp.condition
	LEFT JOIN ref.tax_rate_history AS t
		ON t.region = 'sg'
		AND DATE(so.payout_completed_date) BETWEEN t.from_date AND t.to_date
),

sg_cod_data AS (
	SELECT
		'SG COD' AS sales_channel,
		'sg' AS region,
		CAST(NULL AS STRING) AS type,
		COALESCE(cttp.purchase_type, 'One-Time') AS purchase_type,
		COALESCE(cttp.billing_reason, 'manual') AS billing_reason,
		'N/A' AS brand,
		o.email AS customer_id,
		o.email,
		CAST(NULL AS STRING) AS charge_id,
		CAST(NULL AS STRING) AS order_sys_id,
		CAST(NULL AS STRING) AS payment_intent_id,
		CAST(NULL AS STRING) AS subscription_id,
		CAST(NULL AS STRING) AS recurring_interval,
		NULL AS recurring_interval_count,
		o.date AS purchase_date,
		o.purchase_amount / fx.fx_to_usd AS total_charge_amount_usd,
		0 AS refund_rate,
		0 AS amount_refunded_usd,
		o.email AS product_id,
		prod.name AS product_name,
		CAST(NULL AS STRING) AS price_id,
		JSON_EXTRACT_SCALAR(prod.metadata, '$.condition') AS condition,
		o.quantity,
		o.currency,
		o.purchase_amount / fx.fx_to_usd AS line_item_amount_usd,
		c.cost_box / fx.fx_to_usd AS cogs,
		.02 AS cashback,
		t.rate AS gst_vat,
		0 AS fee_rate,
		c.packaging_cost / fx.fx_to_usd AS packaging,
		MIN(o.date) OVER(PARTITION BY o.email) AS acquisition_date
	FROM finance_metrics.cod_sg_orders_all AS o
	LEFT JOIN ref.fx_rates AS fx
		ON o.currency = fx.currency
	LEFT JOIN all_stripe.product_cost_per_box AS c
		ON o.product_id = c.product_id
		AND o.date BETWEEN c.from_date AND c.to_date
		AND c.region = 'sg'
	LEFT JOIN all_stripe.product AS prod
		ON o.product_id = prod.id
	LEFT JOIN google_sheets.condition_transaction_type_map AS cttp
		ON JSON_EXTRACT_SCALAR(prod.metadata, '$.condition') = cttp.condition
	LEFT JOIN ref.tax_rate_history AS t
		ON t.region = 'sg'
		AND o.date BETWEEN t.from_date AND t.to_date
),

hk_cod_data AS (
	SELECT
		'HK COD' AS sales_channel,
		'hk' AS region,
		CAST(NULL AS STRING) AS type,
		COALESCE(cttp.purchase_type, 'One-Time') AS purchase_type,
		COALESCE(cttp.billing_reason, 'manual') AS billing_reason,
		'N/A' AS brand,
		o.email AS customer_id,
		o.email,
		CAST(NULL AS STRING) AS charge_id,
		CAST(NULL AS STRING) AS order_sys_id,
		CAST(NULL AS STRING) AS payment_intent_id,
		CAST(NULL AS STRING) AS subscription_id,
		CAST(NULL AS STRING) AS recurring_interval,
		NULL AS recurring_interval_count,
		o.date AS purchase_date,
		o.purchase_amount / fx.fx_to_usd AS total_charge_amount_usd,
		0 AS refund_rate,
		0 AS amount_refunded_usd,
		o.email AS product_id,
		prod.name AS product_name,
		CAST(NULL AS STRING) AS price_id,
		JSON_EXTRACT_SCALAR(prod.metadata, '$.condition') AS condition,
		o.quantity,
		o.currency,
		o.purchase_amount / fx.fx_to_usd AS line_item_amount_usd,
		c.cost_box / fx.fx_to_usd AS cogs,
		.02 AS cashback,
		t.rate AS gst_vat,
		SAFE_DIVIDE(o.payment_gateway_fees, o.purchase_amount) AS fee_rate,
		c.packaging_cost / fx.fx_to_usd AS packaging,
		MIN(o.date) OVER(PARTITION BY o.email) AS acquisition_date
	FROM finance_metrics.cod_hk_orders_all AS o
	LEFT JOIN ref.fx_rates AS fx
		ON o.currency = fx.currency
	LEFT JOIN all_stripe.product_cost_per_box AS c
		ON o.product_id = c.product_id
		AND o.date BETWEEN c.from_date AND c.to_date
		AND c.region = 'hk'
	LEFT JOIN all_stripe.product AS prod
		ON o.product_id = prod.id
	LEFT JOIN google_sheets.condition_transaction_type_map AS cttp
		ON JSON_EXTRACT_SCALAR(prod.metadata, '$.condition') = cttp.condition
	LEFT JOIN ref.tax_rate_history AS t
		ON t.region = 'hk'
		AND o.date BETWEEN t.from_date AND t.to_date
),


atome_order_dates AS (
	SELECT
		atome_order_id,
		MIN(transaction_time) AS order_date
	FROM google_sheets.atome_manual
	GROUP BY 1
),

atome_final AS (
	SELECT
		'Atome' AS sales_channel,
		'sg' AS region,
		CAST(NULL AS STRING) AS type,
		CASE 
			WHEN o.stripe_subscription_id IS NOT NULL THEN 'Subscription'
			ELSE 'One-Time' 
			END AS purchase_type,
		'manual' AS billing_reason,
		p.from_platform_env AS brand,
		o.patient_id AS customer_id,
		p.email,
		am.atome_order_id AS charge_id,
		o.sys_id AS order_sys_id,
		o.stripe_payment_intent_id AS payment_intent_id,
		o.stripe_subscription_id AS subscription_id,
		CAST(NULL AS STRING) AS recurring_interval,
		NULL AS recurring_interval_count,
		aod.order_date AS purchase_date,
		SUM(GREATEST(am.transaction_amount, 0) / fx.fx_to_usd) AS total_charge_amount_usd,
		SUM(ABS(LEAST(am.transaction_amount, 0))) / SUM(GREATEST(am.transaction_amount, 0)) AS refund_rate,
		SUM(ABS(LEAST(am.transaction_amount, 0)) / fx.fx_to_usd) AS amount_refunded_usd,
		px.product_id,
		prod.name AS product_name,
		COALESCE(o.prescription_price_id, o.price_id) AS price_id,
		JSON_EXTRACT_SCALAR(prod.metadata, '$.condition') AS condition,
		1 AS quantity,
		LOWER(am.currency) AS currency,
		SUM(GREATEST(am.transaction_amount, 0) / fx.fx_to_usd) AS line_item_amount_usd,
		pc.cogs / fx.fx_to_usd  AS cogs,
		pc.cashback,
		t.rate AS gst_vat,
		-SUM(am.sponsored_voucher_amount + mdr_fee + flat_fee) / SUM(GREATEST(am.transaction_amount, 0) / fx.fx_to_usd) AS fee_rate,
		pc.packaging,
		MIN(aod.order_date) OVER (PARTITION BY o.patient_id) AS acquisition_date
	FROM google_sheets.atome_manual AS am
	INNER JOIN atome_order_dates AS aod
		ON am.atome_order_id = aod.atome_order_id
	LEFT JOIN sg_postgres_rds_public.order AS o
		ON am.e_commerce_platform_order_id = o.short_id
	LEFT JOIN all_postgres.patient AS p
		ON o.patient_id = p.sys_id
	LEFT JOIN ref.fx_rates AS fx
		ON LOWER(am.currency) = fx.currency
	LEFT JOIN all_stripe.price AS px
		ON COALESCE(o.prescription_price_id, o.price_id) = px.id
	LEFT JOIN all_stripe.product AS prod
		ON px.product_id = prod.id
	LEFT JOIN all_stripe.product_cost AS pc
		ON COALESCE(o.prescription_price_id, o.price_id) = pc.price_id
		AND aod.order_date BETWEEN (pc.from_date) AND pc.to_date
	LEFT JOIN ref.tax_rate_history AS t
		ON 'sg' = t.region
		AND am.transaction_time  BETWEEN t.from_date AND t.to_date
	GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,19,20,21,22,24,26,27,28,30
	HAVING SUM(GREATEST(am.transaction_amount, 0)) > 0
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
	
	SELECT * FROM hk_cod_data
	
	UNION ALL

	SELECT
		'Lazada' AS sales_channel,
		'sg' AS region,
		CAST(NULL AS STRING) AS type,
		'One-Time' AS purchase_type,
		'manual' AS billing_reason,
		'N/A' AS brand,
		CAST(NULL AS STRING) AS customer_id,
		CAST(NULL AS STRING) AS email,
		CAST(NULL AS STRING) AS charge_id,
		CAST(NULL AS STRING) AS order_sys_id,
		CAST(NULL AS STRING) AS payment_intent_id,
		CAST(NULL AS STRING) AS subscription_id,
		CAST(NULL AS STRING) AS recurring_interval,
		NULL AS recurring_interval_count,
		purchase_date,
		0 AS total_charge_amount_usd,
		refunds / line_item_amount_usd AS refund_rate,
		refunds AS amount_refunded_usd,
		seller_sku AS product_id,
		product_name,
		CAST(NULL AS STRING) AS price_id,
		condition,
		1 AS quantity,
		currency,
		line_item_amount_usd,
		cogs,
		0 AS cashback,
		t.rate AS gst_vat,
		fees / line_item_amount_usd AS fee_rate,
		packaging,
		CAST(NULL AS DATE) AS acquisition_date
	FROM lazada_data
	LEFT JOIN ref.tax_rate_history AS t
		ON t.region = 'sg'
		AND lazada_data.purchase_date BETWEEN t.from_date AND t.to_date
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