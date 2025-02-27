import streamlit as st
import pandas as pd
import joblib

# Load trained model
pipeline = joblib.load("model_pipeline.pkl")

# Streamlit App
st.title("Employee Churn Prediction")
st.write("Upload a CSV file to predict whether employees will stay or leave.")

# Upload file
uploaded_file = st.file_uploader("Upload CSV", type=["csv"])

if uploaded_file is not None:
    # Load new data
    new_data = pd.read_csv(uploaded_file)

    # Preserve Employee ID if available
    id_cols = ["emp_no"]  # Adjust based on your dataset
    available_id_cols = [col for col in id_cols if col in new_data.columns]

    if available_id_cols:
        ids = new_data[available_id_cols]  # Save IDs
        new_data = new_data.drop(columns=available_id_cols)  # Drop before prediction
    else:
        ids = None  # No IDs available

    # Ensure correct column order and make predictions
    try:
        new_data = new_data[pipeline.feature_order]

        # Make predictions
        predictions = pipeline.predict(new_data)

        # Add Predictions
        new_data["Prediction"] = ["Leave" if p == 1 else "Stay" for p in predictions]

        # Calculate attrition rate
        total_employees = len(new_data)
        employees_leaving = sum(predictions)  # Count of 1s in predictions
        attrition_rate = (employees_leaving / total_employees) * 100 if total_employees > 0 else 0

        # Reattach Employee ID if available
        if ids is not None:
            new_data = pd.concat([ids, new_data], axis=1)

        # Display attrition rate metric
        st.metric(
            label="Predicted Attrition Rate",
            value=f"{attrition_rate:.2f}%",
            delta=f"{employees_leaving} out of {total_employees} employees"
        )

        # Show results
        st.write("Prediction Results:")
        st.write(new_data)

        # Download results
        csv = new_data.to_csv(index=False).encode("utf-8")
        st.download_button("Download Predictions", csv, "predictions.csv", "text/csv")

    except KeyError:
        st.error("Uploaded CSV does not have the correct columns. Please check your file.")