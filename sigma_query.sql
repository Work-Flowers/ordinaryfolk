 Select
  lower(to_hex(md5(to_utf8(trim(customers.id))))) as "ID",
  customers.email AS "Email",
  charges.created AS "Purchase Date",
  charges.description As "Transaction Type",
  charges.amount AS "Purchase Amount",
  refunds.amount as "Refund Amount",
  products.name AS "Product Name",
  prices.id AS "Price ID",
  COALESCE(
    MAX(CASE WHEN payment_intents_metadata.key = 'paymentIntentPriceId' THEN payment_intents_metadata.value END),
    MAX(CASE WHEN payment_intents_metadata.key = 'stripePriceIds' THEN payment_intents_metadata.value END)
  ) AS "Price ID (no-invoice charge)",
  MAX(invoice_items.price_id) AS "Invoice Price ID",
  map_agg(prices_metadata.key, prices_metadata.value) AS "Price Metadata"
FROM
  charges
  LEFT JOIN payment_intents ON payment_intents.id = charges.payment_intent
  LEFT JOIN customers ON customers.id = payment_intents.customer_id
  LEFT JOIN invoices ON payment_intents.invoice_id = invoices.id
  LEFT JOIN payment_intents_metadata ON payment_intents.id = payment_intents_metadata.payment_intent_id
  LEFT JOIN subscriptions ON invoices.subscription_id = subscriptions.id
  LEFT JOIN prices ON subscriptions.price_id = prices.id
  LEFT JOIN invoice_items ON invoices.id = invoice_items.invoice_id
  LEFT JOIN products ON prices.product_id = products.id
  LEFT JOIN prices_metadata ON prices.id = prices_metadata.price_id
  LEFT JOIN refunds on refunds.charge_id = charges.id
WHERE
  charges.status = 'succeeded' and
  charges.created >= date('2025-01-01')
GROUP BY
  customers.email,
  customers.id,
  charges.created,
  charges.description,
  charges.amount,
  refunds.amount,
  charges.id,
  products.name,
  prices.id
ORDER BY
  charges.created ASC;