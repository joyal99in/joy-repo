use mobile_sales_db

select top 5 * from DIM_CUSTOMER
select top 5 * from DIM_DATE
select top 5 * from DIM_LOCATION
select top 5 * from DIM_MANUFACTURER
select top 5 * from DIM_MODEL
select top 5 * from FACT_TRANSACTIONS

select  * from DIM_CUSTOMER
select  * from DIM_DATE
select  * from DIM_LOCATION
select  * from DIM_MANUFACTURER
select  * from DIM_MODEL
select  * from FACT_TRANSACTIONS


--Joined_table
select * into final_data from
(
select f.*,
md.Model_Name,
md.unit_price,
md.IDmanufacturer,
ma.manufacturer_name,
l.zipcode,
l.country,
l.state,
l.city,
c.customer_name,
email,
phone
from FACT_TRANSACTIONS as f 
join DIM_MODEL as md
on f.IDModel=md.IDModel
join DIM_MANUFACTURER as ma 
on md.IDManufacturer=ma.IDManufacturer
join DIM_LOCATION as l 
on f.IDLocation=l.IDLocation
join DIM_CUSTOMER as c
on f.IDCustomer=c.IDCustomer) as t

select * from final_data

--List all the states in which we have customers who have bought cellphones  
--from 2005 till today
select distinct state from final_data
where year(date)>=2005

--What state in the US is buying the most 'Samsung' cell phones?
select Top 1 state,count(*) as  sales_count from final_data
where country='US'
group by state
order by sales_count desc

--Show the number of transactions for each model per zip code per state
select model_name,state,zipcode,count(*) sales_count
from final_data
group by model_name,state,zipcode

--Show the cheapest cellphone (Output should contain the price also) 
select distinct model_name, unit_price from final_data
where unit_price=(select min(unit_price) from final_data)

-- Find out the average price for each model in the top5 manufacturers in  
--terms of sales quantity and order by average price

with cte as
(
select top 5 manufacturer_name,
sum(Quantity) as total_quantity
from final_data
group by manufacturer_name
order by total_quantity desc
)

select model_name, avg(unit_price) as avg_price
from final_data
where manufacturer_name in (select Manufacturer_Name from cte)
group by model_name

--List the names of the customers and the average amount spent in 2009,  
--where the average is higher than 500
select Customer_Name,avg(totalprice) as avg_amt
from final_data
where year(date)=2009
group by Customer_Name
having avg(totalprice)>500

-- List if there is any model that was in the top 5 in terms of quantity,  
--simultaneously in 2008, 2009 and 2010  

 with cte1 as
 (select top 5 model_name, sum(quantity) as qty
 from final_data
 where year(date)= 2008
 group by model_name
 order by qty desc),
 
 cte2 as
 (select top 5 model_name, sum(quantity) as qty
 from final_data
 where year(date)= 2009
 group by model_name
 order by qty desc
 ),
 
 cte3 as
 (select top 5 model_name, sum(quantity) as qty
 from final_data
 where year(date)= 2010
 group by model_name
 order by qty desc
 )

 select model_name from
 cte1 intersect 
 select model_name from cte2 
 intersect 
 select model_name from cte3 

 --Method 2
with cte1 as
(
select year(date) as year_date,
	model_name,
	rank() over(partition by year(date) order by sum(quantity) desc) as rank_num
from final_data
where year(date) between 2008 and 2010
group by year(date),model_name
 )

 select model_name 
 from cte1
 where rank_num<=5
 group by Model_Name
 having count(year_date)=3


 --Show the manufacturer with the 2nd top sales in the year of 2009 and the  
--manufacturer with the 2nd top sales in the year of 2010

with cte1 as
( 
select year(date) as year,manufacturer_name,
	sum(totalprice) as amount
from final_data
where year(date)=2009
group by year(date),Manufacturer_Name
order by amount desc
offset 1 row Fetch next 1 row only
),

 cte2 as
( 
select year(date) as year,
	manufacturer_name,
	sum(totalprice) as amount
from final_data
where year(date)=2010
group by year(date),Manufacturer_Name
order by amount desc
offset 1 row Fetch next 1 row only
)

select  * from
cte1
union
select * from cte2


--Method 2
with cte as
(
select year(date) as year,
	manufacturer_name,
	sum(totalprice) as amount,
	row_number() over(partition by year(date) order by sum(totalprice) desc) as row_num
from final_data
where year(date) in(2009,2010)
group by year(date) ,manufacturer_name
)

select year,
manufacturer_name,
amount
from cte 
where row_num=2


---Show the manufacturers that sold cellphones in 2010 but did not in 2009
select manufacturer_name from final_data
where year(date) =2010 
except
select manufacturer_name from final_data
where year(date) =2009


--Find top 10 customers and their average spend, average quantity by each  
--year. Also find the percentage of change in their spend.  

WITH cte AS (
    SELECT TOP 10 customer_name,
           SUM(totalprice) AS amount
    FROM final_data
    GROUP BY customer_name
    ORDER BY amount DESC
),

cte2 as
(
SELECT 
    YEAR(date) AS year,
    customer_name,
    AVG(totalprice * 1.0) AS avg_price,
    AVG(quantity * 1.0) AS avg_qty,
    SUM(totalprice) AS amount,
    LAG(SUM(totalprice)) OVER (PARTITION BY customer_name ORDER BY YEAR(date)) AS prev_amount
FROM final_data
WHERE customer_name IN (SELECT customer_name FROM cte)
GROUP BY YEAR(date), customer_name
)

select year,
customer_name,
avg_price,
avg_qty,
amount,
(amount-prev_amount)*100.0/amount as percentage_change
from cte2




