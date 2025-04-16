# Employee Data Engineering & Analytics Project

## 📊 Business Context

You have been hired as a new data engineer at **Analytixlabs**. Your first major task is to work on a **data engineering / data science** project for one of the big corporation’s employee datasets, covering records from the **1980s to the 1990s**.

---

## 💾 Data Availability

All employee-related data from that period is provided in the form of **six CSV files**:

### a. `titles.csv` — Titles

| Column Name | Description                          | Data Type | Constraint |
|-------------|--------------------------------------|-----------|------------|
| `title_id`  | Unique ID of the employee's designation | Character | Not Null   |
| `title`     | Employee's designation title         | Character | Not Null   |

---

### b. `employees.csv` — Employees

| Column Name              | Description                           | Data Type | Constraint |
|---------------------------|---------------------------------------|-----------|------------|
| `emp_no`                  | Employee ID                          | Integer   | Not Null   |
| `emp_titles_id`           | Designation ID (FK to `titles`)      | Character | Not Null   |
| `birth_date`              | Date of Birth                        | DateTime  | Not Null   |
| `first_name`              | First Name                           | Character | Not Null   |
| `last_name`               | Last Name                            | Character | Not Null   |
| `sex`                     | Gender                               | Character | Not Null   |
| `hire_date`               | Hire Date                            | DateTime  | Not Null   |
| `no_of_projects`          | Number of projects worked on         | Integer   | Not Null   |
| `Last_performance_rating` | Last year’s performance rating       | Character | Not Null   |
| `left`                    | Employee left the organization       | Boolean   | Not Null   |
| `Last_date`               | Last date of employment (Exit Date)  | DateTime  | Nullable   |

---

### c. `salaries.csv` — Salaries

| Column Name | Description          | Data Type | Constraint |
|-------------|----------------------|-----------|------------|
| `emp_no`    | Employee ID          | Integer   | Not Null   |
| `Salary`    | Employee’s Salary    | Integer   | Not Null   |

---

### d. `departments.csv` — Departments

| Column Name | Description                | Data Type | Constraint |
|-------------|----------------------------|-----------|------------|
| `dept_no`   | Unique ID for each department | Character | Not Null   |
| `dept_name` | Department Name            | Character | Not Null   |

---

### e. `dept_manager.csv` — Department Managers

| Column Name | Description                            | Data Type | Constraint |
|-------------|----------------------------------------|-----------|------------|
| `dept_no`   | Unique ID for each department          | Character | Not Null   |
| `emp_no`    | Employee Number (Head of Department)   | Integer   | Not Null   |

---

### f. `dept_emp.csv` — Department Employees

| Column Name | Description                | Data Type | Constraint |
|-------------|----------------------------|-----------|------------|
| `emp_no`    | Employee ID                | Integer   | Not Null   |
| `dept_no`   | Unique ID for each department | Character | Not Null   |

---

## 🎯 Objective

In this project, your goals are:

- Design a **data model** to structure and hold all the provided datasets.
- Import the CSV files into a **SQL database**.
- Perform **data analysis** using SQL, Power BI, and Python.
- Build **data pipelines** and **ML pipelines** for analytical tasks and business insights.

---
