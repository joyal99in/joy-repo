--SQL Advance Case Study
use mobile_sales_db

  select top 1* from DIM_CUSTOMER
  select top 1* from DIM_DATE
  select top 1* from DIM_LOCATION
  select top 1* from DIM_MANUFACTURER
  select top 1* from DIM_MODEL
  select top 1* from FACT_TRANSACTIONS

  --Count of rows
SELECT 'Customer Count' as 'Table', COUNT(*) as 'Count' FROM DIM_CUSTOMER
UNION ALL
SELECT 'Date Count', COUNT(*) FROM DIM_DATE
UNION ALL
SELECT 'Location Count', COUNT(*) FROM DIM_LOCATION
UNION ALL
SELECT 'Manufacturer Count', COUNT(*) FROM DIM_MANUFACTURER
UNION ALL
SELECT 'Model Count', COUNT(*) FROM DIM_MODEL
UNION ALL
SELECT 'Transaction Count', COUNT(*) FROM FACT_TRANSACTIONS


--List all the states in which we have customers who have bought cellphones  from 2005 till today. 

select distinct(State) as States from FACT_TRANSACTIONS as f
inner join  DIM_LOCATION as d
on f.IDLocation=d.IDLocation
where YEAR(f.Date)>=2005
 

--What state in the US is buying the most 'Samsung' cell phones? 

  select top 1 State,SUM(Quantity) as quantity from DIM_LOCATION as t1 
  join 
  FACT_TRANSACTIONS as t2
  on t1.IDLocation=t2.IDLocation 
  join 
  DIM_MODEL as t3 on t2.IDModel=t3.IDModel
  join 
  DIM_MANUFACTURER as t4 on t3.IDManufacturer=t4.IDManufacturer
  where Country='US' and Manufacturer_Name= 'samsung'
  group by State
  order by quantity desc


--Show the number of transactions for each model per zip code per state  

	select Model_Name,State ,ZipCode,COUNT(*) as Tl_trans from DIM_LOCATION as d 
	join FACT_TRANSACTIONS as f 
	on d.IDLocation=f.IDLocation
	join DIM_MODEL as m
	on f.IDmodel=m.IDmodel 
	group by Model_Name,State,ZipCode


--Show the cheapest cellphone with price

select top 1 Model_Name,Unit_price from DIM_MODEL
order by Unit_price asc


--Find average price for each model in the top5 manufacturers in  terms of sales quantity and order by average price.

select Model_Name,AVG(TotalPrice) as Avg_price from DIM_MANUFACTURER as t1 join
DIM_MODEL as t2 on t1.IDManufacturer=t2.IDManufacturer join
FACT_TRANSACTIONS as t3 on t2.IDModel=t3.IDModel 

where manufacturer_Name in
(select top 5 Manufacturer_Name from DIM_MANUFACTURER as t1 join
DIM_MODEL as t2 on t1.IDManufacturer=t2.IDManufacturer join
FACT_TRANSACTIONS as t3 on t2.IDModel=t3.IDModel
group by Manufacturer_Name
order by sum(TotalPrice) desc)
group by Model_Name
order by Avg_price desc


--List the names of the customers and the average amount spent in 2009, where the average is higher than 500

select customer_Name,avg(TotalPrice) as avg_Price from DIM_CUSTOMER as t1 join
FACT_TRANSACTIONS as t2
on t1.IDCustomer=t2.IDCustomer
where YEAR(date)=2009 
group by Customer_Name
having avg(TotalPrice)>500

	
--List if there is any model that was in the top 5 in terms of quantity,  simultaneously in 2008, 2009 and 2010

WITH TopModels AS (
    SELECT YEAR(date) as Year, Model_name, RANK() OVER(PARTITION BY YEAR(date) ORDER BY SUM(Quantity) DESC) as Rank
    FROM DIM_MODEL as t1 
    JOIN fact_transactions as t2 ON t1.idmodel=t2.IDModel
    WHERE YEAR(date) BETWEEN 2008 AND 2010
    GROUP BY YEAR(date), Model_Name
)
SELECT Model_name
FROM TopModels
WHERE Rank <= 5
GROUP BY Model_name
HAVING COUNT(DISTINCT Year) = 3

/* Show the manufacturer with the 2nd top sales in the year of 2009 and the  
manufacturer with the 2nd top sales in the year of 2010.   */

;WITH Sales AS (
    SELECT 
        Manufacturer_Name,
        YEAR(date) AS Year,
        SUM(Totalprice) AS Tl_sales,
        ROW_NUMBER() OVER (PARTITION BY YEAR(date) ORDER BY SUM(Totalprice) DESC) as SalesRank
    FROM 
        DIM_MANUFACTURER as t1 
        JOIN DIM_MODEL as t2 ON t1.IDmanufacturer=t2.IDManufacturer 
        JOIN FACT_TRANSACTIONS as t3 ON t2.IDModel=t3.IDModel
    WHERE 
        YEAR(date) IN (2009, 2010)
    GROUP BY 
        Manufacturer_Name,
        YEAR(date)
)
SELECT Manufacturer_Name, Year, Tl_sales FROM Sales WHERE SalesRank = 2


--Show the manufacturers that sold cellphones in 2010 but did not in 2009

select Manufacturer_Name from DIM_MANUFACTURER as t1 
join DIM_MODEL as t2 
on t1.IDManufacturer=t2.IDManufacturer 
join FACT_TRANSACTIONS as t3
on t2.IDModel=t3.IDModel
where YEAR(date)=2010
group by Manufacturer_Name

except

select Manufacturer_Name from DIM_MANUFACTURER as t1
join DIM_MODEL as t2 
on t1.IDManufacturer=t2.IDManufacturer 
join FACT_TRANSACTIONS as t3
on t2.IDModel=t3.IDModel
where YEAR(date)=2009
group by Manufacturer_Name

/*Top 10 customers and their average spend each  year. Also their percentage of change in their spend.*/  

;WITH CustomerSpend AS (
    SELECT customer_name, YEAR(date) as year, SUM(totalprice) as totalprice
    FROM DIM_CUSTOMER as t1
    JOIN FACT_TRANSACTIONS as t2
    ON t1.IDCustomer=t2.IDCustomer
    GROUP BY customer_name, YEAR(date)
), TopCustomers AS (
    SELECT TOP 10 customer_name, SUM(totalprice) as totalprice
    FROM CustomerSpend
    GROUP BY customer_name
    ORDER BY SUM(totalprice) DESC
), RankedCustomers AS (
    SELECT cs.customer_name, cs.year, cs.totalprice,
           ROW_NUMBER() OVER(PARTITION BY cs.customer_name ORDER BY cs.year) as row_number
    FROM CustomerSpend cs
    JOIN TopCustomers tc
    ON cs.customer_name = tc.customer_name
)

SELECT customer_name, year, AVG(totalprice) as avg_spend, 
       ((AVG(totalprice) - LAG(AVG(totalprice)) OVER (PARTITION BY customer_name ORDER BY year)) / LAG(AVG(totalprice)) OVER (PARTITION BY customer_name ORDER BY year)) * 100 as Spend_Change_Percentage
FROM RankedCustomers
WHERE row_number <= 10
GROUP BY customer_name, year
ORDER BY customer_name, year






