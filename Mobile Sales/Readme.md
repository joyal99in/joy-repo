## 📱 Business Scenario

The database **"Cellphones Information"** contains detailed records of **cell phone sales and transactions**.

---

## 💾 Data Overview

The database is structured with the following tables:

| Table Name           | Description                                                   |
|-----------------------|---------------------------------------------------------------|
| `Dim_Manufacturer`    | Stores details of cellphone manufacturers.                    |
| `Dim_Model`           | Stores information about cellphone models.                    |
| `Dim_Customer`        | Stores information about customers.                           |
| `Dim_Location`        | Stores information about sales locations.                     |
| `Fact_Transactions`   | Stores transaction-level details of cellphone sales.          |

The **dimension tables** (`Dim_Manufacturer`, `Dim_Model`, `Dim_Customer`, `Dim_Location`) store metadata for the respective entities, while the **fact table** (`Fact_Transactions`) records all **sales transactions** for specific cellphones.

---

## 🎯 Objective

The data can be used to analyze:

- Sales performance by **manufacturer, model, or location**.
- Customer purchase trends.
- Business insights for strategic decision-making.

---

