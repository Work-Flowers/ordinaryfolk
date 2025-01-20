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