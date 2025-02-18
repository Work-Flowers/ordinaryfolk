-- 1) subscription_history
DROP VIEW IF EXISTS `all_stripe.subscription_history`;
CREATE VIEW `all_stripe.subscription_history` AS

SELECT
	'sg' AS region,
	sg.*
FROM sg_stripe.subscription_history AS sg

UNION ALL

SELECT
	'hk' AS region,
	hk.*
FROM hk_stripe.subscription_history AS hk

UNION ALL

SELECT
	'jp' AS region,
	jp.*
FROM jp_stripe.subscription_history AS jp;

-- 2) subscription_item
DROP VIEW IF EXISTS `all_stripe.subscription_item`;
CREATE VIEW `all_stripe.subscription_item` AS

SELECT
	'sg' AS region,
	sg.*
FROM sg_stripe.subscription_item AS sg

UNION ALL

SELECT
	'hk' AS region,
	hk.*
FROM hk_stripe.subscription_item AS hk

UNION ALL

SELECT
	'jp' AS region,
	jp.*
FROM jp_stripe.subscription_item AS jp;

-- 3) charge
DROP VIEW IF EXISTS `all_stripe.charge`;
CREATE VIEW `all_stripe.charge` AS

SELECT
	'sg' AS region,
	sg.*
FROM sg_stripe.charge AS sg

UNION ALL

SELECT
	'hk' AS region,
	hk.*
FROM hk_stripe.charge AS hk

UNION ALL

SELECT
	'jp' AS region,
	jp.*
FROM jp_stripe.charge AS jp;

-- 4) plan
DROP VIEW IF EXISTS `all_stripe.plan`;
CREATE VIEW `all_stripe.plan` AS

SELECT
	'sg' AS region,
	sg.*
FROM sg_stripe.plan AS sg

UNION ALL

SELECT
	'hk' AS region,
	hk.*
FROM hk_stripe.plan AS hk

UNION ALL

SELECT
	'jp' AS region,
	jp.*
FROM jp_stripe.plan AS jp;

-- 5) invoice
DROP VIEW IF EXISTS `all_stripe.invoice`;
CREATE VIEW `all_stripe.invoice` AS

SELECT
	'sg' AS region,
	sg.*
FROM sg_stripe.invoice AS sg

UNION ALL

SELECT
	'hk' AS region,
	hk.*
FROM hk_stripe.invoice AS hk

UNION ALL

SELECT
	'jp' AS region,
	jp.*
FROM jp_stripe.invoice AS jp;

-- 6) product
DROP VIEW IF EXISTS `all_stripe.product`;
CREATE VIEW `all_stripe.product` AS

SELECT
	'sg' AS region,
	sg.*
FROM sg_stripe.product AS sg

UNION ALL

SELECT
	'hk' AS region,
	hk.*
FROM hk_stripe.product AS hk

UNION ALL

SELECT
	'jp' AS region,
	jp.*
FROM jp_stripe.product AS jp;

-- 7) invoice_item
DROP VIEW IF EXISTS `all_stripe.invoice_item`;
CREATE VIEW `all_stripe.invoice_item` AS

SELECT
	'sg' AS region,
	sg.*
FROM sg_stripe.invoice_item AS sg

UNION ALL

SELECT
	'hk' AS region,
	hk.*
FROM hk_stripe.invoice_item AS hk

UNION ALL

SELECT
	'jp' AS region,
	jp.*
FROM jp_stripe.invoice_item AS jp;

-- 8) payment_intent
DROP VIEW IF EXISTS `all_stripe.payment_intent`;
CREATE VIEW `all_stripe.payment_intent` AS

SELECT
	'sg' AS region,
	id,
  metadata
FROM sg_stripe.payment_intent AS sg

UNION ALL

SELECT
	'hk' AS region,
	id,
  metadata
FROM hk_stripe.payment_intent AS hk

UNION ALL

SELECT
	'jp' AS region,
	id,
  metadata
FROM jp_stripe.payment_intent AS jp;


-- 8) price
DROP VIEW IF EXISTS `all_stripe.price`;
CREATE VIEW `all_stripe.price` AS

SELECT
	'sg' AS region,
	sg.*
FROM sg_stripe.price AS sg

UNION ALL

SELECT
	'hk' AS region,
	hk.*
FROM hk_stripe.price AS hk

UNION ALL

SELECT
	'jp' AS region,
	jp.*
FROM jp_stripe.price AS jp;

-- 9) invoice_line_item
DROP VIEW IF EXISTS `all_stripe.invoice_line_item`;
CREATE VIEW `all_stripe.invoice_line_item` AS

SELECT
	'sg' AS region,
	sg.*
FROM sg_stripe.invoice_line_item AS sg

UNION ALL

SELECT
	'hk' AS region,
	hk.*
FROM hk_stripe.invoice_line_item AS hk

UNION ALL

SELECT
	'jp' AS region,
	jp.*
FROM jp_stripe.invoice_line_item AS jp;

-- 10) invoice_line_item
DROP VIEW IF EXISTS `all_stripe.customer`;
CREATE VIEW `all_stripe.customer` AS

SELECT
	'sg' AS region,
	sg.*
FROM sg_stripe.customer AS sg

UNION ALL

SELECT
	'hk' AS region,
	hk.*
FROM hk_stripe.customer AS hk

UNION ALL

SELECT
	'jp' AS region,
	jp.*
FROM jp_stripe.customer AS jp;

-- 11) balance_transaction
DROP VIEW IF EXISTS `all_stripe.balance_transaction`;
CREATE VIEW `all_stripe.balance_transaction` AS

SELECT
	'sg' AS region,
	id,
	connected_account_id,
	amount,
	available_on,
	created,
	currency,
	description,
	exchange_rate,
	fee,
	net,
	source,
	status,
	type,
	reporting_category,
	_fivetran_synced
FROM sg_stripe.balance_transaction AS sg

UNION ALL

SELECT
	'hk' AS region,
	id,
	connected_account_id,
	amount,
	available_on,
	created,
	currency,
	description,
	exchange_rate,
	fee,
	net,
	source,
	status,
	type,
	reporting_category,
	_fivetran_synced
FROM hk_stripe.balance_transaction AS hk

UNION ALL

SELECT
	'jp' AS region,
	id,
	connected_account_id,
	amount,
	available_on,
	created,
	currency,
	description,
	exchange_rate,
	fee,
	net,
	source,
	status,
	type,
	reporting_category,
	_fivetran_synced
FROM jp_stripe.balance_transaction AS jp;