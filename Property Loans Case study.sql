CREATE DATABASE Loans;
use Loans

--Print all the databases available in the SQL Server.
SELECT name FROM master.sys.databases

-- Print the names of the tables from the Loans database
SELECT name as Tablename
FROM sys.tables

--Print 5 records in each table
select top 5 * from Banker
select top 5 * from Customer
select top 5 * from Home_Loan
select top 5 * from Loan_Records;


--find top 5 customers in each city in terms of property value

;WITH city_ranks AS (
    SELECT 
        t3.city, 
        concat(t1.first_name,' ',t1.last_name) as full_name, 
        t3.property_value,
        rank() OVER (PARTITION BY t3.city ORDER BY t3.property_value DESC) as rank
    FROM Customer AS t1 
    JOIN Loan_Records AS t2 ON t1.customer_id = t2.customer_id 
    JOIN Home_Loan as t3 ON t2.loan_id = t3.loan_id
)
SELECT 
    city, 
    full_name, 
    property_value
FROM city_ranks
WHERE rank <= 5;


-- Find the average age of male bankers

SELECT Round(AVG(DATEDIFF(DAY, dob, date_joined)/365.25),1) as Average_Age
FROM Banker
WHERE gender = 'Male'


--number of home loans issued in San Francisco

select COUNT(*) as home_loan_Count from Home_Loan 
where city='San Francisco'


--Top 3 cities (based on descending alphabetical order) and 
--corresponding loan percent (in ascending order) with the lowest average loan percent

SELECT top 3 city, AVG(loan_percent) as Average_Loan_Percent
FROM Home_Loan
GROUP BY city
ORDER BY Average_Loan_Percent ASC,city DESC 


--total number of different cities for which home loans have been issued
select count (distinct city) as Distinct_city from home_loan


--maximum property value of each property type, ordered by the maximum property value in descending order
SELECT property_type, MAX(property_value) as Max_Property_Value
FROM Home_Loan
GROUP BY property_type
ORDER BY Max_Property_Value DESC;


--Find the customer ID, first name, last name, and email of customers whose email address contains the term 'amazon'
SELECT customer_id, first_name, last_name, email
FROM customer
WHERE email LIKE '%amazon%';


--Find the average age of female customers who took a non-joint loan for townhomes

SELECT ROUND(AVG(DATEDIFF(year, A.dob, A.transaction_date)), 0) AS average_age
FROM (
    SELECT t1.customer_id,t1.gender,  t1.dob,t2.transaction_date,t3.property_type, t3.joint_loan
    FROM customer AS t1 
    JOIN Loan_Records AS t2 ON t1.customer_id = t2.customer_id
    JOIN Home_Loan AS t3 ON t2.loan_id = t3.loan_id
) as A
WHERE A.gender = 'Female' AND A.joint_loan = 'No' AND A.property_type = 'Townhome';


--Find the ID, first name, and last name of top 2 bankers , transaction count with highest number of distinct loan records

SELECT TOP 2 t1.banker_id, t1.first_name, t1.last_name, COUNT(DISTINCT t2.loan_id) AS distinct_transaction_count
FROM Banker AS t1 
JOIN Loan_Records AS t2 ON t1.banker_id = t2.banker_id
GROUP BY t1.banker_id, t1.first_name, t1.last_name
ORDER BY distinct_transaction_count DESC


--Average loan term for loans not for semi-detached and townhome & in cities: 
--Sparks, Biloxi, Waco, Las Vegas, and Lansing

SELECT ROUND(AVG(CAST(loan_term AS DECIMAL)), 2) AS average_loan_term
FROM Home_Loan
WHERE property_type NOT IN ('Semi-Detached', 'Townhome')
AND city IN ('Sparks', 'Biloxi', 'Waco', 'Las Vegas', 'Lansing')


--Find the city name and the corresponding average property value for cities 
--where the average property value is greater than $3,000,000

SELECT city, AVG(property_value) AS average_property_value
FROM Home_Loan
GROUP BY city
HAVING AVG(property_value) > 3000000


--Find the sum of the loan amounts for each banker ID, excluding properties based in the cities of Dallas and Waco

SELECT t1.banker_id, ROUND(SUM(t3.property_value * t3.loan_percent / 100), 0) AS loan_amount
FROM Banker AS t1 
JOIN Loan_Records AS t2 ON t1.banker_id = t2.banker_id 
JOIN Home_Loan as t3 ON t2.loan_id = t3.loan_id
WHERE t3.city NOT IN ('Dallas', 'Waco')
GROUP BY t1.banker_id


--Find the number of bankers involved in loans where the loan amount is greater than the average loan amount

;WITH LoanAmounts AS (
    SELECT t1.banker_id, (t3.property_value * t3.loan_percent / 100) as loan_amount
    FROM Banker AS t1 
    JOIN Loan_Records AS t2 ON t1.banker_id = t2.banker_id 
    JOIN Home_Loan as t3 ON t2.loan_id = t3.loan_id
)
SELECT COUNT(DISTINCT banker_id) as above_avg_bankers
FROM LoanAmounts
WHERE loan_amount > (SELECT AVG(loan_amount) FROM LoanAmounts)
Go
--Create a view called `dallas_townhomes_gte_1m` which returns all the details of loans 
--involving properties of townhome type, located in Dallas, and have loan amount of >$1 million

CREATE VIEW dallas_townhomes_gte_1m AS
SELECT *
FROM Home_Loan
WHERE property_type = 'Townhome'
AND city = 'Dallas'
AND (property_value * loan_percent / 100) > 1000000
Go
SELECT *
FROM dallas_townhomes_gte_1m
Go

--Create a stored procedure called `recent_joiners` that returns the ID, concatenated full name, 
--date of birth, and join date of bankers who joined within the recent 2 years (as of 1 Sep 2022) 

CREATE PROCEDURE recent_joiners
AS
BEGIN
    SELECT banker_id, CONCAT(first_name, ' ', last_name) AS full_name, dob, date_joined
    FROM Banker
    WHERE date_joined >= DATEADD(year, -2, '2022-09-01');
END
Go
EXEC recent_joiners
Go

--stored procedure `city_and_above_loan_amt` based on the city San Francisco and loan amount cutoff of $1.5 million 
--that returns the full details of customers

CREATE PROCEDURE city_and_above_loan_amt @city_name varchar(255), @loan_amt_cutoff decimal(18, 2)
AS
BEGIN
    SELECT *
    FROM Customer AS t1 
    JOIN Loan_Records AS t2 ON t1.customer_id = t2.customer_id
    JOIN Home_Loan as t3 ON t2.loan_id = t3.loan_id
    WHERE t3.city = @city_name AND (t3.property_value * t3.loan_percent / 100) >= @loan_amt_cutoff;
END;
EXEC city_and_above_loan_amt 'San Francisco', 1500000;


---ID, first name and last name of customers with properties of value between $1.5 and $1.9 million 

SELECT t1.customer_id, t1.first_name, t1.last_name,
CASE 
    WHEN customer_since < '2015-01-01' THEN 'Long'
    WHEN customer_since >= '2015-01-01' AND customer_since < '2019-01-01' THEN 'Mid'
    ELSE 'Short'
END as tenure
FROM Customer AS t1 
JOIN Loan_Records AS t2 ON t1.customer_id = t2.customer_id
JOIN Home_Loan as t3 ON t2.loan_id = t3.loan_id
WHERE (t3.property_value * t3.loan_percent / 100) BETWEEN 1500000 AND 1900000;


--Find the top 3 transaction dates (and corresponding loan amount sum) 
--for which the sum of loan amount issued on that date is the highest

SELECT TOP 3 transaction_date, SUM(property_value * loan_percent / 100) as total_loan_amount
FROM Home_Loan as t1
JOIN Loan_Records as t2
ON t1.loan_id = t2.loan_id
GROUP BY transaction_date
ORDER BY total_loan_amount DESC;


--Number of Chinese customers with joint loans with property values less than $2.1 million, and served by female bankers

SELECT COUNT( t1.customer_id) as Customer_Count
FROM Customer AS t1 
JOIN Loan_Records AS t2 ON t1.customer_id = t2.customer_id 
JOIN Home_Loan as t3 ON t2.loan_id = t3.loan_id 
JOIN Banker as t4 on t2.banker_id=t4.banker_id
WHERE t1.nationality = 'China' 
AND t3.property_value < 2100000 
AND t3.joint_loan = 'Yes' 
AND t4.gender = 'Female';


--Find the ID and full name of customers who were served by bankers aged below 30 (as of 1 Aug 2022).
SELECT t1.customer_id, CONCAT(t1.first_name, ' ', t1.last_name) AS full_name
FROM Customer AS t1 
JOIN Loan_Records AS t2 ON t1.customer_id = t2.customer_id 
JOIN Banker as t3 on t2.banker_id=t3.banker_id
WHERE DATEDIFF(year, t3.dob, '2022-08-01') < 30;

