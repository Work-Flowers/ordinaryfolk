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
	_fivetran_synced,
	amount,
	amount_capturable,
	amount_received,
	application,
	application_fee_amount,
	canceled_at,
	cancellation_reason,
	capture_method,
	confirmation_method,
	connected_account_id,
	created,
	currency,
	customer_id,
	description,
	id,
	last_payment_error_charge_id,
	last_payment_error_code,
	last_payment_error_decline_code,
	last_payment_error_doc_url,
	last_payment_error_message,
	last_payment_error_param,
	last_payment_error_source_id,
	last_payment_error_type,
	livemode,
	metadata,
	on_behalf_of,
	payment_method_id,
	payment_method_types,
	source_id,
	statement_descriptor,
	status,
	transfer_data_destination,
	transfer_group
FROM sg_stripe.payment_intent AS sg

UNION ALL

SELECT
	'hk' AS region,
	_fivetran_synced,
	amount,
	amount_capturable,
	amount_received,
	application,
	application_fee_amount,
	canceled_at,
	cancellation_reason,
	capture_method,
	confirmation_method,
	connected_account_id,
	created,
	currency,
	customer_id,
	description,
	id,
	last_payment_error_charge_id,
	last_payment_error_code,
	last_payment_error_decline_code,
	last_payment_error_doc_url,
	last_payment_error_message,
	last_payment_error_param,
	last_payment_error_source_id,
	last_payment_error_type,
	livemode,
	metadata,
	on_behalf_of,
	payment_method_id,
	payment_method_types,
	source_id,
	statement_descriptor,
	status,
	transfer_data_destination,
	transfer_group

FROM hk_stripe.payment_intent AS hk

UNION ALL

SELECT
	'jp' AS region,
	_fivetran_synced,
	amount,
	amount_capturable,
	amount_received,
	application,
	application_fee_amount,
	canceled_at,
	cancellation_reason,
	capture_method,
	confirmation_method,
	connected_account_id,
	created,
	currency,
	customer_id,
	description,
	id,
	last_payment_error_charge_id,
	last_payment_error_code,
	last_payment_error_decline_code,
	last_payment_error_doc_url,
	last_payment_error_message,
	last_payment_error_param,
	last_payment_error_source_id,
	last_payment_error_type,
	livemode,
	metadata,
	on_behalf_of,
	payment_method_id,
	payment_method_types,
	source_id,
	statement_descriptor,
	status,
	transfer_data_destination,
	transfer_group

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