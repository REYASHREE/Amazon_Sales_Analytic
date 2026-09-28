CREATE TABLE amazon_sales_optimized (
    index INT,
    Order_ID VARCHAR(50),
    Dates VARCHAR(15),                    -- or DATETIME if you have time
    Status VARCHAR(50),
    Fulfillment VARCHAR(50),
    Sales_Channel VARCHAR(100),
    Ship_service_levels VARCHAR(50),
    Styles VARCHAR(100),
    SKU VARCHAR(100),
    Category VARCHAR(100),
    Sizes VARCHAR(20),
    ASIN VARCHAR(20),
    CourierStatus VARCHAR(50),
    Qty INT,                      -- or DECIMAL if decimals
    currency VARCHAR(10),
    Amount DECIMAL(10,2),         -- for money values
    ship_states VARCHAR(50),
    ship_city VARCHAR(100),
    ship_postal_code VARCHAR(20),
    ship_country VARCHAR(50),
    promotions_ids VARCHAR(500),
    B2B VARCHAR(10),              -- or BOOLEAN if Yes/No
    Fullfilled_by VARCHAR(100)
);
Alter table amazon_sales_optimized add column Country_name VARCHAR(10);

Alter table amazon_sales_optimized Alter column  "index" type VARCHAR(10) ;
Alter table amazon_sales_optimized Alter column Qty  type VARCHAR(10) ;
Alter table amazon_sales_optimized Alter column Amount  type VARCHAR(15) ;
select * from amazon_sales_optimized;
Alter table amazon_sales_optimized Alter column Country_name  type VARCHAR(100);
Alter table amazon_sales_optimized Alter column  promotions_ids  type VARCHAR(1000);

Alter table amazon_sales_optimized Alter column  promotions_ids  type TEXT;

select count(*) from amazon_sales_optimized;

select * from amazon_sales_optimized 
limit 10;

/*
================================================================================
PROJECT 1: E-COMMERCE SALES PERFORMANCE ANALYSIS
================================================================================
Author: [Saransh Sharma]
Database: PostgreSQL
Dataset: Amazon Sales Data (128,976 orders)
Objective: Analyze sales performance, revenue distribution, and business trends

Business Questions Answered:
1. What is our total revenue and order volume?
2. How is revenue distributed across different order statuses?
3. What percentage of orders are successfully delivered?
4. What are our month-over-month growth trends?
5. What is the overall health of the business?
================================================================================
*/

-- ============================================================================
-- SECTION 1: DATA QUALITY & EXPLORATION
-- ============================================================================

-- Query 1: Check total number of rows imported
-- PURPOSE: Verify data import completeness
SELECT COUNT(*) as total_rows 
FROM amazon_sales_optimized;
-- EXPECTED: 128,976 rows


-- Query 2: Check for missing values in key columns
-- PURPOSE: Identify data quality issues that may affect analysis
-- INSIGHT: Understanding missing data helps us make informed decisions about data cleaning
SELECT 
    COUNT(*) - COUNT(order_id) - 1 as missing_order_id,
    COUNT(*) - COUNT(status) - 1 as missing_status,
    COUNT(*) - COUNT(amount) - 1 as missing_amount,
    COUNT(*) - COUNT(qty) - 1 as missing_qty
FROM amazon_sales_optimized;
-- KEY FINDING: 7,795 orders have missing amounts (6% of data)


-- Query 3: Examine all unique order statuses
-- PURPOSE: Understand the order lifecycle and categorize orders properly
-- BUSINESS IMPACT: Helps define which orders count as "successful sales"
SELECT DISTINCT status 
FROM amazon_sales_optimized
ORDER BY status;


-- Query 4: Count orders by status
-- PURPOSE: Distribution analysis - where do most orders end up?
-- INSIGHT: Shows funnel drop-offs and problem areas
SELECT 
    status, 
    COUNT(*) as order_count
FROM amazon_sales_optimized
GROUP BY status
ORDER BY order_count DESC;
-- KEY FINDING: 77,804 "Shipped" + 28,769 "Delivered" = 106K successful orders (82%)


-- Query 5: Identify orders with missing amounts by status
-- PURPOSE: Understand WHY amounts are missing - is there a pattern?
-- BUSINESS INSIGHT: Cancelled orders often lack finalized prices
SELECT 
    status,
    COUNT(*) as total_orders,
    COUNT(amount) as orders_with_amount,
    COUNT(*) - COUNT(amount) as missing_amount,
    ROUND((COUNT(*) - COUNT(amount))::NUMERIC / COUNT(*) * 100, 2) as missing_percentage
FROM amazon_sales_optimized
GROUP BY status
ORDER BY missing_amount DESC;
-- KEY FINDING: 41% of cancelled orders lack amounts (makes sense - never finalized)

-- Query 6: Order Status Distribution Analysis
-- PURPOSE: Provide granular breakdown of all order statuses with revenue and volume metrics
-- BUSINESS VALUE: Identifies operational bottlenecks and revenue distribution across fulfillment stages
SELECT 
    status,
    COUNT(*) as order_count,
    SUM(CAST(amount AS NUMERIC)) as total_revenue,
    ROUND(AVG(CAST(amount AS NUMERIC)), 2) as avg_order_value,
    ROUND(COUNT(*)::NUMERIC / 
          (SELECT COUNT(*) FROM amazon_sales_optimized WHERE status != 'Status') * 100, 2) 
        as percentage_of_orders
FROM amazon_sales_optimized
WHERE amount IS NOT NULL
    AND amount ~ '^[0-9]+\.?[0-9]*$'
    AND status != 'Status'
GROUP BY status
ORDER BY order_count DESC;
-- KEY FINDINGS:
-- 1. "Shipped" status has 77,804 orders (60.3%) = ₹51.6M - largest volume
-- 2. Only 28,769 orders (22.3%) fully delivered = operational efficiency concern
-- 3. 18,332 cancellations (14.2%) = ₹6.6M lost - needs root cause analysis
-- 4. Average order value consistent across statuses (~₹613-663) = no value bias
-- INSIGHT: 60% of orders stuck in "Shipped" status suggests delivery tracking/completion issues
-- RECOMMENDATION: Investigate why orders stay in "Shipped" vs progressing to "Delivered"
-- ============================================================================
-- SECTION 2: REVENUE ANALYSIS
-- ============================================================================

-- Query 6: Calculate total successful revenue by status
-- PURPOSE: Measure actual revenue generated from completed/in-transit orders
-- BUSINESS DEFINITION: "Successful" = Shipped, Delivered, Out for Delivery, Picked Up
-- RATIONALE: These represent committed sales where product has left warehouse
SELECT 
    status,
    COUNT(*) as order_count,
    SUM(CAST(amount AS NUMERIC)) as status_revenue,
    ROUND(AVG(CAST(amount AS NUMERIC)), 2) as avg_order_value
FROM amazon_sales_optimized
WHERE status IN ('Shipped', 'Shipped - Picked Up', 'Shipped - Out for Delivery', 'Shipped - Delivered to Buyer')
    AND amount IS NOT NULL
    AND amount ~ '^[0-9]+\.?[0-9]*$'  -- Regex: ensures valid numeric values
GROUP BY status
ORDER BY status_revenue DESC;
-- KEY INSIGHT: ₹69.6M total successful revenue from 107K orders



-- Query 7: Revenue breakdown with percentage contribution
-- PURPOSE: Show which status contributes most to total revenue
-- BUSINESS VALUE: Helps prioritize operational focus areas
SELECT 
    status,
    COUNT(*) as order_count,
    SUM(CAST(amount AS NUMERIC)) as status_revenue,
    ROUND(AVG(CAST(amount AS NUMERIC)), 2) as avg_order_value,
    ROUND((SUM(CAST(amount AS NUMERIC)) / 69663293 * 100), 2) as revenue_percentage
FROM amazon_sales_optimized
WHERE status IN ('Shipped', 'Shipped - Picked Up', 'Shipped - Out for Delivery', 'Shipped - Delivered to Buyer')
    AND amount IS NOT NULL
    AND amount ~ '^[0-9]+\.?[0-9]*$'
GROUP BY status
ORDER BY status_revenue DESC;
-- KEY FINDING: "Shipped" status alone contributes 74.1% of total revenue (₹51.6M)


-- ============================================================================
-- SECTION 3: ORDER LIFECYCLE CATEGORIZATION
-- ============================================================================

-- Query 8: Categorize all orders into business-meaningful buckets
-- PURPOSE: Create a high-level view of order health
-- CATEGORIES:
--   - Delivered: Successfully completed
--   - In-Transit: Currently being shipped (future revenue at risk)
--   - Pre-Delivery Problems: Never shipped (cancelled, lost, rejected)
--   - Post-Delivery Problems: Shipped but returned/damaged
SELECT
    CASE 
        WHEN status IN ('Shipped - Delivered to Buyer') THEN 'Delivered'
        WHEN status IN ('Shipped', 'Shipped - Picked Up', 'Shipped - Out for Delivery', 
                        'Pending - Waiting for Pick Up', 'Pending') THEN 'In-Transit'
        WHEN status IN ('Cancelled', 'Shipped - Lost in Transit', 'Shipped - Rejected by Buyer') 
            THEN 'Pre-Delivery Problems'
        WHEN status IN ('Shipped - Returned to Seller', 'Shipped - Damaged', 
                        'Shipped - Returning to Seller') THEN 'Post-Delivery Problems'
        ELSE 'Other'
    END AS revenue_category,
    COUNT(*) as order_count,
    SUM(CAST(amount AS NUMERIC)) as total_revenue,
    ROUND(SUM(CAST(amount AS NUMERIC)) / 
          (SELECT SUM(CAST(amount AS NUMERIC)) 
           FROM amazon_sales_optimized 
           WHERE amount IS NOT NULL AND amount ~ '^[0-9]+\.?[0-9]*$') * 100, 2) 
        AS revenue_percentage
FROM amazon_sales_optimized
WHERE amount IS NOT NULL
    AND amount ~ '^[0-9]+\.?[0-9]*$'
GROUP BY revenue_category
ORDER BY total_revenue DESC;
-- KEY INSIGHTS:
-- Delivered: ₹18.6M (26.7%) - Confirmed successful revenue
-- In-Transit: ₹51.6M (73.3%) - At-risk revenue (not yet delivered)
-- Pre-Delivery Problems: ₹6.9M lost before shipping
-- Post-Delivery Problems: ₹2.3M lost after shipping


-- ============================================================================
-- SECTION 4: TIME TREND ANALYSIS
-- ============================================================================

-- Query 9: Month-over-month growth analysis
-- PURPOSE: Identify business trends, seasonality, and growth/decline patterns
-- BUSINESS VALUE: Critical for forecasting and strategic planning
-- TECHNIQUE: Uses LAG window function to compare current month vs previous month
WITH monthly_data AS (
    SELECT 
        DATE_TRUNC('month', TO_DATE(dates, 'MM/DD/YYYY')) AS order_month,
        COUNT(*) AS monthly_orders,
        SUM(CAST(amount AS NUMERIC)) AS monthly_revenue,
        ROUND(AVG(CAST(amount AS NUMERIC)), 2) AS avg_order_value
    FROM amazon_sales_optimized
    WHERE amount IS NOT NULL
      AND amount ~ '^[0-9]+\.?[0-9]*$'
      AND dates != 'Date'  -- Exclude header row
      AND dates IS NOT NULL
      AND TO_DATE(dates, 'MM/DD/YYYY') >= '2022-04-01'  -- Filter valid date range
    GROUP BY order_month
)
SELECT 
    order_month,
    monthly_orders,
    monthly_revenue,
    avg_order_value,
    LAG(monthly_orders) OVER (ORDER BY order_month) AS prev_month_orders,
    ROUND(
        ((monthly_orders - LAG(monthly_orders) OVER (ORDER BY order_month))::NUMERIC /
         NULLIF(LAG(monthly_orders) OVER (ORDER BY order_month), 0) * 100), 
    2) AS order_growth_percent,
    ROUND(
        ((monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY order_month))::NUMERIC /
         NULLIF(LAG(monthly_revenue) OVER (ORDER BY order_month), 0) * 100), 
    2) AS revenue_growth_percent,
    ROUND(
        ((avg_order_value - LAG(avg_order_value) OVER (ORDER BY order_month))::NUMERIC /
         NULLIF(LAG(avg_order_value) OVER (ORDER BY order_month), 0) * 100), 
    2) AS aov_growth_percent
FROM monthly_data
ORDER BY order_month;
-- KEY FINDING: Concerning -10.43% monthly decline in recent months
-- RECOMMENDATION: Investigate causes - marketing, competition, seasonality?


-- ============================================================================
-- SECTION 5: BUSINESS HEALTH DASHBOARD (EXECUTIVE SUMMARY)
-- ============================================================================

-- Query 10: Key Performance Indicators (KPIs) Summary
-- PURPOSE: Single-view dashboard for stakeholders
-- USAGE: Present to management for quick business health check
SELECT 
    'Total Revenue (₹)' as kpi_metric,
    TO_CHAR(ROUND(SUM(CAST(amount AS NUMERIC)), 2), 'FM999,999,999.00') as value,
    'All orders with valid amounts' as definition
FROM amazon_sales_optimized 
WHERE amount IS NOT NULL 
    AND amount ~ '^[0-9]+\.?[0-9]*$'

UNION ALL

SELECT 
    'Total Orders',
    TO_CHAR(COUNT(*), 'FM999,999'),
    'All non-header rows'
FROM amazon_sales_optimized
WHERE status != 'Status'

UNION ALL

SELECT 
    'Successful Delivery Rate (%)',
    TO_CHAR(ROUND((SUM(CASE WHEN status = 'Shipped - Delivered to Buyer' THEN 1 ELSE 0 END)::NUMERIC / 
           NULLIF(COUNT(*), 0) * 100), 2), 'FM999.00'),
    'Delivered orders / Total orders'
FROM amazon_sales_optimized
WHERE status != 'Status'

UNION ALL

SELECT 
    'Average Order Value (₹)',
    TO_CHAR(ROUND(AVG(CAST(amount AS NUMERIC)), 2), 'FM999,999.00'),
    'Mean revenue per order'
FROM amazon_sales_optimized
WHERE amount IS NOT NULL 
    AND amount ~ '^[0-9]+\.?[0-9]*$'

UNION ALL

SELECT 
    'Cancellation Rate (%)',
    TO_CHAR(ROUND((SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END)::NUMERIC / 
           NULLIF(COUNT(*), 0) * 100), 2), 'FM999.00'),
    'Cancelled orders / Total orders'
FROM amazon_sales_optimized
WHERE status != 'Status'

UNION ALL

SELECT 
    'In-Transit Revenue (₹)',
    TO_CHAR(ROUND(SUM(CAST(amount AS NUMERIC)), 2), 'FM999,999,999.00'),
    'Revenue not yet delivered (at risk)'
FROM amazon_sales_optimized
WHERE status IN ('Shipped', 'Shipped - Picked Up', 'Shipped - Out for Delivery')
    AND amount IS NOT NULL 
    AND amount ~ '^[0-9]+\.?[0-9]*$';

-- ============================================================================
-- KEY INSIGHTS & RECOMMENDATIONS (PROJECT 1)
-- ============================================================================
/*
MAJOR FINDINGS:
1. ✅ Total Revenue: ₹79.4M across 128K+ orders
2. ✅ Successful Delivery: Only 22.3% fully delivered (28,769 orders)
3. ⚠️  In-Transit Risk: ₹51.6M (65%) still in transit - not confirmed revenue
4. 📉 Declining Trend: -10.43% month-over-month decline (alarming!)
5. ❌ Cancellation Rate: 14.2% (18,332 cancelled orders)

BUSINESS RECOMMENDATIONS:
1. URGENT: Investigate monthly decline - marketing issue or seasonal?
2. Reduce in-transit time - 73% of revenue is at risk until delivered
3. Lower 14% cancellation rate - analyze reasons (payment, availability?)
4. Improve average order value (₹615) through upselling/bundles
5. Focus on conversion optimization - only 22% reach delivered status

NEXT STEPS:
→ See Project 2 for deep-dive into failure analysis and risk mitigation
→ Implement tracking for delivery times and bottlenecks
→ A/B test strategies to reduce cancellations






================================================================================
PROJECT 2: E-COMMERCE RISK & FAILURE ANALYSIS
================================================================================
Author: [Your Name]
Database: PostgreSQL
Dataset: Amazon Sales Data (128,976 orders)
Objective: Deep-dive analysis of order failures, losses, and operational risks

Business Questions Answered:
1. How much revenue is lost due to pre-delivery failures?
2. How much is lost to post-delivery returns/damages?
3. What is our expected revenue after accounting for risk?
4. Which product categories have highest failure rates?
5. Are there geographic patterns in delivery failures?
6. What is the financial impact of operational problems?

Risk Framework:
- PRE-DELIVERY: Orders that fail before shipment (Cancelled, Lost, Rejected)
- POST-DELIVERY: Orders that fail after delivery (Returns, Damages)
- IN-TRANSIT RISK: Current orders at risk based on historical success rates
================================================================================
*/

-- ============================================================================
-- SECTION 1: PRE-DELIVERY RISK ANALYSIS
-- ============================================================================

-- Query 1: Calculate revenue lost BEFORE delivery
-- PURPOSE: Quantify financial impact of orders that never reached customers
-- BUSINESS IMPACT: These represent operational inefficiencies or customer issues
-- CATEGORIES:
--   - Cancelled: Customer/seller cancelled before shipping
--   - Lost in Transit: Package lost by courier
--   - Rejected by Buyer: Customer refused delivery
--   - Pending: Stuck in processing (potential system issues)

SELECT 
    status,
    COUNT(*) as problem_order_count,
    SUM(CAST(amount AS NUMERIC)) as lost_revenue,
    ROUND(AVG(CAST(amount AS NUMERIC)), 2) as avg_order_value,
    ROUND(SUM(CAST(amount AS NUMERIC)) / 
          (SELECT SUM(CAST(amount AS NUMERIC)) 
           FROM amazon_sales_optimized 
           WHERE amount IS NOT NULL AND amount ~ '^[0-9]+\.?[0-9]*$') * 100, 2) 
        AS percent_of_total_revenue
FROM amazon_sales_optimized
WHERE status IN ('Cancelled', 'Shipped - Lost in Transit', 'Shipped - Rejected by Buyer', 
                 'Pending', 'Pending - Waiting for Pick Up', 'Shipping')
    AND amount IS NOT NULL
    AND amount ~ '^[0-9]+\.?[0-9]*$'
GROUP BY status
ORDER BY lost_revenue DESC;
-- KEY FINDING: ₹6.9M lost in pre-delivery failures
-- BIGGEST CULPRIT: Cancelled orders (₹6.6M / 10,766 orders)


-- Query 2: Aggregate pre-delivery risk metrics
-- PURPOSE: Single number for total pre-delivery losses
-- EXECUTIVE SUMMARY: "How much did we lose before shipping?"
SELECT 
    'Pre-Delivery Problems' as risk_category,
    COUNT(*) as total_problem_orders,
    SUM(CAST(amount AS NUMERIC)) as total_lost_revenue,
    ROUND(AVG(CAST(amount AS NUMERIC)), 2) as avg_lost_order_value
FROM amazon_sales_optimized
WHERE status IN ('Cancelled', 'Shipped - Lost in Transit', 'Shipped - Rejected by Buyer', 
                 'Pending', 'Pending - Waiting for Pick Up')
    AND amount IS NOT NULL
    AND amount ~ '^[0-9]+\.?[0-9]*$';
-- RESULT: ₹6,858,621 lost across 11,426 orders
-- IMPACT: 8.6% of total revenue never materialized


-- ============================================================================
-- SECTION 2: POST-DELIVERY RISK ANALYSIS
-- ============================================================================

-- Query 3: Calculate revenue lost AFTER delivery
-- PURPOSE: Quantify costs of returns, damages, and customer dissatisfaction
-- BUSINESS IMPACT: These cost MORE than cancellations (shipping + handling + restocking)
-- CATEGORIES:
--   - Returned to Seller: Customer returned product
--   - Damaged: Product damaged in transit/delivery
--   - Returning to Seller: Return in progress
SELECT 
    status,
    COUNT(*) as problem_order_count,
    SUM(CAST(amount AS NUMERIC)) as lost_revenue,
    ROUND(AVG(CAST(amount AS NUMERIC)), 2) as avg_order_value,
    ROUND(SUM(CAST(amount AS NUMERIC)) / 
          (SELECT SUM(CAST(amount AS NUMERIC)) 
           FROM amazon_sales_optimized 
           WHERE amount IS NOT NULL AND amount ~ '^[0-9]+\.?[0-9]*$') * 100, 2) 
        AS percent_of_total_revenue
FROM amazon_sales_optimized
WHERE status IN ('Shipped - Returned to Seller', 'Shipped - Damaged', 
                 'Shipped - Returning to Seller')
    AND amount IS NOT NULL
    AND amount ~ '^[0-9]+\.?[0-9]*$'
GROUP BY status
ORDER BY lost_revenue DESC;
-- KEY FINDING: ₹2.3M lost in post-delivery problems
-- CONCERN: Returns cost MORE than the product value (reverse logistics!)


-- Query 4: Aggregate post-delivery risk metrics
-- PURPOSE: Total cost of returns and damages
-- HIDDEN COSTS: Shipping both ways + restocking + damaged inventory write-offs
SELECT 
    'Post-Delivery Problems' as risk_category,
    COUNT(*) as total_problem_orders,
    SUM(CAST(amount AS NUMERIC)) as total_lost_revenue,
    ROUND(AVG(CAST(amount AS NUMERIC)), 2) as avg_lost_order_value
FROM amazon_sales_optimized
WHERE status IN ('Shipped - Returned to Seller', 'Shipped - Damaged', 
                 'Shipped - Returning to Seller')
    AND amount IS NOT NULL
    AND amount ~ '^[0-9]+\.?[0-9]*$';
-- RESULT: ₹2,296,790 lost across 2,098 orders
-- ACTUAL COST: Likely 1.5-2x this amount when including logistics


-- ============================================================================
-- SECTION 3: RISK-ADJUSTED REVENUE FORECASTING
-- ============================================================================

-- Query 5: Calculate historical success rate
-- PURPOSE: What percentage of orders that ship actually get delivered successfully?
-- METHODOLOGY: Delivered orders / (Delivered + All Problems)
-- USE CASE: Apply this rate to in-transit inventory for realistic revenue forecast
SELECT 
    SUM(CASE WHEN status = 'Shipped - Delivered to Buyer' THEN 1 ELSE 0 END) as delivered_orders,
    SUM(CASE WHEN status IN ('Shipped - Delivered to Buyer', 
                             'Cancelled', 
                             'Shipped - Lost in Transit', 
                             'Shipped - Rejected by Buyer',
                             'Shipped - Returned to Seller', 
                             'Shipped - Damaged', 
                             'Shipped - Returning to Seller') 
        THEN 1 ELSE 0 END) as total_completed_orders,
    ROUND((SUM(CASE WHEN status = 'Shipped - Delivered to Buyer' THEN 1 ELSE 0 END)::NUMERIC /
           NULLIF(SUM(CASE WHEN status IN ('Shipped - Delivered to Buyer', 
                                           'Cancelled', 
                                           'Shipped - Lost in Transit', 
                                           'Shipped - Rejected by Buyer',
                                           'Shipped - Returned to Seller', 
                                           'Shipped - Damaged', 
                                           'Shipped - Returning to Seller') 
                      THEN 1 ELSE 0 END), 0) * 100), 2) as success_rate_percent
FROM amazon_sales_optimized;
-- RESULT: 72.91% success rate
-- INTERPRETATION: Only 73% of orders complete successfully!


-- Query 6: Apply risk adjustment to in-transit revenue
-- PURPOSE: Calculate REALISTIC expected revenue from current in-transit orders
-- BUSINESS VALUE: Prevents overestimating revenue in financial forecasts
-- FORMULA: In-Transit Revenue × Historical Success Rate = Expected Revenue
WITH risk_metrics AS (
    SELECT 
        SUM(CAST(amount AS NUMERIC)) as in_transit_revenue,
        0.7291 as historical_success_rate  -- 72.91% from Query 5
    FROM amazon_sales_optimized
    WHERE status IN ('Shipped', 'Shipped - Picked Up', 'Shipped - Out for Delivery')
        AND amount IS NOT NULL
        AND amount ~ '^[0-9]+\.?[0-9]*$'
)
SELECT 
    TO_CHAR(in_transit_revenue, 'FM999,999,999.00') as current_in_transit_revenue,
    TO_CHAR(ROUND(in_transit_revenue * historical_success_rate, 2), 'FM999,999,999.00') 
        as expected_successful_revenue,
    TO_CHAR(ROUND(in_transit_revenue * (1 - historical_success_rate), 2), 'FM999,999,999.00') 
        as potential_revenue_loss,
    ROUND(historical_success_rate * 100, 2) || '%' as confidence_level
FROM risk_metrics;
-- KEY INSIGHT: 
-- In-Transit: ₹51.6M
-- Expected Revenue: ₹37.6M (73% confidence)
-- Potential Loss: ₹14.0M (27% may fail based on historical patterns)
-- ACTION: Reserve ₹14M for potential refunds/write-offs


-- Query 7: Risk-adjusted total business revenue
-- PURPOSE: What is our TRUE expected revenue after accounting for failures?
-- FORMULA: Delivered Revenue + (In-Transit × Success Rate)
SELECT 
    TO_CHAR(SUM(CASE WHEN status = 'Shipped - Delivered to Buyer' 
                THEN CAST(amount AS NUMERIC) ELSE 0 END), 'FM999,999,999.00') 
        as confirmed_delivered_revenue,
    TO_CHAR(SUM(CASE WHEN status IN ('Shipped', 'Shipped - Picked Up', 'Shipped - Out for Delivery') 
                THEN CAST(amount AS NUMERIC) ELSE 0 END) * 0.7291, 'FM999,999,999.00') 
        as expected_in_transit_revenue,
    TO_CHAR(SUM(CASE WHEN status = 'Shipped - Delivered to Buyer' 
                THEN CAST(amount AS NUMERIC) ELSE 0 END) +
            (SUM(CASE WHEN status IN ('Shipped', 'Shipped - Picked Up', 'Shipped - Out for Delivery') 
                THEN CAST(amount AS NUMERIC) ELSE 0 END) * 0.7291), 'FM999,999,999.00') 
        as total_risk_adjusted_revenue
FROM amazon_sales_optimized
WHERE amount IS NOT NULL
    AND amount ~ '^[0-9]+\.?[0-9]*$';
-- REALISTIC REVENUE FORECAST: ₹56.3M (not ₹69.6M!)
-- DIFFERENCE: ₹13.3M is optimistic overestimation


-- ============================================================================
-- SECTION 4: CATEGORY-LEVEL FAILURE ANALYSIS
-- ============================================================================

-- Query 8: Identify product categories with highest failure rates
-- PURPOSE: Find which products are causing the most problems
-- BUSINESS ACTION: Investigate suppliers, quality issues, or customer expectations mismatch
-- METHODOLOGY: (Failed Orders / Total Orders) × 100
SELECT  
    category, 
    COUNT(*) as total_orders,
    SUM(CASE WHEN status = 'Shipped - Delivered to Buyer' THEN 1 ELSE 0 END) 
        as successful_deliveries,
    SUM(CASE WHEN status IN ('Cancelled', 'Shipped - Lost in Transit', 'Shipped - Rejected by Buyer') 
        THEN 1 ELSE 0 END) as pre_delivery_failures,
    SUM(CASE WHEN status IN ('Shipped - Returned to Seller', 'Shipped - Damaged', 
                             'Shipped - Returning to Seller') 
        THEN 1 ELSE 0 END) as post_delivery_failures,
    ROUND(SUM(CASE WHEN status IN ('Cancelled', 'Shipped - Lost in Transit', 
                                   'Shipped - Rejected by Buyer',
                                   'Shipped - Returned to Seller', 'Shipped - Damaged', 
                                   'Shipped - Returning to Seller')
              THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 2) 
        as total_failure_rate_percent,
    TO_CHAR(SUM(CAST(amount AS NUMERIC)), 'FM999,999,999.00') as total_revenue
FROM amazon_sales_optimized
WHERE amount IS NOT NULL
    AND amount ~ '^[0-9]+\.?[0-9]*$'
GROUP BY category
HAVING COUNT(*) > 50  -- Filter out categories with too few orders for statistical significance
ORDER BY total_failure_rate_percent DESC
LIMIT 10;
-- KEY FINDINGS:
-- Top Problem Categories: Bottom, Western Dress, Kurta, Set, Blouse
-- ALARMING: Some categories have 50%+ failure rates!
-- RECOMMENDATION: Audit these product lines immediately


-- Query 9: Deep-dive into top 5 failing categories
-- PURPOSE: Quantify exact losses from problematic product categories
-- BUSINESS VALUE: Calculate ROI of fixing quality/supplier issues
SELECT  
    category,
    COUNT(*) as total_problem_orders,
    SUM(CAST(amount AS NUMERIC)) as total_lost_revenue,
    ROUND(AVG(CAST(amount AS NUMERIC)), 2) as avg_problem_order_value,
    TO_CHAR(SUM(CAST(amount AS NUMERIC)), 'FM999,999.00') as formatted_loss
FROM amazon_sales_optimized
WHERE category IN ('Bottom', 'Western Dress', 'Kurta', 'Set', 'Blouse')
    AND status IN ('Cancelled', 'Shipped - Lost in Transit', 'Shipped - Rejected by Buyer')
    AND amount IS NOT NULL
    AND amount ~ '^[0-9]+\.?[0-9]*$'
GROUP BY category
ORDER BY total_lost_revenue DESC;
-- ACTIONABLE: These 5 categories alone account for significant losses
-- RECOMMENDATION: 
-- 1. Review supplier contracts for these products
-- 2. Improve product descriptions to reduce expectation mismatches
-- 3. Consider quality control checks before shipment


-- ============================================================================
-- SECTION 5: GEOGRAPHIC FAILURE ANALYSIS
-- ============================================================================

-- Query 10: Identify cities with highest delivery failure rates
-- PURPOSE: Find geographic areas with operational problems
-- ROOT CAUSES: Poor courier service, remote locations, address issues
-- BUSINESS ACTION: Renegotiate courier contracts or adjust delivery zones
SELECT 
    category,
    ship_city,
    COUNT(*) as total_orders,
    SUM(CASE WHEN status IN ('Cancelled', 'Shipped - Lost in Transit', 
                             'Shipped - Rejected by Buyer') 
        THEN 1 ELSE 0 END) as delivery_failures,
    ROUND((SUM(CASE WHEN status IN ('Cancelled', 'Shipped - Lost in Transit', 
                                    'Shipped - Rejected by Buyer') 
               THEN 1 ELSE 0 END)::NUMERIC / 
           NULLIF(COUNT(*), 0) * 100), 2) as failure_rate_percent,
    TO_CHAR(SUM(CASE WHEN status IN ('Cancelled', 'Shipped - Lost in Transit', 
                                     'Shipped - Rejected by Buyer')
                THEN CAST(amount AS NUMERIC) ELSE 0 END), 'FM999,999.00') 
        as lost_revenue_in_city
FROM amazon_sales_optimized
WHERE category IN ('Bottom', 'Western Dress', 'Kurta', 'Set', 'Blouse')
    AND amount IS NOT NULL
    AND amount ~ '^[0-9]+\.?[0-9]*$'
GROUP BY category, ship_city
HAVING COUNT(*) > 10  -- Minimum sample size for reliability
ORDER BY failure_rate_percent DESC
LIMIT 20;
-- INSIGHT: Identifies specific city + category combinations with issues
-- RECOMMENDATION: 
-- 1. Use alternative courier services in high-failure cities
-- 2. Add delivery confirmation requirements
-- 3. Improve address verification at checkout


-- ============================================================================
-- SECTION 6: EXECUTIVE RISK DASHBOARD
-- ============================================================================

-- Query 11: Comprehensive risk summary for leadership
-- PURPOSE: One-page view of all risk metrics for decision-making
-- STAKEHOLDERS: CFO (financial risk), COO (operational fixes), CEO (strategy)
SELECT 
    'Total Pre-Delivery Losses (₹)' as risk_metric,
    TO_CHAR(SUM(CASE WHEN status IN ('Cancelled', 'Shipped - Lost in Transit', 
                                     'Shipped - Rejected by Buyer', 'Pending', 
                                     'Pending - Waiting for Pick Up')
                THEN CAST(amount AS NUMERIC) ELSE 0 END), 'FM999,999,999.00') as value,
    'Revenue lost before shipment' as impact
FROM amazon_sales_optimized
WHERE amount IS NOT NULL AND amount ~ '^[0-9]+\.?[0-9]*$'

UNION ALL

SELECT 
    'Total Post-Delivery Losses (₹)',
    TO_CHAR(SUM(CASE WHEN status IN ('Shipped - Returned to Seller', 'Shipped - Damaged', 
                                     'Shipped - Returning to Seller')
                THEN CAST(amount AS NUMERIC) ELSE 0 END), 'FM999,999,999.00'),
    'Revenue lost after shipment (higher cost)'
FROM amazon_sales_optimized
WHERE amount IS NOT NULL AND amount ~ '^[0-9]+\.?[0-9]*$'

UNION ALL

SELECT 
    'In-Transit Risk Exposure (₹)',
    TO_CHAR(SUM(CASE WHEN status IN ('Shipped', 'Shipped - Picked Up', 'Shipped - Out for Delivery')
                THEN CAST(amount AS NUMERIC) ELSE 0 END), 'FM999,999,999.00'),
    '₹51.6M at risk - only 73% will deliver successfully'
FROM amazon_sales_optimized
WHERE amount IS NOT NULL AND amount ~ '^[0-9]+\.?[0-9]*$'

UNION ALL

SELECT 
    'Expected Loss from In-Transit (₹)',
    TO_CHAR(ROUND(SUM(CASE WHEN status IN ('Shipped', 'Shipped - Picked Up', 'Shipped - Out for Delivery')
                THEN CAST(amount AS NUMERIC) ELSE 0 END) * (1 - 0.7291), 2), 'FM999,999,999.00'),
    'Predicted failures based on 27% historical failure rate'
FROM amazon_sales_optimized
WHERE amount IS NOT NULL AND amount ~ '^[0-9]+\.?[0-9]*$'

UNION ALL

SELECT 
    'Delivery Success Rate (%)',
    TO_CHAR(ROUND((SUM(CASE WHEN status = 'Shipped - Delivered to Buyer' THEN 1 ELSE 0 END)::NUMERIC /
                   NULLIF(SUM(CASE WHEN status IN ('Shipped - Delivered to Buyer', 'Cancelled', 
                                                   'Shipped - Lost in Transit', 'Shipped - Rejected by Buyer',
                                                   'Shipped - Returned to Seller', 'Shipped - Damaged', 
                                                   'Shipped - Returning to Seller') 
                              THEN 1 ELSE 0 END), 0) * 100), 2), 'FM999.00'),
    'Only 73% of orders complete successfully'
FROM amazon_sales_optimized

UNION ALL

SELECT 
    'Total Risk-Adjusted Revenue (₹)',
    TO_CHAR(SUM(CASE WHEN status = 'Shipped - Delivered to Buyer' THEN CAST(amount AS NUMERIC) ELSE 0 END) +
            (SUM(CASE WHEN status IN ('Shipped', 'Shipped - Picked Up', 'Shipped - Out for Delivery')
                 THEN CAST(amount AS NUMERIC) ELSE 0 END) * 0.7291), 'FM999,999,999.00'),
    'Realistic revenue after accounting for failure risk'
FROM amazon_sales_optimized
WHERE amount IS NOT NULL AND amount ~ '^[0-9]+\.?[0-9]*$';

-- ============================================================================
-- KEY INSIGHTS & CRITICAL RECOMMENDATIONS (PROJECT 2)
-- ============================================================================
/*
🚨 CRITICAL FINDINGS:

1. RISK EXPOSURE: ₹14M at risk in current in-transit inventory
   → Only 73% will successfully deliver based on historical patterns
   → Need to reserve funds for refunds and losses

2. PRE-DELIVERY LOSSES: ₹6.9M lost before shipping
   → 14.2% cancellation rate is TOO HIGH
   → Root causes: Payment issues? Stock unavailability? Poor UX?

3. POST-DELIVERY LOSSES: ₹2.3M lost to returns/damages
   → Actual cost is 2x due to reverse logistics
   → Total impact: ~₹4.6M including operational costs

4. CATEGORY PROBLEMS: 5 categories (Bottom, Western Dress, Kurta, Set, Blouse) 
   → Show 50%+ failure rates
   → These alone account for significant portion of losses
   → URGENT: Quality audit needed

5. SUCCESS RATE: Only 72.91% order completion
   → Industry standard is 85-90%
   → 15-20% improvement potential = ₹10-13M additional revenue

💡 STRATEGIC RECOMMENDATIONS (PRIORITY ORDER):

HIGH PRIORITY (Immediate Action Required):
1. Reduce cancellation rate from 14% to <8%
   - Improve payment success rates
   - Real-time inventory updates
   - Better product information

2. Audit top 5 failing product categories
   - Review supplier quality
   - Enhance product descriptions
   - Implement pre-shipment QC

3. Reserve ₹14M for in-transit risk exposure
   - Financial planning must account for 27% failure rate
   - Don't overestimate revenue forecasts

MEDIUM PRIORITY (Within 30 days):
4. Geographic delivery optimization
   - Identify high-failure cities from Query 10
   - Negotiate better courier contracts
   - Implement address verification

5. Reduce return rate (currently causing ₹2.3M loss)
   - Improve product photography
   - Size guides and fit recommendations
   - Customer reviews for realistic expectations

LONG-TERM (Strategic Initiatives):
6. Improve overall success rate from 73% → 85%
   - Potential revenue uplift: ₹10-13M annually
   - Better logistics partners
   - Predictive analytics for problem orders

FINANCIAL IMPACT OF RECOMMENDATIONS:
- Reducing cancellations by 50%: Save ~₹3.3M
- Improving success rate to 85%: Gain ~₹10M
- Optimizing top 5 categories: Save ~₹2-3M
- TOTAL POTENTIAL IMPACT: ₹15-16M additional annual revenue

📊 NEXT STEPS FOR STAKEHOLDERS:
→ CFO: Adjust revenue forecasts to use risk-adjusted numbers
→ COO: Immediate audit of top failing categories
→ Marketing: Reduce cancellations through better UX
→ Logistics: Renegotiate courier contracts for problem areas
→ Product: Quality improvements for high-failure SKUs
*/