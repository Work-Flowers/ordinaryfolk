SELECT
    o.short_id,
    o.evaluation_id,
    s.product_name,
    s.price_metadata->>'frequency' AS frequency,
    s.price_metadata->>'dosage' AS dosage,
    s.price_metadata->>'boxes' AS boxes,
    CASE
        WHEN o.created_at = first_order.first_created_at THEN 'Yes'
        ELSE 'No'
    END AS is_first_order,
    p.email
FROM
    public.order o
JOIN
    (SELECT patient_id, MIN(created_at) AS first_created_at
     FROM public.order
     GROUP BY patient_id) AS first_order
ON
    o.patient_id = first_order.patient_id
LEFT JOIN
    public.stripe_product_price s
ON
    o.prescription_price_id = s.price_id
LEFT JOIN
    public.patient p
ON
    o.patient_id::text = p.sys_id::text
WHERE
    o.short_id IN (
        293611, 293545, 271567, 292324, 292357, 291301, 291037, 288463, 251207,
        289783, 289420, 288067, 288100, 288529, 286715, 285726, 286714, 285726,
        286715, 278464, 284998, 225169, 284074, 283546, 247774, 265958, 283315,
        281567, 282754, 282259, 282226, 281698, 229525, 281830, 260614, 265298,
        280873, 279784, 258666, 279192, 254773, 278167, 277739, 246091, 277078,
        277243, 276616, 276649, 274108, 275923, 274339, 275825, 275461, 275065,
        275131, 273580, 271567, 273749, 272590, 272953, 273382, 273383
    );