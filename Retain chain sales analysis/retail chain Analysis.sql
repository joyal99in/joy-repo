 
create database Retail_chain

use retail_chain




/********************************************************************************************************************************************************************************************************
																				DATA CLEANING
*************************************************************************************************************************************************************************************************/



-----------------------------------------------------------------------------ORDERPAYMENTS-----------------------------------------------

SELECT COUNT(distinct order_id) from orders /* 98666 rows */
SELECT COUNT(distinct order_id) from orderpayments /* 99440  rows */
--- So there should be at least 774 or more distinct orderids ( 99440 - 98666 ) in orderpayments table that are not present in orders table


----Check the count of DISTINCT orderids that are present in orderpayments but not present in orders table
SELECT COUNT(distinct op.order_id) AS Orders_Only_In_OrderPayments
FROM orderpayments op
LEFT JOIN orders o ON op.order_id = o.order_id
WHERE o.order_id IS NULL;

----Check the count of orderids that are present in orders but not present in orderpayments table
SELECT COUNT(DISTINCT o.order_id) AS Orders_Only_In_Orders
FROM orders o
LEFT JOIN orderpayments op ON o.order_id = op.order_id
WHERE op.order_id IS NULL;


/*****************************************
			Aggregate
****************************************/

--- Aggregate into orderpayments into new table orderpayments_agg -95442 rows

SELECT 
    order_id, 
    payment_type, 
    SUM(payment_value) AS payment_value
INTO orderpayments_agg
FROM orderpayments
GROUP BY order_id, payment_type;


------------------------------------------------------------------ORDERREVIEW RATINGS-------------------------------------------------------------------

----Delete Key level duplicates from orderreview_ratings

WITH CTE AS (
    SELECT
        order_id,
        ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY (SELECT NULL)) AS rn
    FROM orderreview_ratings
)
DELETE FROM CTE
WHERE rn > 1;

select * from orderreview_ratings


--------------------------------------------------------------------STORES INFO--------------------------------------------------------------------------------------------

----Delete key level duplicates from stores_info
WITH CTE AS (
    SELECT
        storeid,
        ROW_NUMBER() OVER (PARTITION BY storeid ORDER BY (SELECT NULL)) AS rn
    FROM stores_info
)
DELETE FROM CTE
WHERE rn > 1;




---------------------------------------------------------------------PRODUCTS INFO---------------------------------------------------------------------------------

----Replace #N/A in category column with Not Avaliable
UPDATE productsinfo
SET category = 'Not Available'
WHERE category = '#N/A';




-- -------------------------------------------------------------------ORDERS-------------------------------------------------------------


	SELECT *
FROM orders
order by quantity desc

	SELECT *
FROM orders
where order_id='8272b63d03f5f79c56e9e4120aec44ef'
order by quantity desc


/************************************************
                  Impute
*************************************************/

---Quantity column is cumulative so replace entire quantity column with

UPDATE orders
SET quantity = 1;

/**************************************************
				Drop Column
****************************************************/
--Total amount column is calculated based on wrong quantity count. hence drop Total_Amount column

ALTER TABLE orders
DROP COLUMN total_amount;


	select * from orders
	order by quantity desc


/********************************************************
				Drop Rows
*********************************************************/


---- List of orderID's that are present in multiple stores
SELECT order_id
FROM orders
GROUP BY order_id
HAVING COUNT(DISTINCT Delivered_StoreID) > 1;


---Delete orderID's that are present in multiple stores
DELETE FROM orders
WHERE order_id IN (
    SELECT order_id
    FROM orders
    GROUP BY order_id
    HAVING COUNT(DISTINCT Delivered_StoreID) > 1
);



---verify that rows related to that orderids are deleted

	select * from orders
	where order_id ='014405982914c2cde2796ddcf0b8703d'



---List of orderId's with multiple customersId's
SELECT order_id
FROM orders
GROUP BY order_id
HAVING COUNT(DISTINCT customer_id) > 1;

--Delete rows with orderIDs which is related to multiple customerID's
DELETE FROM orders
WHERE order_id IN (
    SELECT order_id
    FROM orders
    GROUP BY order_id
    HAVING COUNT(DISTINCT customer_id) > 1
);


----List of orderids which has multiple bill_stamp_date

SELECT order_id
FROM orders
GROUP BY order_id
HAVING COUNT(DISTINCT bill_date_timestamp) > 1;

----delete rows with orderids having multiple bill_stamp_date

DELETE FROM orders
WHERE order_id IN (
    SELECT order_id
    FROM orders
    GROUP BY order_id
    HAVING COUNT(DISTINCT bill_date_timestamp) > 1
);

---List of orderid's where order_id and product_id is same but either mrp or cost per unit or discount is different

SELECT order_id
FROM orders
GROUP BY order_id, product_id
HAVING COUNT(DISTINCT MRP) > 1
   OR COUNT(DISTINCT Cost_Per_Unit) > 1
   OR COUNT(DISTINCT Discount) > 1;


   ---Deleting rows  where order_id, product_id, bill_date_timestamp is same but either mrp or cost per unit or discount is different

   DELETE FROM orders
WHERE order_id IN (
    SELECT order_id
    FROM orders
    GROUP BY order_id, product_id, bill_date_timestamp
    HAVING COUNT(DISTINCT MRP) > 1
       OR COUNT(DISTINCT Cost_Per_Unit) > 1
       OR COUNT(DISTINCT Discount) > 1
);


--Number of columns in orders -99,001
select * from orders
																									

/*******************************************************
					Aggregate
*********************************************************/

SELECT 
    Customer_id,
    order_id,
    product_id,
    Channel,
    Delivered_StoreID,
    Bill_date_timestamp,
    SUM(Quantity) AS Quantity,
    Cost_Per_Unit,
    MRP,
    Discount
	into orders_agg
FROM 
    orders
GROUP BY 
    Customer_id,
    order_id,
    product_id,
    Channel,
    Delivered_StoreID,
    Bill_date_timestamp,
	Cost_Per_Unit,
    MRP,
    Discount

	---Number of rows in orders_agg -95640
	select* from orders_agg

/************************************************
			Add Column
************************************************/

	--- add Total amounts column

ALTER TABLE orders_agg
ADD Total_amounts DECIMAL(30, 15);  -- Adjust the data type and precision as needed

UPDATE orders_agg
SET Total_amounts = (MRP - Discount) * Quantity;


/********************************************************************************
Identify orderId where total_amounts and payment_value is different
********************************************************************************/
WITH Orders_Summary AS (
    SELECT 
        order_id, 
        ROUND(SUM(total_amounts), 0) AS total_order_amount
    FROM 
        orders_agg
    GROUP BY 
        order_id
),
Payments_Summary AS (
    SELECT 
        order_id, 
        ROUND(SUM(payment_value), 0) AS total_payment_amount
    FROM 
        orderpayments
    GROUP BY 
        order_id
)
SELECT 
    o.order_id,
    o.total_order_amount,
    p.total_payment_amount
FROM 
    Orders_Summary o
LEFT JOIN 
    Payments_Summary p ON o.order_id = p.order_id
WHERE 
    o.total_order_amount <> ISNULL(p.total_payment_amount, 0);



------Delete OrderId where total_amounts and payment_value  is different

WITH Orders_Summary AS (
    SELECT 
        order_id, 
        ROUND(SUM(total_amounts), 0) AS total_order_amount
    FROM 
        orders_agg
    GROUP BY 
        order_id
),
Payments_Summary AS (
    SELECT 
        order_id, 
        ROUND(SUM(payment_value), 0) AS total_payment_amount
    FROM 
        orderpayments
    GROUP BY 
        order_id
),
Discrepant_Orders AS (
    SELECT 
        o.order_id
    FROM 
        Orders_Summary o
    LEFT JOIN 
        Payments_Summary p ON o.order_id = p.order_id
    WHERE 
        o.total_order_amount <> ISNULL(p.total_payment_amount, 0)
)

DELETE FROM orders_agg
WHERE order_id IN (SELECT order_id FROM Discrepant_Orders);


select * from orders_agg
---95382 rows
-----------------------------------------------------------------------------------JOIN Tables--------------------------------------------------------------------------------------

select * from orderpayments_agg



SELECT 
    o.*, 
    c.customer_city, c.customer_state,c.Gender,
     i.category, 
    s.seller_city, s.seller_state, s.region,
    p.payment_type, p.payment_value, 
    r.Customer_Satisfaction_Score
INTO joined_tables
FROM orders_agg o
INNER JOIN customers c
ON o.customer_id = c.custid
INNER JOIN productsinfo i
ON o.product_id = i.product_id
INNER JOIN Stores_Info s
ON o.delivered_storeid = s.StoreID
INNER JOIN orderpayments_agg p
ON o.order_id = p.order_id
INNER JOIN OrderReview_Ratings r
ON o.order_id = r.order_id;


----Joining done 97532 rows

---This table have duplicate customer_id ,order_id, producct_id etc. But no record level duplicates. Example:
	select * from joined_tables
	where order_id='478c69b6c0107cf696d64c524286ff05'



/*
SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'joined_tables';*/


/********************************************************************************************************************************************************************************************************
																			      DATA ANALYSIS
********************************************************************************************************************************************************************************************************/

use retail_chain

--------------------------------------------------------------------------------Exploratory Data Analysis-------------------------------------------------------------------

/********************************************************************************
Number of orders from each city
********************************************************************************/

SELECT customer_city,count(distinct order_id) as count_city
FROM orders_agg AS o
JOIN customers AS c
ON o.customer_id = c.custid
GROUP BY customer_city 


/********************************************************************************
Avg. number of categories per order
********************************************************************************/
select AVG(cat_cnt * 1.0) from (
select order_id,COUNT ( distinct Category ) cat_cnt 
from orders_agg as o join ProductsInfo as p on
o.product_id=p.product_id
group by order_id) as a


/********************************************************************************
Customer satisfaction count
********************************************************************************/
select customer_satisfaction_score,COUNT(distinct o.order_id) as customer_count
from orders_agg as o
join OrderReview_Ratings s
on o.order_id= s.order_id
group by customer_satisfaction_score


/********************************************************************************
What is the average customer satisfaction score
********************************************************************************/
select avg(customer_satisfaction_score)
from orders_agg as o
join OrderReview_Ratings s
on o.order_id= s.order_id



/********************************************************************************
-----Count of customers statewise
********************************************************************************/
		SELECT 
    customer_state, 
    COUNT(DISTINCT customer_id) AS state_count
FROM 
    joined_tables
GROUP BY 
    customer_state;


	/********************************************************************************
	--Count of stores statewise
********************************************************************************/

	SELECT 
    seller_state, 
    COUNT(DISTINCT delivered_storeid) AS state_count
FROM 
    joined_tables
GROUP BY 
    seller_state;


/********************************************************************************
----Count of channel
********************************************************************************/
SELECT 
    channel, 
    COUNT(DISTINCT order_id) AS channel_count
FROM 
    orders_agg
GROUP BY 
    channel;

/********************************************************************************
Payment_type count from orderpayments_agg
********************************************************************************/
SELECT
    op.payment_type,
    COUNT(DISTINCT op.order_id) AS payment_type_count
FROM
    orderpayments op
JOIN
    orders_agg oa ON op.order_id = oa.order_id
GROUP BY
    op.payment_type;


/****************************************************
Total payment (based on payment_value of orderpayments table ) 
***********************************************************/

SELECT SUM(p.payment_value) AS total_payment_value
FROM orderpayments_agg p
WHERE p.order_id IN (SELECT DISTINCT order_id FROM orders_agg);

/***************************************************************
Total revenue (based on Total_amounts column in orders_agg)
***************************************************************/
SELECT SUM(Total_amounts) AS bill_amount
FROM orders_agg



/********************************************************************************
	-----Payment& count of orders-  Male/Female
********************************************************************************/
SELECT 
    c.gender,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(o.total_amounts) AS sum_of_payments
FROM 
    orders_agg o
INNER JOIN 
    customers c ON o.Customer_id = c.custid
GROUP BY 
    c.gender;



/**********************************************************
--Number of orders
**********************************************************/
SELECT COUNT(DISTINCT order_id) AS NumberOfOrders
FROM orders_agg;



/******************************************************************
--Total discount
*******************************************************************/
SELECT SUM(Discount) AS TotalDiscount
FROM orders_agg;



/******************************************
Avg discount per customer
**************************************/
SELECT CAST(AVG(CustomerDiscount) AS DECIMAL(18, 4)) AS AverageDiscountPerCustomer
FROM (
    SELECT customer_id, SUM(CAST(Discount AS DECIMAL(18, 4))) AS CustomerDiscount
    FROM orders_agg
    GROUP BY customer_id
) AS CustomerDiscounts;


/****************************************************************
Avg discount per order
********************************************************/

SELECT CAST(AVG(order_discount) AS DECIMAL(18, 4)) AS avg_orderDiscount
FROM (
    SELECT order_id, SUM(CAST(discount AS DECIMAL(18, 4))) AS order_discount
    FROM orders_agg
    GROUP BY order_id
) AS orderDiscounts;



/***************************************************************
Average order_value
*****************************************************************/
SELECT AVG(TotalOrderValue) AS AverageOrderValue
FROM (
    SELECT order_id, SUM(Total_amounts) AS TotalOrderValue
    FROM orders_agg
    GROUP BY order_id
) AS OrderValues;



/******************************************************************
Average sales per customer
*******************************************************************/
SELECT AVG(TotalSales) AS AverageSalesPerCustomer
FROM (
    SELECT customer_id, SUM(Total_amounts) AS TotalSales
    FROM orders_agg
    GROUP BY customer_id
) AS CustomerSales;



/*********************************************************************
Average profit per customer
*********************************************************************/
SELECT AVG(TotalProfit) AS AverageProfitPerCustomer
FROM (
    SELECT customer_id, SUM(total_amounts-(Cost_Per_Unit * Quantity)) AS TotalProfit
    FROM orders_agg
    GROUP BY customer_id
) AS CustomerProfits;





/******************************************************************************
Avg number of items per order
********************************************************************************/
SELECT SUM(Quantity) * 1.0 / COUNT(DISTINCT order_id) AS AverageNumberOfItemsPerOrder
FROM orders_agg;



/********************************************************************************
Number of customers
********************************************************************************/
SELECT COUNT(DISTINCT customer_id) AS NumberOfCustomers
FROM joined_tables;



/********************************************************************************
--Transactions per customer
********************************************************************************/
SELECT AVG(TransactionCount) AS TransactionsPerCustomer
FROM (
    SELECT customer_id, COUNT(*) AS TransactionCount
    FROM orders_agg
    GROUP BY customer_id
) AS CustomerTransactions;


/********************************************************************************
--Total profit
********************************************************************************/
select SUM(total_amounts-(Cost_Per_Unit * Quantity)) as Profit
from orders_agg



/********************************************************************************
--Total cost
********************************************************************************/
SELECT SUM(Cost_Per_Unit * Quantity) AS TotalCost
FROM orders_agg;



/********************************************************************************
--Total quantity
********************************************************************************/
SELECT SUM(Quantity) AS TotalQuantity
FROM orders_agg;



/********************************************************************************
--Total products 
********************************************************************************/
SELECT COUNT(DISTINCT product_id) AS TotalProducts
FROM ProductsInfo;



	/********************************************************************************
	One time buyer vs repeat buyer
	********************************************************************************/
	WITH PurchaseCounts AS (
    -- Count the number of purchases per customer
    SELECT 
        Customer_id,
        COUNT(distinct Order_id) AS Purchase_Count
    FROM 
        orders_agg
    GROUP BY 
        Customer_id
),
PurchaseTypes AS (
    -- Determine if the customer is a one-time or repeat purchaser
    SELECT 
        Customer_id,
        CASE 
            WHEN Purchase_Count = 1 THEN 'One-Time'
            ELSE 'Repeat'
        END AS Purchase_Type
    FROM 
        PurchaseCounts
)
-- Count the number of customers in each purchase type
SELECT 
    Purchase_Type,
    COUNT(Customer_id) AS Customer_Count
FROM 
    PurchaseTypes
GROUP BY 
    Purchase_Type;




/********************************************************************************
--Count of customers with more than one purchase
********************************************************************************/
WITH CustomerOrderCounts AS (
    -- Count the number of distinct orders for each customer
    SELECT
        customer_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM orders_agg
    GROUP BY customer_id
)

-- Select customers with more than one distinct order
SELECT
    COUNT(customer_id) AS repeat_customers_count
FROM CustomerOrderCounts
WHERE order_count > 1;



/********************************************************************************
--Productid with highest profit margin
********************************************************************************/
select top 1 product_id, (mrp-discount-cost_per_unit)  as profit
from orders_agg
order by profit desc

select * from productsinfo
where product_id='ec31d2a17b299511e7c8627be9337b9b'


/********************************************************************************
---Product with lowest profit margin
********************************************************************************/
select top 1 product_id, (mrp-discount-cost_per_unit)  as profit
from orders_agg
order by profit asc



/********************************************************************************
--productId with zero profit
********************************************************************************/
select product_id, (mrp-cost_per_unit-quantity) 
from orders
where (mrp-cost_per_unit-quantity) =0


/********************************************************************************
--Total categories of products avaliable
********************************************************************************/
SELECT COUNT(DISTINCT category) AS TotalCategories
FROM ProductsInfo;


/********************************************************************************
--Total stores
********************************************************************************/
SELECT COUNT(DISTINCT Delivered_StoreID) AS TotalStores
FROM orders_agg;



/********************************************************************************
--Total channels
********************************************************************************/
SELECT COUNT(DISTINCT Channel) AS TotalChannels
FROM orders_agg;



/********************************************************************************
--Total payment methods
********************************************************************************/
SELECT COUNT(DISTINCT payment_type) AS TotalPaymentMethods
FROM orderpayments;



/********************************************************************************
--profit percentage
********************************************************************************/

select sum((total_amount - cost_per_unit)) *100.0 / SUM(total_amount) as profit_percent from orders_agg



/********************************************************************************
Repeat purchase rate
********************************************************************************/

-- Calculate the number of repeat customers and total customers
-- Identify customers with more than one distinct order_id
WITH CustomerOrderCounts AS (
    SELECT 
        customer_id,
        COUNT(DISTINCT order_id) AS OrderCount
    FROM orders_agg
    GROUP BY customer_id
),
RepeatCustomers AS (
    SELECT 
        COUNT(*) AS RepeatCustomerCount
    FROM CustomerOrderCounts
    WHERE OrderCount > 1
),
TotalCustomers AS (
    SELECT 
        COUNT(DISTINCT customer_id) AS TotalCustomerCount
    FROM orders_agg
)

-- Calculate the repeat purchase percentage
SELECT 
    CAST((RepeatCustomerCount * 100.0 / TotalCustomerCount) AS DECIMAL(6, 3)) AS RepeatPurchasepercentage
FROM RepeatCustomers, TotalCustomers;





/********************************************************************************
	---List the top 10 most expensive products sorted by price and their contribution to sales
********************************************************************************/
use retail_chain

----method 1
select top 10 product_id , max(MRP)MRP, SUM(total_amounts)total_sales,SUM(total_amounts)*100.0/ (select SUM(total_amounts) from orders_agg) as p_ercent
from orders_agg
group by product_id
order by max(MRP) desc

/********************************************************************************
---Top10/ worst10 stores
********************************************************************************/
SELECT TOP 10 Delivered_StoreID, SUM(Total_amounts) AS total_sales
FROM orders_agg
GROUP BY Delivered_StoreID
ORDER BY total_sales DESC;

SELECT TOP 10 Delivered_StoreID, SUM(Total_amounts) AS total_sales
FROM orders_agg
GROUP BY Delivered_StoreID
ORDER BY total_sales ASC;



/********************************************************************************
Understanding how many new customers acquired every month (who made transaction first time in the data)
********************************************************************************/
-- Step 1: Identify the first transaction date for each customer

	select year(a.min_bill_date) year,MONTH(a.min_bill_date) as month , COUNT(*) as cohort_customers from
(select customer_id, MIN(bill_date_timestamp) as min_bill_date from orders
group by Customer_id) as a
group by year(a.min_bill_date),MONTH(a.min_bill_date)
order by year, month


/********************************************************************************
	---- Revenue from new vs existing customer on monthly basis
********************************************************************************/
SELECT
    YEAR(o.Bill_date_timestamp) AS TransactionYear,
    MONTH(o.Bill_date_timestamp) AS TransactionMonth,
    SUM(CASE WHEN o.Bill_date_timestamp = FirstPurchaseDate THEN o.Total_amount ELSE 0 END) AS NewCustomerRevenue,
    SUM(CASE WHEN o.Bill_date_timestamp > FirstPurchaseDate THEN o.Total_amount ELSE 0 END) AS ExistingCustomerRevenue
FROM orders o
JOIN (
    SELECT 
        customer_id, 
        MIN(Bill_date_timestamp) AS FirstPurchaseDate
    FROM orders
    GROUP BY customer_id
) AS FirstPurchase ON o.customer_id = FirstPurchase.customer_id
GROUP BY 
    YEAR(o.Bill_date_timestamp),
    MONTH(o.Bill_date_timestamp)
ORDER BY 
    TransactionYear,
    TransactionMonth;

------------------------------------------------------------------------------------------- CUSTOMER BEHAVIOUR     ----------------------------------------------------------------------

/************************************************************
--Segment customer on the basis of revenue
************************************************************/

select Customer_id ,total_amt,NTILE(4) over (order by total_amt desc) as segment
from (select customer_id,SUM(total_amount) as total_amt
  from orders group by Customer_id) as a



/********************************************************************************	
Divide the customers into groups based on Recency, Frequency, and Monetary (RFM Segmentation) -  
Divide the customers into Premium, Gold, Silver, Standard customers and understand the behaviour of each segment of customers*/
/********************************************************************************/

----CTE

WITH rfm_data AS (
    -- Calculate RFM metrics for each customer
    SELECT 
        customer_id,
        DATEDIFF(DAY, MAX(bill_date_timestamp), GETDATE()) AS recency,
        COUNT(DISTINCT order_id) AS frequency,
        SUM(total_amount) AS monetary
    FROM orders
    GROUP BY customer_id
),
rfm_segments AS (
    -- Assign R, F, M segments and calculate RFM score
    SELECT 
        customer_id,
        recency,
        frequency,
        monetary,
        NTILE(4) OVER (ORDER BY recency ASC) AS r_segment, -- Smaller recency is better
        NTILE(4) OVER (ORDER BY frequency DESC) AS f_segment, -- Higher frequency is better
        NTILE(4) OVER (ORDER BY monetary DESC) AS m_segment, -- Higher monetary value is better
        -- Sum of R, F, and M segments
        NTILE(4) OVER (ORDER BY recency ASC) +
        NTILE(4) OVER (ORDER BY frequency DESC) +
        NTILE(4) OVER (ORDER BY monetary DESC) AS rfm_score
    FROM rfm_data
)
SELECT 
    customer_id,
    recency,
    frequency,
    monetary,
    r_segment,
    f_segment,
    m_segment,
    rfm_score,
    -- Assign categories based on RFM score
    CASE 
        WHEN rfm_score > 10 THEN 'Premium'
        WHEN rfm_score > 8 THEN 'Gold'
        WHEN rfm_score > 4 THEN 'Silver'
        ELSE 'Bronze'
    END AS customer_category
FROM rfm_segments
ORDER BY customer_category;


/********************************************************************************
---Find out the number of customers who purchased in all the channels and find the key metrics.
********************************************************************************/

select customer_id,SUM(total_amount)
from orders
group by customer_id
having COUNT (distinct Channel) =(select COUNT (distinct channel) from orders)



/********************************************************************************
    Understand the behaviour of discount seekers vs non discount seekers 
********************************************************************************/
-- Categorize customers into discount seekers and non-discount seekers

-----Every item in an order has discount


	WITH Order_Discount_Status AS (
    SELECT 
        Customer_id,
        Order_id,
        -- Ensure all products in the order have a discount (i.e., all products must have Discount > 0)
        MIN(CASE WHEN Discount > 0 THEN 1 ELSE 0 END) AS Has_Discount -- If any product in the order doesn't have a discount, the order isn't considered discounted
    FROM 
        orders
    GROUP BY 
        Customer_id, Order_id
),
Customer_Discount_Categories AS (
    SELECT 
        Customer_id,
        CASE 
            WHEN COUNT(*) = SUM(Has_Discount) THEN 'Discount Seeker' -- All orders have discounts (every product in every order has a discount)
            ELSE 'Non-Discount Seeker'
        END AS Discount_Category
    FROM 
        Order_Discount_Status
    GROUP BY 
        Customer_id
)
-- Calculate key metrics for discount seekers and non-discount seekers
SELECT 
    c.Discount_Category,
    COUNT(DISTINCT o.Customer_id) AS NumberOfCustomers,
    SUM(o.Total_amount) AS TotalRevenue,
    COUNT(DISTINCT o.Order_id) AS TotalOrders, -- Count distinct orders to avoid duplication
    AVG(o.Total_amount) AS AverageOrderValue
FROM 
    Customer_Discount_Categories c
JOIN 
    orders o ON c.Customer_id = o.Customer_id
GROUP BY 
    c.Discount_Category;


/********************************************************************************
		Understand the behaviour of customers who purchased one category and multiple categories 
********************************************************************************/


	------Using orders_agg table join productsinfo and total_amounts column instead of payment_value


with cte as (
select customer_id ,COUNT(distinct category) as cat_count
from orders as o join ProductsInfo as p on o.product_id =p.product_id
group by customer_id),

cte2 as 
	(select customer_id, case when cat_count> 1 then 'mutiple_cat_cust' else 'single_cat_cust' end as cust_type
	from cte )

	select cust_type,COUNT(distinct c.Customer_id) cust_count, COUNT(distinct order_id) order_cnt, SUM(total_amount) total_amount
	from orders as o join cte2 as c on o.customer_id=c.customer_id
	group by cust_type




	---------------------------------------------------------------------------------- CROSS SELLING --------------------------------------------------------------------------------


SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'joined_tables'; */

/********************************************************************************
--We need to find which of the top 10 combinations of products are selling together in each transaction.  (combination of 2 buying together) 
********************************************************************************/

SELECT top 10
    o1.product_id AS Product1, 
    o2.product_id AS Product2, 
    COUNT(*) AS Frequency
FROM 
    orders AS o1
JOIN 
    orders AS o2 
    ON o1.order_id = o2.order_id 
    AND o1.product_id < o2.product_id  -- Ensure no reversed pairs
GROUP BY 
    o1.product_id, o2.product_id
ORDER BY 
    Frequency DESC;

---	Suppose an order has three different products, then there will be 6 combinations (which is shown in 6 rows)


-------------------------------------------------------------------------------- Category behavior--------------------------------------------------------------------------------
/********************************************************************************
Total Sales & Percentage of sales by category (Perform Pareto Analysis)
********************************************************************************/

select category , (amounts*100.0/ SUM(amounts) over()) as contribution_percentage from (
	select category,SUM(total_amount) as amounts
	from orders as o join ProductsInfo as p on o.product_id=p.product_id
	group by category) as t
	order by contribution_percentage desc


/********************************************************************************
	--Most profitable category and its contribution
********************************************************************************/
WITH CategoryProfit AS (
    SELECT 
        category,
        SUM(payment_value - (Quantity * Cost_Per_Unit)) AS TotalProfit
    FROM 
        joined_tables
    GROUP BY 
        category
),

TotalProfitSum AS (
    SELECT 
        SUM(TotalProfit) AS OverallProfit
    FROM 
        CategoryProfit
)

SELECT 
    cp.category AS MostProfitableCategory,
    cp.TotalProfit AS CategoryProfit,
    (cp.TotalProfit / tp.OverallProfit) * 100 AS ContributionPercentage
FROM 
    CategoryProfit cp
CROSS JOIN 
    TotalProfitSum tp
ORDER BY 
    cp.TotalProfit DESC
OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY;


/********************************************************************************
--- Category Penetration Analysis by month on month (Category Penetration = number of orders containing the category/number of orders)
********************************************************************************/

WITH cte1 AS 
    (
        SELECT 
            YEAR(bill_date_timestamp) AS year, 
            MONTH(bill_date_timestamp) AS month, 
            COUNT(DISTINCT order_id) AS orders
        FROM orders
        GROUP BY 
            YEAR(bill_date_timestamp),
            MONTH(bill_date_timestamp)
    ),
    
cte2 AS 
    (
        SELECT 
            YEAR(bill_date_timestamp) AS year, 
            MONTH(bill_date_timestamp) AS month,
            category,
            COUNT(DISTINCT order_id) AS ordersContainingCategory
        FROM orders AS o 
        JOIN ProductsInfo AS p ON o.product_id = p.product_id
        GROUP BY 
            YEAR(bill_date_timestamp),
            MONTH(bill_date_timestamp),
            category
    )

SELECT 
    t1.year,
    t1.month,
    t2.category,
    (ordersContainingCategory * 100.0) / t1.orders AS cate_penetration
FROM cte1 AS t1 
JOIN cte2 AS t2 ON t1.year = t2.year AND t1.month = t2.month
ORDER BY 
    t1.year,
    t1.month;


	-------


/********************************************************************************
Most popular category during first purchase of customer 
********************************************************************************/


WITH First_Order AS (
    SELECT
        o.Customer_id,
        MIN(o.Order_id) AS First_Order_ID
    FROM 
        orders_agg o
    GROUP BY 
        o.Customer_id
),
Category_Count AS (
    SELECT
        p.category,
        COUNT(DISTINCT o.Order_id) AS Order_Count
    FROM 
        orders_agg o
    JOIN 
        productsInfo p ON o.Product_id = p.product_id
    JOIN 
        First_Order f ON o.Order_id = f.First_Order_ID
    GROUP BY 
        p.category
)
SELECT TOP 1
    category,
    Order_Count
FROM 
    Category_Count
ORDER BY 
    Order_Count DESC;

	/********************************************************************************
Avg. categories per bill month on month basis based on region
********************************************************************************/
	SELECT 
    YEAR(bill_date_timestamp) AS year,
    MONTH(bill_date_timestamp) AS month,
    region,
    COUNT(category) * 1.0 / COUNT(DISTINCT order_id) AS avg_cat_per_order
FROM 
    orders AS o
JOIN 
    stores_info AS s
    ON o.Delivered_StoreID = s.StoreID
JOIN 
    ProductsInfo AS p
    ON o.product_id = p.product_id
GROUP BY
    YEAR(bill_date_timestamp),
    MONTH(bill_date_timestamp),
    region
ORDER BY 
    year, 
    month;


----------------------------------------------------------Customer Satisfaction------------------------------------------------

/********************************************************************************
Average rating by location, store, product, category, month, etc
********************************************************************************/

--- Average rating by store


SELECT
    o.Delivered_StoreID,
    AVG(CAST(r.Customer_Satisfaction_Score AS DECIMAL(18, 2))) AS Average_Rating_Score
FROM
    orders_agg o
JOIN
    orderreview_ratings r ON o.Order_id = r.Order_id
GROUP BY
    o.Delivered_StoreID
ORDER BY
    o.Delivered_StoreID;



	------Average rating by category

		SELECT
    p.category,
    AVG(cast((r.Customer_Satisfaction_Score) as decimal(18,2))) AS Average_Rating_Score
FROM
    orders_agg o
JOIN
    orderreview_ratings r ON o.Order_id = r.Order_id
JOIN
    productsInfo p ON o.Product_id = p.product_id
GROUP BY
    p.category
ORDER BY
    p.category;


	---Average rating by month
		SELECT
    DATEPART(YEAR, o.Bill_date_timestamp) AS Year,
    DATEPART(MONTH, o.Bill_date_timestamp) AS Month,
    AVG(cast((r.Customer_Satisfaction_Score) as decimal (18,2))) AS Average_Rating_Score
FROM
    orders_agg o
JOIN
    orderreview_ratings r ON o.Order_id = r.Order_id
GROUP BY
    DATEPART(YEAR, o.Bill_date_timestamp),
    DATEPART(MONTH, o.Bill_date_timestamp)
ORDER BY
    Year,
    Month;

------------------------------------------------------------------------------------Seasonality and trend--------------------------------------------------------------------------------


/********************************************************************************
--Sales trend by month
********************************************************************************/
WITH MonthlySales AS (
    -- Aggregate sales amount by month
    SELECT
        DATEPART(YEAR, Bill_date_timestamp) AS sales_year,
        DATEPART(MONTH, Bill_date_timestamp) AS sales_month,
        SUM(Total_amounts) AS total_sales
    FROM orders_agg
    GROUP BY DATEPART(YEAR, Bill_date_timestamp), DATEPART(MONTH, Bill_date_timestamp)
)
-- Retrieve and order by year and month to show the sales trend over time
SELECT
    sales_year,
    sales_month,
    total_sales
FROM MonthlySales
ORDER BY sales_year, sales_month;

/********************************************************************************
--Total_sale by day of week
********************************************************************************/
SELECT
    DATENAME(WEEKDAY, Bill_date_timestamp) AS week_day,
    SUM(Total_amounts) AS total_sales
FROM orders_agg
GROUP BY DATENAME(WEEKDAY, Bill_date_timestamp), DATEPART(WEEKDAY, Bill_date_timestamp)
ORDER BY DATEPART(WEEKDAY, Bill_date_timestamp);

/********************************************************************************
--sales by week
********************************************************************************/
select year(bill_date_timestamp)year,datepart(week,bill_date_timestamp) week, sum(total_amount) as sales
from orders group by year(bill_date_timestamp),datepart(week,bill_date_timestamp)
order by year, week


---------------------------------------------------------------------------------COHORT ANALYSIS----------------------------------------------------------------------------------------------

	/********************************************************************************
	--Month by month retention rate ( distribution of customers from above query )
********************************************************************************/


	WITH CustomerCohort AS (
    -- Identify the first purchase for each customer (the cohort date)
    SELECT 
        Customer_id,
        MIN(DATEADD(MONTH, DATEDIFF(MONTH, 0, Bill_date_timestamp), 0)) AS Cohort_Date
    FROM 
        orders_agg
    GROUP BY 
        Customer_id
),

CohortSizes AS (
    -- Identify the cohort year, month, and the number of new customers in that cohort
    SELECT 
        DATEPART(YEAR, Cohort_Date) AS Cohort_Year,
        DATEPART(MONTH, Cohort_Date) AS Cohort_Month,
        COUNT(Customer_id) AS Cohort_Customers
    FROM 
        CustomerCohort
    GROUP BY 
        DATEPART(YEAR, Cohort_Date),
        DATEPART(MONTH, Cohort_Date)
),

CustomerOrders AS (
    -- Track distinct order_id counts per customer
    SELECT 
        Customer_id,
        COUNT(DISTINCT order_id) AS Distinct_Order_Count
    FROM 
        orders_agg
    GROUP BY 
        Customer_id
),

MonthByMonthRetention AS (
    -- Calculate how many months after their first purchase each customer made a repeat purchase
    SELECT 
        c.Customer_id,
        DATEPART(YEAR, c.Cohort_Date) AS Cohort_Year,
        DATEPART(MONTH, c.Cohort_Date) AS Cohort_Month,
        MIN(DATEDIFF(MONTH, c.Cohort_Date, o.Bill_date_timestamp)) AS Month_Offset
    FROM 
        orders_agg o
    INNER JOIN 
        CustomerCohort c ON o.Customer_id = c.Customer_id
    INNER JOIN 
        CustomerOrders co ON o.Customer_id = co.Customer_id
    WHERE 
        DATEDIFF(MONTH, c.Cohort_Date, o.Bill_date_timestamp) >= 1
        AND co.Distinct_Order_Count > 1 -- Ensure more than one distinct order_id
    GROUP BY 
        c.Customer_id, c.Cohort_Date
)

-- Final query to calculate retention month by month
SELECT 
    cs.Cohort_Year,
    cs.Cohort_Month,
    cs.Cohort_Customers,
    -- Retained customers in each subsequent month (Month 1 to Month 12)
    SUM(CASE WHEN r.Month_Offset = 1 THEN 1 ELSE 0 END) AS Month_1_Retention,
    SUM(CASE WHEN r.Month_Offset = 2 THEN 1 ELSE 0 END) AS Month_2_Retention,
    SUM(CASE WHEN r.Month_Offset = 3 THEN 1 ELSE 0 END) AS Month_3_Retention,
    SUM(CASE WHEN r.Month_Offset = 4 THEN 1 ELSE 0 END) AS Month_4_Retention,
    SUM(CASE WHEN r.Month_Offset = 5 THEN 1 ELSE 0 END) AS Month_5_Retention,
    SUM(CASE WHEN r.Month_Offset = 6 THEN 1 ELSE 0 END) AS Month_6_Retention,
    SUM(CASE WHEN r.Month_Offset = 7 THEN 1 ELSE 0 END) AS Month_7_Retention,
    SUM(CASE WHEN r.Month_Offset = 8 THEN 1 ELSE 0 END) AS Month_8_Retention,
    SUM(CASE WHEN r.Month_Offset = 9 THEN 1 ELSE 0 END) AS Month_9_Retention,
    SUM(CASE WHEN r.Month_Offset = 10 THEN 1 ELSE 0 END) AS Month_10_Retention,
    SUM(CASE WHEN r.Month_Offset = 11 THEN 1 ELSE 0 END) AS Month_11_Retention,
    SUM(CASE WHEN r.Month_Offset = 12 THEN 1 ELSE 0 END) AS Month_12_Retention
FROM 
    MonthByMonthRetention r
RIGHT JOIN 
    CohortSizes cs ON r.Cohort_Year = cs.Cohort_Year AND r.Cohort_Month = cs.Cohort_Month
GROUP BY 
    cs.Cohort_Year,
    cs.Cohort_Month,
    cs.Cohort_Customers
ORDER BY 
    cs.Cohort_Year, 
    cs.Cohort_Month;








