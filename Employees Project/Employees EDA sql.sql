create database employees_db
use employees_db

--Joined table
 select * into final_data
 from
 (select e.*,
 em.dept_no,
 d.dept_name,
 s.salary,
 t.title
from employees as e 
join dept_emp as em on e.emp_no=em.emp_no
join departments as d on em.dept_no=d.dept_no 
join salaries as s on e.emp_no=s.emp_no
join titles as t on e.emp_title_id=t.title_id
) as t


---EDA
/* A list showing employee number, last name, first name, sex, 
and salary for each employee */

select e.emp_no,last_name,first_name,sex,salary
from employees as e join salaries as s on
e.emp_no=s.emp_no

/*A list showing first name, last name, 
and hire date for employees who were hired in 1986.*/
select first_name,
		last_name,
		hire_date
from employees
where year(hire_date)=1986

/*A list showing the manager of each department with the following information: department number, department name, 
the manager's employee number, last name, first name.*/
select dept_no,
		dept_name,
		emp_no,
		last_name,
		first_name
FROM FINAL_DATA
WHERE title='manager'
order by dept_no

/*A list showing the department of each employee with the following information: employee number, last name, first 
name, and department name*/
select emp_no,
		last_name,
		first_name,
		dept_name
from final_data

/*A list showing first name, last name, 
and sex for employees whose first name is "Hercules" and last names begin with "B.*/
select distinct first_name,
		last_name,
		sex
from employees
where first_name ='Hercules' and last_name like'B%'

/*A list showing all employees in the Sales department, including their employee number, last name, first name, and 
department name.*/
select emp_no,
		last_name,
		first_name,
		dept_name
from final_data
where dept_name='sales'

/*A list showing all employees in the Sales and Development departments, including their employee number, last name, 
first name, and department name.*/
select
	last_name,
	first_name,
	dept_name
from final_data
where dept_name in ('sales','development')

/*A list showing the frequency count of employee last names, in descending order. ( i.e., how many employees share each 
last name*/
select last_name,count(*) as name_count 
from employees
group by last_name
order by count(*) desc

/* Calculate employee tenure & show the tenure distribution among the employees*/
with cte as
(
select emp_no,
hire_date,
last_date,
case when last_date is null then floor(datediff(day,hire_date,(select max(last_date) from employees))/365.25) 
	when last_date is not null then floor(datediff(day,hire_date,last_date)/365.25) end as tenure
from employees
)
select tenure,count(*) as number_of_employees
from cte
group by tenure
order by tenure desc

/*Employees by rating*/
select Last_performance_rating,count(*) as employee_count 
from employees
group by Last_performance_rating
order by employee_count desc

/* Distribution of salary of employees*/
select emp_no,
		salary,
		ntile(4) over (order by salary) as salary_quartile
from salaries

/*what is the average salary of each profession*/

with cte as
(select emp_no,title,salary,
row_number()over (partition by emp_no order by (select null)) as row_num
from final_data)

SELECT 
    title,
    AVG(CAST(salary AS BIGINT)) AS avg_salary
FROM cte
where row_num=1
GROUP BY title
ORDER BY avg_salary DESC;

/*what are the professions where salary > avg salary */

with cte as
(select emp_no,title,salary,
row_number()over (partition by emp_no order by (select null)) as row_num
from final_data),

cte2 as
(
SELECT 
    title,
    AVG(CAST(salary AS BIGINT)) AS avg_salary
FROM cte
where row_num=1
GROUP BY title)

select * from cte2 
where avg_salary > (select avg(avg_salary) from cte2)

/*Male to Female ratio*/

select 
round(count(case when sex='m' then 1 end)*1.0
		/count(case when sex='f' then 1 end),2)
as MtoF_ratio
from employees

/* Male to female ratio by titles*/

with cte as
(
select emp_no,title,sex,
row_number()over (partition by emp_no order by (select null)) as row_num
from final_data)

select title,
round(count(case when sex='m' then 1 end)*1.0
		/count(case when sex='f' then 1 end),2)
as MtoF_ratio
from cte
where row_num=1
group by title

/* Male to female ratio by departments*/
select dept_name,
round(count(case when sex='m' then 1 end)*1.0
		/count(case when sex='f' then 1 end),2)
as MtoF_ratio
from final_data
group by dept_name

/* Employees who has done the most projects */
with cte as
(
select emp_no,
	no_of_projects,
	dense_rank() over (order by no_of_projects desc) as denserank
from final_data
)
select * from cte
where denserank=(select min(denserank) from cte)

/*average age of employees*/
with cte as
(
select emp_no,
case when last_date is null then floor(datediff(day,birth_date,(select max(last_date) from employees))/365.25) 
	when last_date is not null then floor(datediff(day,birth_date,last_date)/365.25) end as age
	from employees
)
select avg(age) as avg_age from cte

/*average age of employees by title*/
with cte as
(
select emp_no,
title,
case when last_date is null then floor(datediff(day,birth_date,(select max(last_date) from employees))/365.25) 
	when last_date is not null then floor(datediff(day,birth_date,last_date)/365.25) end as age
	from final_data
)
select title,avg(age) as avg_age
from cte
group by title

/* Avg. Salary by experience by job title*/
select title,
floor(datediff(day,hire_date,last_date)/365.25) as experience_years,
avg(salary) as avg_salary
from final_data
where last_date is not null 
group by title,floor(datediff(day,hire_date,last_date)/365.25)
order by title,experience_years asc

select * from final_data

/* Number of employees by department*/
select dept_name,count(*) as employee_count
from final_data
group by dept_name
order by employee_count desc

/* Number of employees by title along with percentage of total workforce*/
select title,
	count(*) as employee_count,
	round(count(*)*100.0/
	(select count(emp_no) from final_data),2) as Percent_of_total_workforce
from final_data
group by title
order by employee_count desc

/* Percentage fo each performance rating*/
select last_performance_rating,
		count(*) as rating_count,
		round(count(*)*100.0/ (select count(*) from employees),2) as Percentage_of_total
from employees
group by Last_performance_rating
order by rating_count desc

--Average salary

select avg(salary*1.0) from salaries
select * from salaries

--avg monthly hire

with cte as
(
select year(hire_date) hire_year,
month(hire_date)hire_month,
count(*) hire_count
from employees
group by year(hire_date),month(hire_date)
)

select avg(hire_count) as avg_monthly_hire
from cte

--Month with highest hire

select year(hire_date) hire_year,
month(hire_date)hire_month,
count(*) hire_count
from employees
group by year(hire_date),month(hire_date)
order by hire_count desc

--EMployee with highest salary
select * from final_data
where salary=(select max(salary) from final_data)


--Male to female ratio
select count(case when sex='M' then 1 end)*1.0/
		count(case when sex='F' then 1 end) as ratio
from employees

--Average salary by gender
select
(select count(emp_no) from final_data)-
(select count (distinct emp_no) from final_data)

---Employees currently working
select count(emp_no) from employees
where [left]=0

--Attrition rate
select count(case when [left]=1 then 1 end)*100.0/
		(select count(emp_no) from employees)  as attrition_rate
from employees

--Avg tenure
with cte as(
select emp_no,
case when last_date is null then
	floor(datediff(day,hire_date,(select max(last_date) from employees))/365.25)
else 
	floor(datediff(day,hire_date,last_date)/365.25) end as Tenure
from employees
)

---Employee manager ratio
select
(select count(emp_no) from employees)/
(select count(emp_no) from dept_manager)

--Attrition rate
select count (case when [left]= 1 then 1 end) *100.0/
		(select count(emp_no) from employees) as attrition_rate
from employees

--avg tenure

with cte as
(
select emp_no,
case when last_date is null then floor(datediff(day,hire_date,(select max(last_date) from employees))/365.25)
	else floor(datediff(day,hire_date,last_date)/365.25) end as tenure
from employees)

select avg(tenure) as aveg_tenure from cte

--manager department ratio
select (select count(emp_no) from dept_manager)*1.0 /
		(select count(dept_no) from departments) manager_dept_ratio

--salary range
select max(salary) from salaries
select min(salary) from salaries

--currently working employees
select * from employees
where [left]=0

-- Employees who left
select * from employees
where [left]=1




