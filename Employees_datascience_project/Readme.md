Business Context:
You have been hired as a new data engineer at Analytixlabs. Your first major task is to work on data engineering/data 
science project for one of the big corporation’s employees data from the 1980s and 1995s. 

Data Availability:
All the database of employees from that period are provided six CSV files. 

a. Titles (titles.csv):
 title_id – Unique id of type of employee (designation id) – Character – Not Null
 title – Designation – Character – Not Null

b. Employees (employees.csv):
 emp_no – Employee Id – Integer – Not Null
 emp_titles_id – designation id – Not Null
 birth_date – Date of Birth – Date Time – Not Null
 first_name – First Name – Character – Not Null
 last_name – Last Name – Character – Not Null
 sex – Gender – Character – Not Null
 hire_date – Employee Hire date –Date Time -Not Null
 no_of_projects – Number of projects worked on – Integer – Not Null
 Last_performance_rating – Last year performance rating – Character – Not Null
 left – Employee left the organization – Boolean – Not Null
 Last_date - Last date of employment (Exit Date) – Date Time 

c. Salaries (salaries.csv):
 emp_no – Employee id – Integer – Not Null
 Salary – Employee’s Salary – Integer – Not Null

d. Departments (departments.csv)
 dept_no - Unique id for each department – character – Not Null
 dept_name – Department Name – Character – Not Null

e. Department Managers (dept_manager.csv)
 dept_no - Unique id for each department – character – Not Null
 emp_no – Employee number (head of the department ) – Integer – Not Null

f. Department Employees (dept_emp.csv)
 emp_no – Employee id – Integer – Not Null
 dept_no - Unique id for each department – character – Not Null


Objective:
In this project, you will design data model with all the tables to hold data, import the CSVs into a SQL database, and perform analysis using SQL, PowerBI, Python using the data and create data and ML pipelines
