use digital_analytics


-- Creating the order_data table by joining 3 order related tables
WITH base_data AS (
    SELECT 
		o.order_id,
        o.created_at AS order_created_at,
		o.website_session_id AS order_website_session_id,
		o.user_id ,
        o.primary_product_id,
        o.items_purchased,
		oi.order_item_id,
        oi.product_id AS product_id,
        oi.is_primary_item,
        oi.price_usd AS price_usd,
        oi.cogs_usd AS cogs_usd,
        p.created_at as prod_created_at,
		p.product_name,
		oir.created_at as refund_created_at,
		oir.refund_amount_usd

	 FROM 
        orders AS o
	  JOIN 
        order_items AS oi
        ON o.order_id = oi.order_id
		left join products as p
		on oi.product_id=p.product_id
		left join order_item_refunds as oir on
		oi.order_item_id = oir.order_item_id
)
SELECT *
INTO order_data
FROM base_data;



/******************************** EXploratory Data Analysis*********************/

---Total cost of goods sold
WITH refunded_cogs AS (
    SELECT 
        oi.order_item_id,
        COALESCE(SUM(oir.refund_amount_usd), 0) AS refunded_cogs
    FROM 
        order_items oi
    LEFT JOIN 
        order_item_refunds oir ON oi.order_item_id = oir.order_item_id
    GROUP BY 
        oi.order_item_id
)
SELECT 
    SUM(oi.cogs_usd) - SUM(rc.refunded_cogs) AS net_cogs
FROM 
    order_items oi
LEFT JOIN 
    refunded_cogs rc ON oi.order_item_id = rc.order_item_id;



--Average product_price
select AVG(distinct price_usd) as average_product_price from order_items

--refunded items percentage
SELECT 
 (SELECT COUNT(order_item_refund_id) FROM order_item_refunds) * 100.0 /
 (SELECT COUNT(order_item_id) FROM order_items) AS refund_percentage;

 --Total refund amount
 select SUM(refund_amount_usd) from order_item_refunds

 --refunded amount percentage
SELECT 
 (SELECT sum(refund_amount_usd) FROM order_item_refunds) * 100.0 /
 (SELECT sum(price_usd) FROM orders) AS refund_percentage;

 --Total number of customers who ordered
 select COUNT(distinct USER_ID) from orders

  --Total number of customers
 select COUNT(distinct USER_ID) from website_sessions


 --Number of repeat buyers
select count(*) as repeat_buyer_count from
	(select USER_ID from Orders
	group by user_id
	having count(user_id)>1) as a

	--repeat buyer percentage
WITH user_order_counts AS (
    SELECT user_id,
           COUNT(order_id) AS order_count
    FROM orders
    GROUP BY user_id
)
SELECT
    (COUNT(CASE WHEN order_count > 1 THEN 1 END) * 100.0 / COUNT(*)) AS repeat_buyer_percentage
FROM
    user_order_counts;

	--avg number of items per order
	SELECT
    SUM(items_purchased) * 1.0 / COUNT(order_id) AS avg_items_per_order
FROM
    orders;





	---------------------------------------Traffic source analysis
	
---Identify top traffic source
select utm_source,COUNT(*) as source_count
from website_sessions
group by utm_source
order by source_count desc


--- Traffic Source Conversion Rates
	SELECT 
    w.utm_source,
    COUNT( o.order_id) * 100.0 / COUNT( w.website_session_id) AS conversion_rate
FROM 
    website_sessions AS w
LEFT JOIN 
    Orders AS o ON w.website_session_id = o.website_session_id
GROUP BY 
    w.utm_source;

	---campaign with highest conversion rates
	SELECT 
    ws.utm_campaign AS campaign,
    COUNT( ws.website_session_id) AS total_sessions,
    COUNT( o.order_id) AS total_conversions,
    (COUNT( o.order_id) * 1.0 / COUNT( ws.website_session_id)) * 100 AS conversion_rate
FROM 
    website_sessions ws
LEFT JOIN 
    orders o ON ws.website_session_id = o.website_session_id
GROUP BY 
    ws.utm_campaign
ORDER BY 
    conversion_rate DESC


	--ads with highest conversion rate
	SELECT 
    ws.utm_content AS ads,
    COUNT( ws.website_session_id) AS total_sessions,
    COUNT( o.order_id) AS total_conversions,
    (COUNT( o.order_id) * 1.0 / COUNT( ws.website_session_id)) * 100 AS conversion_rate
FROM 
    website_sessions ws
LEFT JOIN 
    orders o ON ws.website_session_id = o.website_session_id
GROUP BY 
    ws.utm_content
ORDER BY 
    conversion_rate DESC


/**********************************************************************************
What is the breakdown of sessions by UTM source, campaign, and referring domain up to April 12, 2012.
****************************************************************************************/

--sessions by utm_source
SELECT 
    utm_source,
    COUNT(website_session_id) AS session_count
FROM 
    website_sessions
WHERE 
    created_at <= '2012-04-12'
GROUP BY 
    utm_source
ORDER BY 
    session_count DESC;


---Sessions by campaign
SELECT 
    utm_campaign,
    COUNT(website_session_id) AS session_count
FROM 
    website_sessions
WHERE 
    created_at <= '2012-04-12'
GROUP BY 
    utm_campaign
ORDER BY 
    session_count DESC;

--sessions by referring domain
SELECT 
    http_referer,
    COUNT(website_session_id) AS session_count
FROM 
    website_sessions
WHERE 
    created_at <= '2012-04-12'
GROUP BY 
    http_referer
ORDER BY 
    session_count DESC;


/**********************************************************************************
 Traffic Conversion Rates: Calculate conversion rate (CVR) from sessions to order. If CVR is 4% >=, then increase bids to drive 
volume, otherwise reduce bids. (Filter sessions < 2012-04-12, utm_source = gsearch and utm_campaign = nonbrand)
****************************************************************************************/

select COUNT(w.website_session_id) as sessions,COUNT(o.order_id) as orders, 
count(o.order_id)*100.0/count(w.website_session_id) as cvr
from website_sessions as w 
left join orders as o on w.website_session_id=o.website_session_id
where w.created_at <='04-12-2012' and utm_source='gsearch' and utm_campaign='nonbrand'


/**********************************************************************************
Traffic Source Trending: After bidding down on Apr 15, 2021, what is the trend and impact on sessions for gsearch nonbrand 
campaign? Find weekly sessions before 2012-05-10.
****************************************************************************************/

SELECT 
    DATEADD(WEEK, DATEDIFF(WEEK, 0, created_at), 0) AS week_start,
    COUNT(website_session_id) AS weekly_sessions
FROM 
    website_sessions
WHERE 
    created_at < '2012-05-10'
    AND utm_source = 'gsearch'
    AND utm_campaign = 'nonbrand'
GROUP BY 
    DATEADD(WEEK, DATEDIFF(WEEK, 0, created_at), 0)
ORDER BY 
    week_start;


	/**********************************************************************************
Traffic Source Bid Optimization: What is the conversion rate from session to order by device type?
****************************************************************************************/

SELECT 
    ws.device_type,
    COUNT(DISTINCT o.website_session_id) * 100.0 / COUNT(DISTINCT ws.website_session_id) AS conversion_rate
FROM 
    website_sessions ws
LEFT JOIN 
    orders o ON ws.website_session_id = o.website_session_id
GROUP BY 
    ws.device_type;



/**********************************************************************************
 Traffic Source Segment Trending: After bidding up on desktop channel on 2012-05-19, 
 what is the weekly session trend for both desktop and mobile?
****************************************************************************************/

SELECT 
    DATEDIFF(WEEK, '2012-05-19', created_at) + 1 AS week_number,
    SUM(CASE WHEN device_type = 'desktop' THEN 1 ELSE 0 END) AS desktop_sessions,
    SUM(CASE WHEN device_type = 'mobile' THEN 1 ELSE 0 END) AS mobile_sessions
FROM 
    website_sessions
WHERE 
    created_at >= '2012-05-19'
GROUP BY 
    DATEDIFF(WEEK, '2012-05-19', created_at)
ORDER BY 
    week_number;


/**********************************************************************************
	 New Vs. Repeat Channel Patterns: Analyze the channels through which repeat customers return to our website, comparing them 
to new sessions? Specifically,  interested in understanding if repeat customers predominantly come through direct type-in or if 
there’s a significant portion that originates from paid search ads. This analysis should cover the period from the beginning of 2014 
to the present date.
****************************************************************************************/

WITH filtered_sessions AS (
    SELECT
        ws.website_session_id,
        ws.is_repeat_session,
        CASE
            WHEN ws.utm_source = 'null' AND ws.http_referer = 'null' THEN 'Direct Type-In'
            WHEN ws.utm_source != 'null' THEN 'Paid Ad'
            WHEN ws.utm_source = 'null' AND ws.http_referer != 'null' THEN 'Organic Search'
        END AS traffic_type
    FROM
        website_sessions ws
    LEFT JOIN orders o ON ws.user_id = o.user_id
    WHERE
        ws.created_at >= '2014-01-01'
),
session_summary AS (
    SELECT
        is_repeat_session,
        traffic_type,
        COUNT(*) AS session_count
    FROM
        filtered_sessions
    WHERE
        traffic_type IN ('Direct Type-In', 'Paid Ad', 'Organic Search') -- Include Direct, Paid, and Organic
    GROUP BY
        is_repeat_session, traffic_type
),
total_sessions AS (
    SELECT
        is_repeat_session,
        SUM(session_count) AS total_count
    FROM
        session_summary
    GROUP BY
        is_repeat_session
)
SELECT
    ss.is_repeat_session,
    ss.traffic_type,
    ss.session_count,
    ROUND((ss.session_count * 1.0 / ts.total_count * 100), 10) AS session_percentage
FROM
    session_summary ss
JOIN
    total_sessions ts
ON
    ss.is_repeat_session = ts.is_repeat_session
ORDER BY
    is_repeat_session, traffic_type;



use digital_analytics

/**********************************************************************************
	New Vs. Repeat Performance: Provide analysis on comparison of conversion rates and revenue per 
	session for repeat sessions vs new sessions? 2014 to date is good.
****************************************************************************************/
WITH UserFirstSession AS (
    SELECT 
        user_id,
        MIN(created_at) AS first_session_date -- The earliest session for each user
    FROM 
        website_sessions
    GROUP BY 
        user_id
),
SessionClassification AS (
    SELECT 
        ws.website_session_id,
        ws.user_id,
        CASE 
            WHEN ws.created_at = ufs.first_session_date THEN 0 -- New session if it matches the first session
            ELSE 1 -- Repeat session otherwise
        END AS is_repeat_session
    FROM 
        website_sessions ws
    LEFT JOIN 
        UserFirstSession ufs ON ws.user_id = ufs.user_id
),
SessionStats AS (
    SELECT 
        sc.is_repeat_session,
        COUNT(DISTINCT ws.website_session_id) AS total_sessions,
        COALESCE(SUM(oi.price_usd), 0) AS total_sales,
        COALESCE(SUM(ori.refund_amount_usd), 0) AS total_refunds,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM 
        SessionClassification sc
    LEFT JOIN 
        website_sessions ws ON sc.website_session_id = ws.website_session_id
    LEFT JOIN 
        orders o ON ws.website_session_id = o.website_session_id
    LEFT JOIN 
        order_items oi ON o.order_id = oi.order_id
    LEFT JOIN 
        order_item_refunds ori ON oi.order_item_id = ori.order_item_id
    GROUP BY 
        sc.is_repeat_session
)
SELECT 
    CASE 
        WHEN is_repeat_session = 1 THEN 'Repeat Sessions'
        ELSE 'New Sessions'
    END AS session_type,
    total_sessions,
    total_orders,
    total_sales - total_refunds AS total_revenue,
    (total_orders * 100.0 / NULLIF(total_sessions, 0)) AS conversion_percentage,
    (total_sales - total_refunds) * 1.0 / NULLIF(total_sessions, 0) AS revenue_per_session
FROM 
    SessionStats;






	/**********************************************************************************
Build Conversion Funnels for gsearch nonbrand traffic from /lander-1 to /thank you page: 
What are the session counts and click percentages for /lander-1, /products, 
product (mrfuzzy), cart, shipping, billing, and thank you pages from August 5, 2012, to 
September 5, 2012?
****************************************************************************************/

WITH session_pages AS (
    SELECT
        wp.website_session_id,
        wp.pageview_url,
        wp.created_at
    FROM website_pageviews wp
    JOIN website_sessions ws ON wp.website_session_id = ws.website_session_id
    WHERE
        ws.utm_source = 'gsearch'
        AND ws.utm_campaign = 'nonbrand'
        AND wp.created_at BETWEEN '2012-08-05' AND '2012-09-05'
        AND wp.pageview_url IN (
            '/lander-1', 
            '/products',
            '/the-original-mr-fuzzy', 
            '/cart', 
            '/shipping', 
            '/billing', 
            '/thank-you-for-your-order'
        )
),

ordered_session_pages AS (
    SELECT
        website_session_id,
        pageview_url,
        ROW_NUMBER() OVER(PARTITION BY website_session_id ORDER BY created_at) AS page_order
    FROM session_pages
),

funnel_steps AS (
    SELECT 
        website_session_id,
        MAX(CASE WHEN page_order = 1 AND pageview_url = '/lander-1' THEN 1 ELSE 0 END) AS step_1_lander,
        MAX(CASE WHEN page_order = 2 AND pageview_url = '/products' THEN 1 ELSE 0 END) AS step_2_products,
        MAX(CASE WHEN page_order = 3 AND pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END) AS step_3_product,
        MAX(CASE WHEN page_order = 4 AND pageview_url = '/cart' THEN 1 ELSE 0 END) AS step_4_cart,
        MAX(CASE WHEN page_order = 5 AND pageview_url = '/shipping' THEN 1 ELSE 0 END) AS step_5_shipping,
        MAX(CASE WHEN page_order = 6 AND pageview_url = '/billing' THEN 1 ELSE 0 END) AS step_6_billing,
        MAX(CASE WHEN page_order = 7 AND pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END) AS step_7_thank_you
    FROM ordered_session_pages
    GROUP BY website_session_id
)

SELECT
    SUM(step_1_lander) AS lander_1_sessions,
    SUM(step_2_products) AS products_page_sessions,
    SUM(step_3_product) AS mrfuzzy_sessions,
    SUM(step_4_cart) AS cart_page_sessions,
    SUM(step_5_shipping) AS shipping_page_sessions,
    SUM(step_6_billing) AS billing_page_sessions,
    SUM(step_7_thank_you) AS thank_you_page_sessions,
    (SUM(step_2_products) * 100.0 / NULLIF(SUM(step_1_lander), 0)) AS lander_to_products_percentage,
    (SUM(step_3_product) * 100.0 / NULLIF(SUM(step_2_products), 0)) AS products_to_mrfuzzy_percentage,
    (SUM(step_4_cart) * 100.0 / NULLIF(SUM(step_3_product), 0)) AS mrfuzzy_to_cart_percentage,
    (SUM(step_5_shipping) * 100.0 / NULLIF(SUM(step_4_cart), 0)) AS cart_to_shipping_percentage,
    (SUM(step_6_billing) * 100.0 / NULLIF(SUM(step_5_shipping), 0)) AS shipping_to_billing_percentage,
    (SUM(step_7_thank_you) * 100.0 / NULLIF(SUM(step_6_billing), 0)) AS billing_to_thank_you_percentage
FROM funnel_steps;





/**********************************************************************************
	Analyze Conversion Funnel Tests for /billing vs. new /billing-2 pages: what is the traffic and billing to order conversion rate of 
    both pages new/billing-2 page?
****************************************************************************************/

WITH funnel_sessions AS (
    SELECT 
        wp.website_session_id,
        wp.pageview_url,
        ROW_NUMBER() OVER(PARTITION BY wp.website_session_id ORDER BY wp.created_at) AS page_order
    FROM website_pageviews wp
),

billing_sessions AS (
    SELECT 
        website_session_id,
        MAX(CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END) AS billing,
        MAX(CASE WHEN pageview_url = '/billing-2' THEN 1 ELSE 0 END) AS billing_2,
        MAX(CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END) AS order_completed
    FROM funnel_sessions
    GROUP BY website_session_id
)

SELECT
    page,
    COUNT(*) AS traffic,
    SUM(order_completed) AS orders,
    (SUM(order_completed) * 100.0 / NULLIF(COUNT(*), 0)) AS conversion_rate
FROM (
    SELECT 
        website_session_id, 
        CASE 
            WHEN billing = 1 THEN '/billing'
            WHEN billing_2 = 1 THEN '/billing-2'
        END AS page,
        order_completed
    FROM billing_sessions
    WHERE billing = 1 OR billing_2 = 1
) AS conversion_data
GROUP BY page;



select distinct (pageview_url) from website_pageviews

	/**********************************************************************************
 Product Pathing Analysis: What are the clickthrough rates from /products since the new product launch on January 6th 2013,by 
product and compare to the 3 months leading up to launch as a baseline?
****************************************************************************************/
WITH session_pages AS (
    -- Select relevant pages for the funnel analysis
    SELECT
        website_session_id,
        pageview_url,
        created_at
    FROM website_pageviews
    WHERE pageview_url IN (
        '/products',
        '/the-original-mr-fuzzy',
        '/the-forever-love-bear',
        '/the-birthday-sugar-panda',
        '/the-hudson-river-mini-bear'
    )
),

ordered_session_pages AS (
    -- Order pages within each session to track the path progression
    SELECT 
        website_session_id,
        pageview_url,
        ROW_NUMBER() OVER(PARTITION BY website_session_id ORDER BY created_at) AS page_order
    FROM session_pages
),

funnel_steps AS (
    -- Identify each step in the funnel for product pages
    SELECT 
        website_session_id,
        MAX(CASE WHEN page_order = 1 AND pageview_url = '/products' THEN 1 ELSE 0 END) AS step_1_products,
        MAX(CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END) AS step_2_mr_fuzzy,
        MAX(CASE WHEN pageview_url = '/the-forever-love-bear' THEN 1 ELSE 0 END) AS step_2_forever_love_bear,
        MAX(CASE WHEN pageview_url = '/the-birthday-sugar-panda' THEN 1 ELSE 0 END) AS step_2_birthday_sugar_panda,
        MAX(CASE WHEN pageview_url = '/the-hudson-river-mini-bear' THEN 1 ELSE 0 END) AS step_2_hudson_river_mini_bear
    FROM ordered_session_pages
    GROUP BY website_session_id
),

-- Calculate clickthrough rates for the baseline period by product
ctr_baseline AS (
    SELECT
        'Baseline' AS period,
        COUNT(DISTINCT CASE WHEN step_1_products = 1 THEN website_session_id END) AS products_page_sessions,
        COUNT(DISTINCT CASE WHEN step_2_mr_fuzzy = 1 THEN website_session_id END) AS mr_fuzzy_sessions,
        COUNT(DISTINCT CASE WHEN step_2_forever_love_bear = 1 THEN website_session_id END) AS forever_love_bear_sessions,
        COUNT(DISTINCT CASE WHEN step_2_birthday_sugar_panda = 1 THEN website_session_id END) AS birthday_sugar_panda_sessions,
        COUNT(DISTINCT CASE WHEN step_2_hudson_river_mini_bear = 1 THEN website_session_id END) AS hudson_river_mini_bear_sessions,
        (COUNT(DISTINCT CASE WHEN step_2_mr_fuzzy = 1 THEN website_session_id END) * 100.0 / NULLIF(COUNT(DISTINCT CASE WHEN step_1_products = 1 THEN website_session_id END), 0)) AS products_to_mr_fuzzy_percentage,
        (COUNT(DISTINCT CASE WHEN step_2_forever_love_bear = 1 THEN website_session_id END) * 100.0 / NULLIF(COUNT(DISTINCT CASE WHEN step_1_products = 1 THEN website_session_id END), 0)) AS products_to_forever_love_bear_percentage,
        (COUNT(DISTINCT CASE WHEN step_2_birthday_sugar_panda = 1 THEN website_session_id END) * 100.0 / NULLIF(COUNT(DISTINCT CASE WHEN step_1_products = 1 THEN website_session_id END), 0)) AS products_to_birthday_sugar_panda_percentage,
        (COUNT(DISTINCT CASE WHEN step_2_hudson_river_mini_bear = 1 THEN website_session_id END) * 100.0 / NULLIF(COUNT(DISTINCT CASE WHEN step_1_products = 1 THEN website_session_id END), 0)) AS products_to_hudson_river_mini_bear_percentage
    FROM funnel_steps
    WHERE website_session_id IN (
        SELECT website_session_id
        FROM session_pages
        WHERE created_at BETWEEN '2012-10-06' AND '2013-01-05'
    )
),

-- Calculate clickthrough rates for the post-launch period by product
ctr_post_launch AS (
    SELECT
        'Post-Launch' AS period,
        COUNT(DISTINCT CASE WHEN step_1_products = 1 THEN website_session_id END) AS products_page_sessions,
        COUNT(DISTINCT CASE WHEN step_2_mr_fuzzy = 1 THEN website_session_id END) AS mr_fuzzy_sessions,
        COUNT(DISTINCT CASE WHEN step_2_forever_love_bear = 1 THEN website_session_id END) AS forever_love_bear_sessions,
        COUNT(DISTINCT CASE WHEN step_2_birthday_sugar_panda = 1 THEN website_session_id END) AS birthday_sugar_panda_sessions,
        COUNT(DISTINCT CASE WHEN step_2_hudson_river_mini_bear = 1 THEN website_session_id END) AS hudson_river_mini_bear_sessions,
        (COUNT(DISTINCT CASE WHEN step_2_mr_fuzzy = 1 THEN website_session_id END) * 100.0 / NULLIF(COUNT(DISTINCT CASE WHEN step_1_products = 1 THEN website_session_id END), 0)) AS products_to_mr_fuzzy_percentage,
        (COUNT(DISTINCT CASE WHEN step_2_forever_love_bear = 1 THEN website_session_id END) * 100.0 / NULLIF(COUNT(DISTINCT CASE WHEN step_1_products = 1 THEN website_session_id END), 0)) AS products_to_forever_love_bear_percentage,
        (COUNT(DISTINCT CASE WHEN step_2_birthday_sugar_panda = 1 THEN website_session_id END) * 100.0 / NULLIF(COUNT(DISTINCT CASE WHEN step_1_products = 1 THEN website_session_id END), 0)) AS products_to_birthday_sugar_panda_percentage,
        (COUNT(DISTINCT CASE WHEN step_2_hudson_river_mini_bear = 1 THEN website_session_id END) * 100.0 / NULLIF(COUNT(DISTINCT CASE WHEN step_1_products = 1 THEN website_session_id END), 0)) AS products_to_hudson_river_mini_bear_percentage
    FROM funnel_steps
    WHERE website_session_id IN (
        SELECT website_session_id
        FROM session_pages
        WHERE created_at >= '2013-01-06'
    )
)

-- Combine baseline and post-launch results
SELECT * FROM ctr_baseline
UNION ALL
SELECT * FROM ctr_post_launch;


use digital_analytics

	/**********************************************************************************
	Product Conversion Funnels: provide a comparison of the conversion funnels from the product pages to conversion for two 
products since January 6th, analyzing all website traffic?
	****************************************************************************************/

WITH session_pages AS (
    -- Select relevant pages for the conversion funnel analysis
    SELECT
        wp.website_session_id,
        wp.pageview_url,
        wp.created_at
    FROM website_pageviews wp
    WHERE wp.created_at >= '2013-01-06'  -- Consider sessions from this date onwards
    AND wp.pageview_url IN (
        '/products',
        '/the-original-mr-fuzzy',
        '/the-forever-love-bear',
        '/cart',
        '/shipping',
        '/billing',
        '/billing-2',
        '/thank-you-for-your-order'
    )
),

ordered_session_pages AS (
    -- Order pages within each session to track the path progression
    SELECT 
        website_session_id,
        pageview_url,
        ROW_NUMBER() OVER(PARTITION BY website_session_id ORDER BY created_at) AS page_order
    FROM session_pages
),

product_sessions AS (
    -- Create separate records for sessions viewing each product
    SELECT 
        website_session_id,
        MAX(CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END) AS step_1_products,
        MAX(CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END) AS viewed_mr_fuzzy,
        MAX(CASE WHEN pageview_url = '/the-forever-love-bear' THEN 1 ELSE 0 END) AS viewed_forever_love_bear,
        MAX(CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END) AS step_3_cart,
        MAX(CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END) AS step_4_shipping,
        MAX(CASE WHEN pageview_url IN ('/billing', '/billing-2') THEN 1 ELSE 0 END) AS step_5_billing,
        MAX(CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END) AS step_6_thank_you
    FROM ordered_session_pages
    GROUP BY website_session_id
)

-- Select the conversion funnel results
SELECT 
    'The Original Mr. Fuzzy' AS product_name,
    SUM(step_1_products) AS products_page_sessions,
    SUM(viewed_mr_fuzzy) AS product_page_sessions,
    SUM(CASE WHEN viewed_mr_fuzzy = 1 THEN step_3_cart ELSE 0 END) AS cart_page_sessions,
    SUM(CASE WHEN viewed_mr_fuzzy = 1 THEN step_4_shipping ELSE 0 END) AS shipping_page_sessions,
    SUM(CASE WHEN viewed_mr_fuzzy = 1 THEN step_5_billing ELSE 0 END) AS billing_page_sessions,
    SUM(CASE WHEN viewed_mr_fuzzy = 1 THEN step_6_thank_you ELSE 0 END) AS thank_you_page_sessions,
    (SUM(viewed_mr_fuzzy) * 100.0 / NULLIF(SUM(step_1_products), 0)) AS products_to_product_percentage,
    (SUM(CASE WHEN viewed_mr_fuzzy = 1 THEN step_3_cart ELSE 0 END) * 100.0 / NULLIF(SUM(viewed_mr_fuzzy), 0)) AS product_to_cart_percentage,
    (SUM(CASE WHEN viewed_mr_fuzzy = 1 THEN step_4_shipping ELSE 0 END) * 100.0 / NULLIF(SUM(CASE WHEN viewed_mr_fuzzy = 1 THEN step_3_cart ELSE 0 END), 0)) AS cart_to_shipping_percentage,
    (SUM(CASE WHEN viewed_mr_fuzzy = 1 THEN step_5_billing ELSE 0 END) * 100.0 / NULLIF(SUM(CASE WHEN viewed_mr_fuzzy = 1 THEN step_4_shipping ELSE 0 END), 0)) AS shipping_to_billing_percentage,
    (SUM(CASE WHEN viewed_mr_fuzzy = 1 THEN step_6_thank_you ELSE 0 END) * 100.0 / NULLIF(SUM(CASE WHEN viewed_mr_fuzzy = 1 THEN step_5_billing ELSE 0 END), 0)) AS billing_to_thank_you_percentage
FROM product_sessions
WHERE viewed_mr_fuzzy = 1
UNION ALL
SELECT 
    'The Forever Love Bear' AS product_name,
    SUM(step_1_products) AS products_page_sessions,
    SUM(viewed_forever_love_bear) AS product_page_sessions,
    SUM(CASE WHEN viewed_forever_love_bear = 1 THEN step_3_cart ELSE 0 END) AS cart_page_sessions,
    SUM(CASE WHEN viewed_forever_love_bear = 1 THEN step_4_shipping ELSE 0 END) AS shipping_page_sessions,
    SUM(CASE WHEN viewed_forever_love_bear = 1 THEN step_5_billing ELSE 0 END) AS billing_page_sessions,
    SUM(CASE WHEN viewed_forever_love_bear = 1 THEN step_6_thank_you ELSE 0 END) AS thank_you_page_sessions,
    (SUM(viewed_forever_love_bear) * 100.0 / NULLIF(SUM(step_1_products), 0)) AS products_to_product_percentage,
    (SUM(CASE WHEN viewed_forever_love_bear = 1 THEN step_3_cart ELSE 0 END) * 100.0 / NULLIF(SUM(viewed_forever_love_bear), 0)) AS product_to_cart_percentage,
    (SUM(CASE WHEN viewed_forever_love_bear = 1 THEN step_4_shipping ELSE 0 END) * 100.0 / NULLIF(SUM(CASE WHEN viewed_forever_love_bear = 1 THEN step_3_cart ELSE 0 END), 0)) AS cart_to_shipping_percentage,
    (SUM(CASE WHEN viewed_forever_love_bear = 1 THEN step_5_billing ELSE 0 END) * 100.0 / NULLIF(SUM(CASE WHEN viewed_forever_love_bear = 1 THEN step_4_shipping ELSE 0 END), 0)) AS shipping_to_billing_percentage,
    (SUM(CASE WHEN viewed_forever_love_bear = 1 THEN step_6_thank_you ELSE 0 END) * 100.0 / NULLIF(SUM(CASE WHEN viewed_forever_love_bear = 1 THEN step_5_billing ELSE 0 END), 0)) AS billing_to_thank_you_percentage
FROM product_sessions
WHERE viewed_forever_love_bear = 1;

/***********************************
--- avg profit per usd ( 3 tables )
*************************************/
SELECT 
    (SUM(oi.price_usd - oi.cogs_usd - COALESCE(r.refund_amount_usd, 0)) * 1.0) 
    / COUNT(DISTINCT o.user_id) AS avg_profit_per_user
FROM 
    orders o
JOIN 
    order_items oi ON o.order_id = oi.order_id
 left JOIN 
    order_item_refunds r ON oi.order_item_id = r.order_item_id;


/***************************************************************
----Bounce rate of session (session with 1 page visit / total sessions)
********************************************************************/
SELECT COUNT(Y.website_session_id)*100.0/(SELECT COUNT( DISTINCT website_session_id) 
FROM website_pageviews) AS Bounce_rate
FROM 
(
SELECT website_session_id, COUNT(website_pageview_id) AS Cnt_ FROM website_pageviews
GROUP BY website_session_id
having COUNT(website_pageview_id)= 1
) AS Y

/***************************************
---BOunce rate of each page
****************************************/

WITH first_pageviews AS (
    SELECT 
        website_session_id, 
        pageview_url,
        ROW_NUMBER() OVER(PARTITION BY website_session_id ORDER BY created_at) AS row_num,
        COUNT(*) OVER(PARTITION BY website_session_id) AS session_pageviews
    FROM 
        website_pageviews
)

SELECT 
    pageview_url,
    COUNT(CASE WHEN session_pageviews = 1 THEN 1 END) * 100.0 / COUNT(*) AS Bounce_rate 
FROM 
    first_pageviews
WHERE 
    row_num = 1  -- Only consider the first pageview in each session
GROUP BY 
    pageview_url;


/****************************************************************************************
-- What are the bounce rates for \lander-1 and \home in the A/B test conducted by ST for the 
--gsearch nonbrand campaign, considering traffic received by \lander-1 and \home before <2012-07-28 to 
-- ensure a fair comparison?
***************************************************************************************/
WITH all_sessions AS (
    -- Count all pageviews per session across all pages
    SELECT 
        ws.website_session_id,
        COUNT(wp.website_pageview_id) AS pageviews_per_session
    FROM website_sessions ws
    JOIN website_pageviews wp ON ws.website_session_id = wp.website_session_id
    WHERE 
        ws.utm_source = 'gsearch'
        AND ws.utm_campaign = 'nonbrand'
        AND ws.created_at < '2012-07-28'
    GROUP BY ws.website_session_id
),
landing_page_sessions AS (
    -- Filter to sessions that contain /lander-1 or /home at least once
    SELECT 
        wp.pageview_url,
        ws.website_session_id,
        all_sessions.pageviews_per_session
    FROM website_sessions ws
    JOIN website_pageviews wp ON ws.website_session_id = wp.website_session_id
    JOIN all_sessions ON ws.website_session_id = all_sessions.website_session_id
    WHERE 
        wp.pageview_url IN ('/lander-1', '/home')
)
SELECT 
    pageview_url,
    COUNT(*) AS total_sessions,
    SUM(CASE WHEN pageviews_per_session = 1 THEN 1 ELSE 0 END) AS bounce_sessions,
    (SUM(CASE WHEN pageviews_per_session = 1 THEN 1 ELSE 0 END) * 100.0) / COUNT(*) AS bounce_rate
FROM landing_page_sessions
GROUP BY pageview_url;


/**************************************************************************************************
First purchase session vs repeat purchase session by traffic time (from 2014)
****************************************************************************************************/
	WITH customer_visits AS (
    -- Identify if the session is a customer's first visit
    SELECT
        o.user_id,
        ws.website_session_id,
        MIN(ws.created_at) OVER (PARTITION BY o.user_id) AS first_visit_date,
        ws.created_at AS session_date,
        CASE
            WHEN MIN(ws.created_at) OVER (PARTITION BY o.user_id) = ws.created_at THEN 'First Visit'
            ELSE 'Repeat Visit'
        END AS visit_type
    FROM
        orders o
    JOIN
        website_sessions ws ON o.website_session_id = ws.website_session_id
    WHERE
        ws.created_at >= '2014-01-01'
),
traffic_analysis AS (
    -- Categorize traffic sources for each session
    SELECT
        cv.visit_type,
        CASE
            WHEN ws.utm_source = 'null' AND ws.http_referer = 'null' THEN 'Direct Type-In'
            WHEN ws.utm_source != 'null' THEN 'Paid Ad'
            WHEN ws.utm_source = 'null' AND ws.http_referer != 'null' THEN 'Organic Search'
        END AS traffic_type
    FROM
        customer_visits cv
    JOIN
        website_sessions ws ON cv.website_session_id = ws.website_session_id
),
visit_summary AS (
    -- Count visits by type and traffic source
    SELECT
        visit_type,
        traffic_type,
        COUNT(*) AS visit_count
    FROM
        traffic_analysis
    WHERE
        traffic_type IN ('Direct Type-In', 'Paid Ad', 'Organic Search')
    GROUP BY
        visit_type, traffic_type
),
total_visits AS (
    -- Total visits by type
    SELECT
        visit_type,
        SUM(visit_count) AS total_count
    FROM
        visit_summary
    GROUP BY
        visit_type
)
-- Final output with percentages
SELECT
    vs.visit_type,
    vs.traffic_type,
    vs.visit_count,
    ROUND((vs.visit_count * 1.0 / tv.total_count * 100), 10) AS visit_percentage
FROM
    visit_summary vs
JOIN
    total_visits tv
ON
    vs.visit_type = tv.visit_type
ORDER BY
    visit_type, traffic_type;

/*****************************************************************************************
--Product Pathing Analysis: What are the clickthrough rates from /products since the new product launch on January 6th 2013,by 
--product and compare to the 3 months leading up to launch as a baseline?
************************************************************************************************/
WITH SessionPageCounts AS (
    SELECT 
        website_session_id,
        COUNT(pageview_url) AS total_pages,
        CASE 
            WHEN MIN(created_at) BETWEEN '2012-10-06' AND '2013-01-05' THEN 'Baseline'
            WHEN MIN(created_at) BETWEEN '2013-01-06' AND '2013-04-05' THEN 'Post-Launch'
        END AS period
    FROM 
        website_pageviews
    GROUP BY 
        website_session_id
),
SessionSummary AS (
    SELECT 
        period,
        SUM(CASE WHEN total_pages > 1 THEN 1 ELSE 0 END) AS sessions_with_more_than_1_page,
        SUM(CASE WHEN total_pages > 2 THEN 1 ELSE 0 END) AS sessions_with_more_than_2_pages,
        COUNT(*) AS total_sessions
    FROM 
        SessionPageCounts
    WHERE 
        period IS NOT NULL
    GROUP BY 
        period
)
SELECT 
    period,
    sessions_with_more_than_1_page,
    sessions_with_more_than_2_pages,
    (sessions_with_more_than_2_pages) * 100.0 / (sessions_with_more_than_1_page) AS clickthrough_rate
FROM 
    SessionSummary;


/*******************************************
---Cohort Analysis
*******************************************/
WITH FirstPurchase AS (
    SELECT
        user_id,
        MIN(created_at) AS first_purchase_date
    FROM
        orders
    GROUP BY
        user_id
),
Cohorts AS (
    SELECT
        DATEPART(YEAR, first_purchase_date) AS cohort_year,
        DATEPART(MONTH, first_purchase_date) AS cohort_month,
        COUNT(DISTINCT user_id) AS customer_count
    FROM
        FirstPurchase
    GROUP BY
        DATEPART(YEAR, first_purchase_date),
        DATEPART(MONTH, first_purchase_date)
)
SELECT
    cohort_year,
    cohort_month,
    customer_count
FROM
    Cohorts
ORDER BY
    cohort_year,
    cohort_month;


/**********************************************************************************
Pull a list of top entry pages?
****************************************************************************************/

SELECT 
    pageview_url,
    COUNT(website_session_id) AS Entry_Page_Sessions
FROM (
    SELECT 
        website_session_id,pageview_url,
        ROW_NUMBER() OVER (PARTITION BY website_session_id ORDER BY created_at) AS RowNum
    FROM 
        website_pageviews
) AS RankedPages
WHERE 
    RowNum = 1  -- Only the first page of the session
GROUP BY 
    pageview_url
ORDER BY 
    Entry_Page_Sessions DESC;



 /**********************************************************************************
Calculating Bounce Rates: Pull out the bounce rates for traffic landing on home page by sessions, 
bounced sessions and bounce rate?
****************************************************************************************/

	WITH bounced_sessions AS (
    SELECT 
        website_session_id
    FROM 
        website_pageviews
    GROUP BY 
        website_session_id
    HAVING 
        COUNT(pageview_url) = 1  -- Sessions with exactly 1 pageview
)
SELECT 
    COUNT(DISTINCT wp.website_session_id) AS session_cnt,  -- Total sessions landing on /home
    COUNT(DISTINCT bs.website_session_id) AS bounce_session,  -- Bounced sessions landing on /home
    COUNT(DISTINCT bs.website_session_id) * 100.0 / COUNT(DISTINCT wp.website_session_id) AS bounce_rate  -- Bounce rate percentage
FROM 
    website_pageviews AS wp
LEFT JOIN 
    bounced_sessions AS bs
ON 
    wp.website_session_id = bs.website_session_id
WHERE 
    wp.pageview_url = '/home';  -- Filter sessions landing on /home


	 /**********************************************************************************
Analyzing Landing Page Tests: What are the bounce rates for \lander-1 and \home in the A/B test conducted by ST for the gsearch 
nonbrand campaign, considering traffic received by \lander-1 and \home before <2012-07-28 to ensure a fair comparison?
****************************************************************************************/
with filtered_sessions as
	(select *
	from website_data 
	where utm_source='gsearch' and utm_campaign='nonbrand' and created_at < '2012-07-28' and pageview_url in('/lander-1','/home' ) ),

 session_count as 
	(select pageview_url,COUNT(distinct website_session_id) as total_sessions
	from filtered_sessions 
	group by pageview_url ),

 bounce_sessions as
( select pageview_url,COUNT(distinct website_session_id) as bounce_sessions from filtered_sessions
where website_session_id in(select website_session_id from website_data
group by website_session_id
having COUNT(pageview_url)=1)
group by pageview_url)

select t1.pageview_url,bounce_sessions*100/total_sessions as bounce_rate
from session_count as t1 join bounce_sessions as t2 on  t1.pageview_url=t2.pageview_url


		 /**********************************************************************************
Landing Page Trend Analysis: What is the trend of weekly paid gsearch nonbrand campaign traffic on /home and /lander-1 pages 
since June 1, 2012, along with their respective bounce rates, as requested by ST? Please limit the results to the period between 
June 1, 2012, and August 31, 2012, based on the email received on August 31, 2021.
****************************************************************************************/
select T1.*,(home_bounce_session * 100.0) / NULLIF(home_session, 0) AS home_bouncerate,
 (lander1_bounce_session * 100.0) / NULLIF(lander1_session, 0) AS lander1_bouncerate
	from
	(
	select DATEDIFF(week,'2012-06-01',created_at)+1 as week_number,
	 sum(case when pageview_url='/home' then 1 else 0 end) as home_session,
	 SUM(case when pageview_url ='/lander-1' then 1 else 0 end) as lander1_session
	 from website_data
		 where utm_source='gsearch' and utm_campaign='nonbrand'
		and pageview_url in ('/home','/lander-1')
		 AND created_at >='2012-06-01' AND created_at <='2012-08-31'
		group by DATEDIFF(week,'2012-06-01',created_at)
		) as t1 
		join


(select DATEDIFF(week,'2012-06-01',created_at)+1 as week_number,
 sum(case when pageview_url='/home' then 1 else 0 end) as home_bounce_session,
 SUM(case when pageview_url ='/lander-1' then 1 else 0 end) as lander1_bounce_session
 from website_data
	 where utm_source='gsearch' and utm_campaign='nonbrand'
	and pageview_url in ('/home','/lander-1')
	 AND created_at >='2012-06-01' AND created_at <='2012-08-31'
	 and website_session_id in
			(select website_session_id 
			from website_data 
			group by website_session_id 
			having COUNT(pageview_url)>1)
	group by DATEDIFF(week,'2012-06-01',created_at)
	) as t2 on t1.week_number=t2.week_number
	order by week_number


	/**********************************************************************************
Build Conversion Funnels for gsearch nonbrand traffic from /lander-1 to /thank you page: What are the session counts and click 
percentages for \lander-1, product, mrfuzzy, cart, shipping, billing, and thank you pages from August 5, 2012, to September 5, 
2012?
****************************************************************************************/

	SELECT M.*, M.Session_counts*100.0/LAG(M.Session_counts) OVER(ORDER BY M.Session_counts DESC)  AS Click_percentages 
FROM (
       SELECT   pageview_url, COUNT(DISTINCT   website_session_id) AS Session_counts
       FROM website_data
       WHERE   pageview_url IN ('/lander-1', '/products', '/the-original-mr-fuzzy', '/cart', '/shipping', '/billing', '/thank-you-for-your-order')
       AND created_at BETWEEN '2012-08-05' AND '2012-09-05'  
	   AND website_session_id IN ( SELECT website_session_id FROM website_pageviews
                                       WHERE pageview_url= '/lander-1')
       GROUP BY   pageview_url
       ) AS M

/**********************************************************************************
 Analyze Conversion Funnel Tests for /billing vs. new /billing-2 pages: what is the traffic and billing to order conversion rate of 
both pages new/billing-2 page?
****************************************************************************************/
select t2.*,order_count, order_count*100.0/session_count as  conversion_rate from
(
select pageview_url,COUNT(distinct website_session_id) as order_count from website_data 
where pageview_url in('/billing','/billing-2') and website_session_id in
	(select website_session_id from website_data where pageview_url='/thank-you-for-your-order')
	group by pageview_url) t1

	join

( select pageview_url,COUNT(distinct website_session_id) as session_count from website_data 
where pageview_url in('/billing','/billing-2') 
	group by pageview_url) as t2
	on t1. pageview_url=t2.pageview_url


	---
	/**********************************************************************************
 Analyze Conversion Funnel Tests for /billing vs. /billing-2 pages: 
 Compare traffic and billing-to-order conversion rates of both pages without using JOIN.
**********************************************************************************/

SELECT 
    pageview_url,
    SUM(CASE WHEN is_order THEN 1 ELSE 0 END) AS order_count,
    COUNT(DISTINCT website_session_id) AS session_count,
    (SUM(CASE WHEN is_order THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT website_session_id)) AS conversion_rate
FROM 
    (
        SELECT 
            pageview_url,
            website_session_id,
            CASE 
                WHEN website_session_id IN (
                    SELECT DISTINCT website_session_id 
                    FROM website_data 
                    WHERE pageview_url = '/thank-you-for-your-order'
                ) THEN 1 
                ELSE 0 
            END AS is_order
        FROM 
            website_data
        WHERE 
            pageview_url IN ('/billing', '/billing-2')
    ) AS temp_data
GROUP BY 
    pageview_url;


	
/**********************************************************************************
 Analyze Conversion Funnel Tests for /billing vs. /billing-2 pages: 
 Compare traffic and billing-to-order conversion rates of both pages without using JOIN.
**********************************************************************************/

-- Step 1: Create a Common Table Expression (CTE) to identify sessions that resulted in orders
WITH Orders AS (
    SELECT DISTINCT website_session_id
    FROM website_data
    WHERE pageview_url = '/thank-you-for-your-order'
),

-- Step 2: Calculate the session data with a flag for orders
SessionData AS (
    SELECT 
        pageview_url,
        website_session_id,
        CASE 
            WHEN website_session_id IN (SELECT website_session_id FROM Orders) THEN 1 
            ELSE 0 
        END AS is_order
    FROM 
        website_data
    WHERE 
        pageview_url IN ('/billing', '/billing-2')
)

-- Step 3: Aggregate the data for each page
SELECT 
    pageview_url,
    COUNT(DISTINCT website_session_id) AS session_count,
    SUM(is_order) AS order_count,
    (SUM(is_order) * 100.0 / COUNT(DISTINCT website_session_id)) AS conversion_rate
FROM 
    SessionData
GROUP BY 
    pageview_url;


	/**********************************************************************************
Analyzing Channel Portfolios: What are the weekly sessions data for both gsearch and bsearch from August 22nd to November 
29th?
****************************************************************************************/
SELECT 
    DATEDIFF(week, '2012-08-22', created_at) + 1 AS week_number, 
    sum(case when utm_source='gsearch' then 1 else 0 end) as gsearch_sessions,
	SUM(case when utm_source='bsearch' then 1 else 0 end) as bsearch_sessions
FROM 
    website_sessions
WHERE 
    utm_source IN ('gsearch', 'bsearch') 
    AND created_at BETWEEN '2012-08-22' AND '2012-11-29'
GROUP BY 
    DATEDIFF(week, '2012-08-22', created_at) + 1 
ORDER BY 
    week_number;


	/**********************************************************************************
	 Comparing Channel Characteristics: What are the mobile sessions data for non-brand campaigns of gsearch and bsearch from 
August 22nd to November 30th, including details such as utm_source, total sessions, mobile sessions, and the percentage of 
mobile sessions?
****************************************************************************************/
select t1.*, (mobile_sessions*100.0/total_sessions) as mobile_session_percentage from 
	(select utm_source,COUNT(website_session_id) as total_sessions,
	SUM(case when device_type='mobile' then 1 else 0 end) as mobile_sessions
	from website_sessions
	where created_at between '2012-08-22' and '2012-11-30' and utm_source in('gsearch','bsearch') and utm_campaign ='nonbrand'
	group by utm_source) as t1


		/**********************************************************************************
	Cross-Channel Bid Optimization: provide the conversion rates from sessions to orders for non-brand campaigns of gsearch and 
bsearch by device type, for the period spanning from August 22nd to September 18th? Additionally, include details such as device 
type, utm_source, total sessions, total orders, and the corresponding conversion rates
****************************************************************************************/
select device_type,
	utm_source,
	COUNT(ws.website_session_id) as total_sessions,
	COUNT(order_id) as orders,
	COUNT( order_id)*100.0/COUNT(ws.website_session_id) as CVR
	from website_sessions as ws left join orders as o on ws.website_session_id=o.website_session_id
	where ws.created_at between '2012-08-22' and '2012-09-18' and utm_source in('gsearch','bsearch')
		and utm_campaign='nonbrand'
	group by device_type,utm_source


/**********************************************************************************
Channel Portfolio Trends: Retrieve the data for gsearch and bsearch non-brand sessions segmented by device type from 
November 4th to December 22nd? Additionally, include details such as the start date of each week, device type, utm_source, total 
sessions, bsearch comparision.
****************************************************************************************/
SELECT 
    DATEDIFF(week, '2012-11-4', created_at) + 1 AS week_num,
    SUM(CASE WHEN device_type = 'desktop' AND utm_source = 'gsearch' THEN 1 ELSE 0 END) AS gsearch_desktop_sessions,
    SUM(CASE WHEN device_type = 'mobile' AND utm_source = 'gsearch' THEN 1 ELSE 0 END) AS gsearch_mobile_sessions,
    SUM(CASE WHEN device_type = 'desktop' AND utm_source = 'bsearch' THEN 1 ELSE 0 END) AS bsearch_desktop_sessions,
    SUM(CASE WHEN device_type = 'mobile' AND utm_source = 'bsearch' THEN 1 ELSE 0 END) AS bsearch_mobile_sessions,
    COUNT(website_session_id) AS total_sessions -- Total sessions across all sources and devices
FROM 
    website_sessions
WHERE 
    utm_source IN ('gsearch', 'bsearch') 
    AND utm_campaign = 'nonbrand' 
    AND created_at BETWEEN '2012-11-4' AND '2012-12-22'
GROUP BY 
    DATEDIFF(week, '2012-11-4', created_at)
ORDER BY 
    week_num;



/**********************************************************************************
Analyzing Free Channels: Could you pull organic search , direct type in and paid brand sessions by month and show those sessions 
as a % of paid search non brand?
****************************************************************************************/

WITH flagged_sessions AS (
    SELECT 
        website_session_id,
        created_at,
        CASE 
            WHEN utm_source = 'Null' AND http_referer != 'Null' THEN 'organic search'
            WHEN utm_source = 'Null' AND http_referer = 'Null' THEN 'direct type'
            WHEN utm_source != 'Null' AND utm_campaign = 'brand' THEN 'paid_brand'
            WHEN utm_source != 'Null' AND utm_campaign = 'nonbrand' THEN 'paid_nonbrand'
        END AS traffic_source
    FROM 
        website_data
),

cte2 as 
(
SELECT 
    format(created_at,'yyyy-MM') AS session_month,
    traffic_source,
    COUNT(distinct website_session_id) AS session_count
FROM 
    flagged_sessions
WHERE 
    traffic_source IS NOT NULL
GROUP BY 
     format(created_at,'yyyy-MM'), traffic_source)

select session_month,
	 traffic_source,
	 session_count,
	 session_count *100.0 /
	 SUM(CASE WHEN traffic_source = 'paid_nonbrand' THEN session_count END) 
        OVER (partition by session_month) AS percentage_of_paid_nonbrand 
		from cte2
		
		

/**********************************************************************************
Analyzing Seasonality: Pull out sessions and orders by year, monthly and weekly for 2012?
****************************************************************************************/
---monthly sessions
SELECT  
    MONTH(ws.created_at) AS year_month,
    COUNT(ws.website_session_id) AS session_count, -- Counts all sessions, even those without orders
    COUNT(o.order_id) AS order_count              -- Counts only orders from matching sessions
FROM 
    website_sessions AS ws 
LEFT JOIN 
    Orders AS o 
    ON ws.website_session_id = o.website_session_id 
WHERE 
    YEAR(ws.created_at) = 2012 -- Only count sessions created in 2012
GROUP BY 
    MONTH(ws.created_at)
ORDER BY 
    year_month;


	--- weekly
		select DATEPART(week,ws.created_at) as week_num,
			count(ws.website_session_id) as website_sessions,
			COUNT(o.order_id) as orders
			from website_sessions as ws left join Orders as o on ws.website_session_id=o.website_session_id
			where year(ws.created_at)=2012
			group by DATEPART(week,ws.created_at)
			order by week_num

/**********************************************************************************
Analyzing Business Patterns: What is the average website session volume , categorized by hour of the day and day of the week, 
between September 15th and November 15th ,2013, excluding holidays to assist in determining appropriate staffing levels for live 
chat support on the website?
****************************************************************************************/
select DATEPART(hour,created_at) as hour_of_day,
	COUNT(website_session_id) *1.0/count(distinct CAST(created_at AS DATE)) as avg_session_count
	from website_sessions
	where created_at between '2013-09-15' and '2013-11-15'
	 and DATENAME(weekday,created_at) not in ('Saturday','Sunday')
	 group by  DATEPART(hour,created_at)
	 order by hour_of_day



---Weekday
	SELECT 
    DATENAME(WEEKDAY, created_at) AS day_of_week,
    COUNT(website_session_id) * 1.0 / COUNT(DISTINCT cast(created_at As date )) AS avg_sessions_per_day
FROM 
    website_sessions
WHERE 
    created_at BETWEEN '2013-09-15' AND '2013-11-15'
    AND DATENAME(WEEKDAY, created_at) NOT IN ('Saturday', 'Sunday')
GROUP BY 
    DATENAME(WEEKDAY, created_at),
    DATEPART(WEEKDAY, created_at) 
ORDER BY 
    DATEPART(WEEKDAY, created_at); 



/**********************************************************************************
 Product Level Sales Analysis: What is monthly trends to date for number of sales , total revenue and total margin generated for 
business?
****************************************************************************************/
 select FORMAT(created_at,'yyyy-MM') as year_month,count(order_id) as orders,SUM(price_usd) as revenue, sum(price_usd)-SUM(cogs_usd) as profit
from Orders
group by FORMAT(created_at,'yyyy-MM')
order by year_month


 /**********************************************************************************
 Product Launch Sales Analysis: Could you generate trended analysis including monthly order volume, overall conversion rates, 
revenue per session, and a breakdown of sales by product since April 1, 2013, considering the launch of the second product on 
January 6th?
****************************************************************************************/
SELECT 
    FORMAT(ws.created_at, 'yyyy-MM') AS year_month,
    COUNT(order_id) AS orders,
    COUNT(ws.website_session_id) AS session_count,
    ROUND(cast(COUNT(DISTINCT order_id ) as float) *100/ COUNT(ws.website_session_id), 2) AS CVR,
    ROUND(SUM(price_usd) / COUNT(ws.website_session_id), 2) AS revenue_per_session,
    CAST(SUM(CASE WHEN product_name = 'The Original Mr. Fuzzy' THEN price_usd ELSE 0 END) AS INT) AS Mr_Fuzzy_sales,
    CAST(SUM(CASE WHEN product_name = 'The Forever Love Bear' THEN price_usd ELSE 0 END) AS INT) AS Love_bear_sales,
    CAST(SUM(CASE WHEN product_name = 'The Birthday Sugar Panda' THEN price_usd ELSE 0 END) AS INT) AS Sugar_panda_sales,
    CAST(SUM(CASE WHEN product_name = 'The Hudson River Mini bear' THEN price_usd ELSE 0 END) AS INT) AS Mini_bear_sales
FROM
    Orders AS o 
    JOIN products AS p ON o.primary_product_id = p.product_id
    RIGHT JOIN website_sessions AS ws ON o.website_session_id = ws.website_session_id
WHERE
    ws.created_at > '2013-04-13'
GROUP BY
    FORMAT(ws.created_at, 'yyyy-MM')
ORDER BY
    year_month;


/**********************************************************************************
Product Pathing Analysis: What are the clickthrough rates from /products since the new product launch on January 6th 2013,by 
product and compare to the 3 months leading up to launch as a baseline?
****************************************************************************************/
 ---Union method
 
 WITH session_pageviews AS (
    -- Baseline sessions
    SELECT
        'Baseline' AS time_period,
        website_session_id,
        COUNT( pageview_url) AS pageview_count
    FROM website_pageviews
    WHERE created_at >= '2012-10-06' AND created_at < '2013-01-06'
    GROUP BY website_session_id

    UNION 

    -- Post Launch sessions
    SELECT
        'Post Launch' AS time_period,
        website_session_id,
        COUNT( pageview_url) AS pageview_count
    FROM website_pageviews
    WHERE created_at >= '2013-01-06' AND created_at < '2013-04-06'
    GROUP BY website_session_id
),

session_count as (
	SELECT
		time_period,
		COUNT(CASE WHEN pageview_count > 1 THEN 1 END) AS sessions_more_than_1_pageview,
		COUNT(CASE WHEN pageview_count > 2 THEN 1 END) AS sessions_more_than_2_pageview
		
	FROM session_pageviews
	GROUP BY time_period)

select time_period,
	sessions_more_than_1_pageview,
	sessions_more_than_2_pageview,
	sessions_more_than_2_pageview *100.0/sessions_more_than_1_pageview as CTR
	from session_count



/**********************************************************************************
 Product Conversion Funnels: provide a comparison of the conversion funnels from the 
 product pages to conversion for two products since January 6th, analyzing all website traffic?
****************************************************************************************/

-----------------------MRFuzzy
with p1 as
	(select pageview_url,
	COUNT(pageview_url) as page_count
from website_pageviews
where created_at >='2013-01-06' and pageview_url in('/thank-you-for-your-order','/billing-2',
										'/shipping','/cart','/the-original-mr-fuzzy')
	  and website_session_id in (select website_session_id 
								from website_pageviews 
								where pageview_url in('/the-original-mr-fuzzy'))
group by pageview_url)


select pageview_url,
page_count,
page_count *100.0/ LAG(page_count) over (order by page_count desc) as CTR,
page_count*100.0/SUM(case when pageview_url='/the-original-mr-fuzzy' then page_count end) over () as CVR
from p1


--------------Forever Love bear
with p1 as
	(select pageview_url,
	COUNT(pageview_url) as page_count
from website_pageviews
where created_at >='2013-01-06' and pageview_url in('/thank-you-for-your-order','/billing-2',
										'/shipping','/cart','/the-forever-love-bear')
	  and website_session_id in (select website_session_id 
								from website_pageviews 
								where pageview_url in('/the-forever-love-bear'))
group by pageview_url)


select pageview_url,
page_count,
page_count *100.0/ LAG(page_count) over (order by page_count desc) as CTR,
page_count*100.0/SUM(case when pageview_url='/the-forever-love-bear' then page_count end) over () as CVR

from p1


/**********************************************************************************
Cross-Sell Analysis: Analyze the impact of offering customers the option to add a second product on the /cart page, comparing the 
metrics from the month before the change to the month after? Specifically, in comparing the click-through rate (CTR) from the 
/cart page, average products per order, average order value (AOV), and overall revenue per /cart page view
****************************************************************************************/
select MIN(created_at) from Orders
where items_purchased>1
--- We use above date

WITH flagged_sessions AS (
    SELECT 
        ws.website_session_id,
        CASE 
            WHEN ws.created_at >= '2013-08-25' AND ws.created_at < '2013-09-25' THEN 'pre_option'
            WHEN ws.created_at >= '2013-09-25' AND ws.created_at < '2013-10-25' THEN 'post_option'
        END AS flagged,
        max(CASE WHEN wp.pageview_url = '/cart' THEN 1 else 0 END) AS is_cart_session,
        max(CASE WHEN wp.pageview_url = '/shipping' THEN 1 else 0 end ) AS is_shipping_session
    FROM website_pageviews AS wp
    JOIN website_sessions AS ws 
        ON wp.website_session_id = ws.website_session_id
    WHERE ws.created_at >= '2013-08-25' AND ws.created_at < '2013-10-25'
	GROUP BY ws.website_session_id, ws.created_at

),

cte2 as (
	SELECT 
		flagged AS Time_period,
		sum(is_cart_session) AS cart_sessions,
		sum(is_shipping_session) AS shipping_sessions,
		SUM(o.items_purchased) * 1.0/ COUNT(DISTINCT o.order_id) AS avg_products_per_order,
		SUM(o.price_usd) / COUNT(DISTINCT o.order_id) AS avg_order_value,
		SUM(o.price_usd) / Count(is_cart_session) AS revenue_per_cart_view
	FROM flagged_sessions fs
	LEFT JOIN orders o 
		ON fs.website_session_id = o.website_session_id
	GROUP BY flagged)

select 
	time_period,
	shipping_sessions *100.0/cart_sessions as CTR_from_cart,
	avg_products_per_order,
	avg_order_value,
	revenue_per_cart_view
from cte2



/**********************************************************************************
Portfolio Expansion Analysis: Conduct a pre-post analysis comparing the month before and the month after the launch of the 
“Birthday Bear” product on December 12th, 2013? Specifically, containing the changes in session-to-order conversion rate, average 
order value (AOV), products per order, and revenue per session.
****************************************************************************************/
with flagged_sessions as
	(select website_session_id,
	case when created_at between '2013-11-12' and '2013-12-11' then 'Pre launch'
		 when created_at between '2013-12-12' and '2014-01-11' then 'Post launch' end as Time_period
	from website_sessions
	group by website_session_id,created_at)


	select time_period, 
	COUNT(order_id)*100.0/COUNT(fs.website_session_id) as CVR,
	SUM(price_usd)/COUNT(order_id) as AOV,
	SUM(items_purchased)*1.0/COUNT(order_id) as items_per_order,
	SUM(price_usd)/COUNT(fs.website_session_id) as revenue_per_session
	from flagged_sessions as fs left join orders as o on fs.website_session_id=o.website_session_id
	where time_period is not null
	group by TIME_period


/**********************************************************************************
 Product Refund Rates: What is monthly product refund rates, by product and confirm quality issues are now fixed?
 ****************************************************************************************/
   SELECT 
        FORMAT(order_created_at, 'yyyy-MM') AS year_month,
        product_name,
        SUM(refund_amount_usd) * 100.0 / SUM(price_usd) AS refund_rate
    FROM order_data
    GROUP BY FORMAT(order_created_at, 'yyyy-MM'), product_name
	order by year_month




	/**********************************************************************************
 Analyzing Repeat Behavior: What is the minimum , maximum and average time between the first and second session for 
customers who do come back? 2014 to date is good.
****************************************************************************************/

	WITH cte AS (
    SELECT 
        USER_ID,
		website_session_id,
        created_at,
        ROW_NUMBER() OVER (PARTITION BY USER_ID ORDER BY created_at) AS row_num
    FROM 
        website_sessions
    WHERE 
        YEAR(created_at) >= 2014
)
SELECT 
    MIN(DATEDIFF(day, first_session.created_at, second_session.created_at)) AS min_time_between_first_and_second,
    MAX(DATEDIFF(day, first_session.created_at, second_session.created_at)) AS max_time_between_first_and_second,
    AVG(DATEDIFF(day, first_session.created_at, second_session.created_at) * 1.0) AS avg_time_between_first_and_second
FROM 
    cte first_session
JOIN 
    cte second_session
ON 
    first_session.USER_ID = second_session.USER_ID
    AND first_session.row_num = 1
    AND second_session.row_num = 2;


/**********************************************************************************
 New Vs. Repeat Channel Patterns: Analyze the channels through which repeat customers return to our website, comparing them 
to new sessions? Specifically,  interested in understanding if repeat customers predominantly come through direct type-in or if 
there’s a significant portion that originates from paid search ads. This analysis should cover the period from the beginning of 2014 
to the present date
*************************************************************************************/
WITH cte1 AS (
  SELECT 
    USER_ID,
    website_session_id,
    CASE 
      WHEN ROW_NUMBER() OVER (PARTITION BY USER_ID ORDER BY created_at) = 1 THEN 'first_session'
      WHEN ROW_NUMBER() OVER (PARTITION BY USER_ID ORDER BY created_at) = 2 THEN 'repeat_session'
    END AS session_type
  FROM 
    orders
  WHERE 
    USER_ID IN (
      SELECT USER_ID 
      FROM orders 
      WHERE YEAR(created_at) >= 2014
      GROUP BY USER_ID 
      HAVING COUNT(order_id) > 1
    )
),
cte2 AS (
  SELECT 
    session_type,
    CASE WHEN utm_source = 'Null' AND http_referer = 'Null' THEN 1 END AS direct_type_in,
    CASE WHEN utm_source != 'Null' THEN 1 END AS paid_search_ads
  FROM 
    website_sessions ws
  JOIN 
    cte1 
  ON 
    ws.website_session_id = cte1.website_session_id
  WHERE 
    session_type IS NOT NULL
)
SELECT 
  session_type, 
  COUNT(direct_type_in) AS direct_type,
  COUNT(paid_search_ads) AS paid_search, 
  COUNT(direct_type_in) * 100.0 / COUNT(paid_search_ads) AS Ratio
FROM 
  cte2
GROUP BY 
  session_type;


/**********************************************************************************
New Vs. Repeat Performance: Provide analysis on comparison of conversion rates and revenue per session for repeat sessions vs new 
sessions?2014 to date is good
*************************************************************************************/
with cte as
(
select USER_ID, 
	website_session_id,
	case 
		when ROW_NUMBER()over(partition by user_id order by created_at)=1 then 'first session'
		when ROW_NUMBER() over (PARTITION by user_id order by created_at)>=2 then 'Repeat session' end as session_type
	from website_sessions 
	)

select session_type,
		count(o.order_id)*100.0/COUNT(cte.website_session_id) as CVR,
		SUM(price_usd)/COUNT(cte.website_session_id) as revenue_per_session
from cte left join Orders as o on cte.website_session_id=o.website_session_id
where session_type is not null
group by session_type


	

