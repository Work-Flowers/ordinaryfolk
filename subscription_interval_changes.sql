
-- Step 1: Create a Common Table Expression (CTE) called 'all_intervals'
WITH all_intervals AS (
    SELECT DISTINCT
        UPPER(sh.region) AS country,                         -- Normalize country/region to uppercase
        sh.id AS subscription_id,                            -- Subscription ID
        sh.status,                                           -- Subscription status (active, canceled, etc.)
        DATE(sh.created) AS subscription_created,            -- Date the subscription was created
        DATE(sh._fivetran_start) AS subscription_updated,    -- Update timestamp from Fivetran
        p.product_id,                                        -- Product ID
        prod.name AS product_name,                           -- Product name
        JSON_EXTRACT_SCALAR(prod.metadata, '$.condition') AS condition, -- Extract 'condition' from product JSON metadata
        p.interval_count AS current_interval_count,           -- Bill interval (e.g., monthly count)
        
        -- Previous interval count for this subscription/product pair
        LAG(p.interval_count) OVER (
            PARTITION BY sh.id, p.product_id
            ORDER BY sh._fivetran_start
        ) AS previous_interval_count,

        -- First recorded interval count in the history for this subscription/product
        FIRST_VALUE(p.interval_count) OVER (
            PARTITION BY sh.id, p.product_id
            ORDER BY sh._fivetran_start
        ) AS first_interval_count

    FROM all_stripe.subscription_history AS sh
    JOIN all_stripe.invoice_line_item AS ili 
        ON sh.latest_invoice_id = ili.invoice_id                -- Link subscription to its most recent invoice
    JOIN all_stripe.plan AS p 
        ON ili.plan_id = p.id                                   -- Link invoice line to plan
        AND p.interval = 'month'                                -- Only consider plans billed monthly
    JOIN all_stripe.product AS prod
        ON p.product_id = prod.id                               -- Link plan to product
),

-- Step 2: Find the first qualifying active subscription interval for each subscription-product pair
first_interval AS (
    SELECT *
    FROM all_intervals
    WHERE
        1 = 1                       -- Dummy condition for easier commenting/editing
        AND first_interval_count <= 3   -- Only consider if the original interval count was 3 or less
        AND status = 'active'           -- Only active subscriptions
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY subscription_id, product_id
        ORDER BY subscription_updated
    ) = 1                             -- Keep only the first chronological record per pair
)

-- Step 3: Main select - find upgrades within 90 days to interval counts greater than 3
SELECT 
    fi.country,                                       -- The normalized country/region
    fi.subscription_id,                               -- The subscription ID
    fi.subscription_created,                          -- Date subscription was started
    ai.subscription_updated,                          -- Date subscription was upgraded
    fi.product_id,                                    -- Product ID
    fi.product_name,                                  -- Product name
    fi.condition,                                     -- Product 'condition' metadata
    fi.first_interval_count,                          -- Original interval count (<= 3)
    ai.current_interval_count,                        -- The upgraded interval count (> 3)
    DATE_DIFF(ai.subscription_updated, ai.subscription_created, DAY) AS days_elapsed -- Days from start to upgrade
FROM first_interval AS fi
LEFT JOIN all_intervals AS ai
    ON fi.subscription_id = ai.subscription_id
    AND fi.product_id = ai.product_id
    AND ai.current_interval_count > ai.previous_interval_count         -- Only true upgrades
    AND ai.current_interval_count > 3                                 -- Only upgrades beyond 3
    AND DATE_DIFF(ai.subscription_updated, ai.subscription_created, DAY)  <= 90 -- Upgrade must occur within 90 days
