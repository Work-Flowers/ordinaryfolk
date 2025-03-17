WITH rx_customers AS (
	SELECT DISTINCT
		ch.region,
		ch.customer_id
	FROM all_stripe.charge AS ch
	INNER JOIN all_stripe.invoice AS inv
		ON ch.invoice_id = inv.id
	INNER JOIN all_stripe.invoice_line_item AS ili
		ON inv.id = ili.invoice_id
	INNER JOIN all_stripe.price AS px
		ON ili.price_id = px.id
	INNER JOIN all_stripe.product 
		ON px.product_id = product.id
	WHERE
		ch.status = 'succeeded'
		AND product.id NOT IN (
			'prod_sg_wellbeing_nonbe',
			'prod_sg_hl_grow_gum',
			'prod_MvidnPG8TmGzSp',
			'prod_MvidpvliZYKjUw',
			'prod_MvidwsPVspbhhh',
			'prod_LlAuj4CN5yDJX7',
			'prod_LV0X9pjqbfdcI6',
			'prod_LV0XpF1BcCEEmb',
			'prod_LV0XBXxmPNz2Cx',
			'prod_LV0WuJBaBHsyog',
			'prod_LV0WCqLrvNYCTC',
			'prod_LV0WeLYAjOBA6A',
			'prod_LV0WHhQmSfOcbJ',
			'prod_LV0WTxxK2qjzUo',
			'prod_KDfTsmSAJ3pQuU',
			'prod_KCZVBUCIWCWgko',
			'prod_KCZTbyE8t5cuEa',
			'prod_JzgitGwlJPWAtV',
			'prod_JvCD17WT9koS05',
			'prod_Jfqeq1HQTrY7Rn',
			'prod_sg_wellbeing_nonbe',
			'prod_hk_hl_grow_gum',
			'prod_hk_sleep_sleepthins_123',
			'prod_Mws9iLaddPlmu3',
			'prod_Mws8a7FxRibgcU',
			'prod_Mws6M71LxdRUkV',
			'prod_MlIQWryQYKnCzG',
			'prod_KWPnD566MBSF3V',
			'prod_KWN0MREmRqQLhM',
			'prod_M8O7GFZF807szx',
			'prod_Jw18zqru8fsbIA',
			'prod_KwxO4RGSlylsw8',
			'prod_LltRRtYVbCj0j3',
			'prod_M8O7TiXOuoK0Vp',
			'prod_JDp75SMVPAOeGB',
			'prod_JXdNTGduNrf732',
			'prod_OhbYd9B7YKfu8a',
			'prod_KWOGPmnD1qjKQe',
			'prod_J8xb2CpE45lkCf',
			'prod_J9KqDIlUW0cOL6',
			'prod_JLFoT6Gqo16xIK',
			'prod_MGefcIglwzbB1q',
			'prod_K0RlT5kOC20t7d',
			'prod_PB4K9gSShZIHQE'
		)
),

otc_customers AS (
	SELECT DISTINCT
		ch.region,
		ch.customer_id
	FROM all_stripe.charge AS ch
	INNER JOIN all_stripe.invoice AS inv
		ON ch.invoice_id = inv.id
	INNER JOIN all_stripe.invoice_line_item AS ili
		ON inv.id = ili.invoice_id
	INNER JOIN all_stripe.price AS px
		ON ili.price_id = px.id
	INNER JOIN all_stripe.product 
		ON px.product_id = product.id
	WHERE
		ch.status = 'succeeded'
		AND product.id IN (
			'prod_sg_wellbeing_nonbe',
			'prod_sg_hl_grow_gum',
			'prod_MvidnPG8TmGzSp',
			'prod_MvidpvliZYKjUw',
			'prod_MvidwsPVspbhhh',
			'prod_LlAuj4CN5yDJX7',
			'prod_LV0X9pjqbfdcI6',
			'prod_LV0XpF1BcCEEmb',
			'prod_LV0XBXxmPNz2Cx',
			'prod_LV0WuJBaBHsyog',
			'prod_LV0WCqLrvNYCTC',
			'prod_LV0WeLYAjOBA6A',
			'prod_LV0WHhQmSfOcbJ',
			'prod_LV0WTxxK2qjzUo',
			'prod_KDfTsmSAJ3pQuU',
			'prod_KCZVBUCIWCWgko',
			'prod_KCZTbyE8t5cuEa',
			'prod_JzgitGwlJPWAtV',
			'prod_JvCD17WT9koS05',
			'prod_Jfqeq1HQTrY7Rn',
			'prod_sg_wellbeing_nonbe',
			'prod_hk_hl_grow_gum',
			'prod_hk_sleep_sleepthins_123',
			'prod_Mws9iLaddPlmu3',
			'prod_Mws8a7FxRibgcU',
			'prod_Mws6M71LxdRUkV',
			'prod_MlIQWryQYKnCzG',
			'prod_KWPnD566MBSF3V',
			'prod_KWN0MREmRqQLhM'
		)
),

joined_customers AS (
	SELECT
		rx.*,
		oc.customer_id IS NOT NULL AS has_otc
	FROM rx_customers AS rx
	LEFT JOIN otc_customers AS oc
		ON rx.customer_id = oc.customer_id
)

SELECT
	region,
	has_otc,
	COUNT(customer_id) AS n_customers,
	ROUND(COUNT(customer_id) / SUM(COUNT(customer_id)) OVER (PARTITION BY region), 2) AS share_of_region
FROM joined_customers
GROUP BY 1,2
ORDER BY 1, 2 DESC