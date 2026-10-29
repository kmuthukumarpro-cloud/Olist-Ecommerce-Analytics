
/*
Project 4: Olist E-Commerce Analytics
Tool: SQL Server (SSMS)
Focus: Sales, products, payments, reviews, delivery, and customers
*/

USE Olist_Analytics;
GO

-- =====================================================
-- SECTION 1: OVERALL BUSINESS KPIs
-- =====================================================

-- 1. Total product sales and freight charges
SELECT
    ROUND(SUM(price), 2) AS total_product_sales,
    ROUND(SUM(freight_value), 2) AS total_freight
FROM order_items;

-- 2. Total number of orders
SELECT
    COUNT(*) AS total_orders
FROM orders;

-- 3. Number of unique customers who placed orders
SELECT
    COUNT(DISTINCT c.customer_unique_id) AS total_customers
FROM customers c
INNER JOIN orders o
    ON c.customer_id = o.customer_id;


-- =====================================================
-- SECTION 2: PRODUCT CATEGORY SALES
-- =====================================================

-- 4. Sales by product category
SELECT
    t.product_category_name_english AS product_category,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_sales
FROM order_items oi
INNER JOIN products p
    ON oi.product_id = p.product_id
INNER JOIN category_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY t.product_category_name_english
ORDER BY total_sales DESC;

-- 5. Categories with the lowest average review scores
-- Count each review once per category.
SELECT
    product_category,
    COUNT(*) AS total_reviews,
    ROUND(AVG(review_score * 1.0), 2) AS avg_review_score
FROM (
    SELECT DISTINCT
        r.review_id,
        r.review_score,
        t.product_category_name_english AS product_category
    FROM reviews r
    INNER JOIN order_items oi
        ON r.order_id = oi.order_id
    INNER JOIN products p
        ON oi.product_id = p.product_id
    INNER JOIN category_translation t
        ON p.product_category_name = t.product_category_name
) AS category_reviews
GROUP BY product_category
ORDER BY avg_review_score ASC;


-- =====================================================
-- SECTION 3: MONTHLY SALES
-- =====================================================

-- 6. Product sales and order count by month
SELECT
    YEAR(o.order_purchase_timestamp) AS order_year,
    MONTH(o.order_purchase_timestamp) AS order_month,
    ROUND(SUM(oi.price), 2) AS total_sales,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM orders o
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
GROUP BY
    YEAR(o.order_purchase_timestamp),
    MONTH(o.order_purchase_timestamp)
ORDER BY order_year, order_month;


-- =====================================================
-- SECTION 4: PRODUCT AND SELLER PERFORMANCE
-- =====================================================

-- 7. Top 10 products by sales
SELECT TOP 10
    oi.product_id,
    ROUND(SUM(oi.price), 2) AS total_sales,
    COUNT(DISTINCT oi.order_id) AS total_orders
FROM order_items oi
GROUP BY oi.product_id
ORDER BY total_sales DESC;

-- 8. Sales by seller state
SELECT
    s.seller_state,
    COUNT(DISTINCT s.seller_id) AS total_sellers,
    ROUND(SUM(oi.price), 2) AS total_sales
FROM sellers s
INNER JOIN order_items oi
    ON s.seller_id = oi.seller_id
GROUP BY s.seller_state
ORDER BY total_sales DESC;

-- 9. Top sellers by product sales
SELECT TOP 10
    s.seller_id,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_sales
FROM sellers s
INNER JOIN order_items oi
    ON s.seller_id = oi.seller_id
GROUP BY s.seller_id
ORDER BY total_sales DESC;


-- =====================================================
-- SECTION 5: PAYMENT ANALYSIS
-- =====================================================

-- 10. Payment totals and order counts by payment method
SELECT
    payment_type,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(*) AS payment_records
FROM payments
GROUP BY payment_type
ORDER BY total_payment_value DESC;

-- 11. Top 10 customers by recorded payment value
SELECT TOP 10
    c.customer_unique_id,
    COUNT(DISTINCT p.order_id) AS total_orders,
    ROUND(SUM(p.payment_value), 2) AS total_payment_value
FROM payments p
INNER JOIN orders o
    ON p.order_id = o.order_id
INNER JOIN customers c
    ON o.customer_id = c.customer_id
GROUP BY c.customer_unique_id
ORDER BY total_payment_value DESC;


-- =====================================================
-- SECTION 6: REVIEW AND CUSTOMER SATISFACTION
-- =====================================================

-- 12. Number and percentage of reviews for each score
SELECT
    review_score,
    COUNT(*) AS total_reviews,
    ROUND(
        COUNT(*) * 100.0 / (SELECT COUNT(*) FROM reviews),
        2
    ) AS review_pct
FROM reviews
GROUP BY review_score
ORDER BY review_score DESC;

-- 13. Average review score by order status
SELECT
    o.order_status,
    COUNT(r.review_id) AS total_reviews,
    ROUND(AVG(r.review_score * 1.0), 2) AS avg_review_score
FROM orders o
INNER JOIN reviews r
    ON o.order_id = r.order_id
GROUP BY o.order_status
ORDER BY avg_review_score DESC;

-- 14. Compare review scores for late and on-time deliveries
SELECT
    CASE
        WHEN o.order_delivered_customer_date >
             o.order_estimated_delivery_date THEN 'Late'
        ELSE 'On time'
    END AS delivery_performance,
    COUNT(r.review_id) AS total_reviews,
    ROUND(AVG(r.review_score * 1.0), 2) AS avg_review_score
FROM orders o
INNER JOIN reviews r
    ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY
    CASE
        WHEN o.order_delivered_customer_date >
             o.order_estimated_delivery_date THEN 'Late'
        ELSE 'On time'
    END
ORDER BY avg_review_score ASC;


-- =====================================================
-- SECTION 7: DELIVERY PERFORMANCE
-- =====================================================

-- 15. Average delivery time in days
SELECT
    ROUND(
        AVG(DATEDIFF(
            DAY,
            order_purchase_timestamp,
            order_delivered_customer_date
        ) * 1.0),
        2
    ) AS avg_delivery_days
FROM orders
WHERE order_delivered_customer_date IS NOT NULL;

-- 16. Number and percentage of late and on-time deliveries
SELECT
    CASE
        WHEN order_delivered_customer_date >
             order_estimated_delivery_date THEN 'Late'
        ELSE 'On time'
    END AS delivery_performance,
    COUNT(*) AS total_orders,
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*)
         FROM orders
         WHERE order_delivered_customer_date IS NOT NULL
           AND order_estimated_delivery_date IS NOT NULL),
        2
    ) AS order_pct
FROM orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
GROUP BY
    CASE
        WHEN order_delivered_customer_date >
             order_estimated_delivery_date THEN 'Late'
        ELSE 'On time'
    END
ORDER BY total_orders DESC;

-- 17. Late delivery percentage by customer state
SELECT
    c.customer_state,
    COUNT(*) AS delivered_orders,
    SUM(
        CASE
            WHEN o.order_delivered_customer_date >
                 o.order_estimated_delivery_date THEN 1
            ELSE 0
        END
    ) AS late_orders,
    ROUND(
        SUM(
            CASE
                WHEN o.order_delivered_customer_date >
                     o.order_estimated_delivery_date THEN 1.0
                ELSE 0.0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS late_delivery_pct
FROM orders o
INNER JOIN customers c
    ON o.customer_id = c.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY late_delivery_pct DESC;


-- =====================================================
-- SECTION 8: CUSTOMER LOYALTY
-- =====================================================

-- 18. Number of one-time and repeat customers
SELECT
    SUM(CASE WHEN order_count = 1 THEN 1 ELSE 0 END) AS one_time_customers,
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_customers
FROM (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
) AS customer_orders;

-- 19. Top 10 customers by lifetime product sales
SELECT TOP 10
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS lifetime_product_sales
FROM customers c
INNER JOIN orders o
    ON c.customer_id = o.customer_id
INNER JOIN order_items oi
    ON o.order_id = oi.order_id
GROUP BY c.customer_unique_id
ORDER BY lifetime_product_sales DESC;


-- =====================================================
-- SECTION 9: ORDER STATUS
-- =====================================================

-- 20. Number and percentage of orders by status
SELECT
    order_status,
    COUNT(*) AS total_orders,
    ROUND(
        COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders),
        2
    ) AS order_pct
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;

