--SQL Advance Case Study
use [db_SQLCaseStudies]
  select top 1* from [dbo].[DIM_CUSTOMER]
  select top 1* from[dbo].[DIM_DATE]
  select top 1* from[dbo].[DIM_LOCATION]
  select top 1* from[dbo].[DIM_MANUFACTURER]
  select top 1* from[dbo].[DIM_MODEL]
  select top 1* from[dbo].[FACT_TRANSACTIONS]

--Q1--BEGIN 
select distinct(State) as States from [dbo].[FACT_TRANSACTIONS] as f
inner join  [dbo].[DIM_LOCATION] as d
on f.IDLocation=d.IDLocation
where YEAR(f.Date)>=2005
 
--Q1--END

--Q2--BEGIN
	select top 1 state,count(*) as cnt from DIM_LOCATION as d 
	join FACT_TRANSACTIONS as f 
	on d.IDLocation=f.IDLocation
	join DIM_MODEL as m
	on f.IDmodel=m.IDmodel 
	join DIM_MANUFACTURER as t4
	on m.IDManufacturer=t4.IDManufacturer
	where Country='US' and Manufacturer_Name='Samsung'
	group by state
	order by cnt desc
--Q2--END

--Q3--BEGIN      
	select Model_Name,State ,ZipCode,COUNT(*) as Tl_trans from DIM_LOCATION as d 
	join FACT_TRANSACTIONS as f 
	on d.IDLocation=f.IDLocation
	join DIM_MODEL as m
	on f.IDmodel=m.IDmodel 
	group by Model_Name,State,ZipCode
--Q3--END

--Q4--BEGIN
select top 1 Model_Name,min(Unit_price) as min_price from DIM_MODEL
group by Model_Name
order by min_Price asc
--Q4--END

--Q5--BEGIN
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


--Q5--EN

--Q6--BEGIN
select customer_Name,avg(TotalPrice) as avg_Price from DIM_CUSTOMER as t1 join
FACT_TRANSACTIONS as t2
on t1.IDCustomer=t2.IDCustomer
where YEAR(date)=2009 
group by Customer_Name
having avg(TotalPrice)>500
--Q6--END
	
--Q7--BEGIN  
select t3.model_name from(
select top 5 Model_name, sum(Quantity ) as qnt from DIM_MODEL as t1 join
fact_transactions as t2
on t1.idmodel=t2.IDModel
where YEAR(date)=2008
group by Model_Name
order by qnt desc) as t3 join

(select top 5 Model_name, sum(Quantity ) as qnt from DIM_MODEL as t1 join
fact_transactions as t2
on t1.idmodel=t2.IDModel
where YEAR(date)=2009
group by Model_Name
order by qnt desc) as t4 
on t3.Model_name=t4.Model_Name
join
(select top 5 Model_name, sum(Quantity ) as qnt from DIM_MODEL as t1 join
fact_transactions as t2
on t1.idmodel=t2.IDModel
where YEAR(date)=2010
group by Model_Name
order by qnt desc) as t5
on t4.model_name=t5.model_name
--Q7--END	

--Q8--BEGIN

select*from(
select top 1* from (select top 2 Manufacturer_Name,year(date) as Year,SUM(Totalprice) as Tl_sales from DIM_MANUFACTURER as t1 join
DIM_MODEL as t2 
on t1.IDmanufacturer=t2.IDManufacturer join
FACT_TRANSACTIONS as t3 
on t2.IDModel=t3.IDModel
where year(date)=2009
group by Manufacturer_Name,year(date)
order by Tl_sales desc) as a 
order by Tl_sales asc) as c

union

select*from
(
select top 1* from (select top 2 Manufacturer_Name,year(date) as Year,SUM(Totalprice) as Tl_sales from DIM_MANUFACTURER as t1 join
DIM_MODEL as t2 
on t1.IDmanufacturer=t2.IDManufacturer join
FACT_TRANSACTIONS as t3 
on t2.IDModel=t3.IDModel
where year(date)=2010
group by Manufacturer_Name,year(date)
order by Tl_sales desc) as b
order by Tl_sales asc) as d

--Q8--END

--Q9--BEGIN

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

--Q9--END

--Q10--BEGIN

select customer_name,year(date) as year ,avg(TotalPrice) as avg_price , Sum(Quantity) as Qty from DIM_CUSTOMER as t3 join
FACT_TRANSACTIONS as t4 on t3.IDCustomer=t4.IDCustomer
where customer_name in(select top 100 customer_name from DIM_CUSTOMER as t1 join
FACT_TRANSACTIONS as t2 on t1.IDCustomer=t2.IDCustomer
group by customer_name,year(date)
order by sum(totalprice) desc)
group by customer_name,year(date)

--Q10--END
	