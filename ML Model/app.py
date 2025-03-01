import streamlit as st
import pandas as pd
import joblib
import os

# Load trained model
pipeline = joblib.load("model_pipeline.pkl")

# Automatically load output.csv from the same folder
csv_path = "output.csv"
if not os.path.exists(csv_path):
    st.error(f"Could not find {csv_path} in the same folder as app.py. Please ensure it exists.")
    st.stop()

try:
    default_data = pd.read_csv(csv_path)
except Exception as e:
    st.error(f"Error loading {csv_path}: {e}")
    st.stop()

# Define the features used in the model (exactly as in your ML code)
MODEL_FEATURES = ['dept_name', 'title', 'Last_performance_rating', 'salary', 'no_of_projects', 'tenure']

# Extract features and their possible values/ranges from output.csv, only for model features
def extract_features(data, model_features):
    features = {}
    for column in model_features:
        if column in data.columns:
            if data[column].dtype == "object" or data[column].nunique() < 10:
                features[column] = sorted(data[column].dropna().unique().tolist())
            else:
                min_val = int(data[column].min())
                max_val = int(data[column].max())
                features[column] = (min_val, max_val)
        else:
            st.error(f"Column '{column}' not found in {csv_path}. Please check your CSV.")
            st.stop()
    return features

FEATURES = extract_features(default_data, MODEL_FEATURES)

# Initialize session state for authentication
if "authenticated" not in st.session_state:
    st.session_state["authenticated"] = False

# Login function
def check_login(username, password):
    expected_username = "admin"
    expected_password = "1999"
    if username == expected_username and password == expected_password:
        st.success("Login successful!")
        return True
    else:
        st.error("Incorrect username or password.")
        return False

# Main app function
def main_app():
    st.title("Employee Churn Prediction")
    st.write("Predict whether an employee will stay or leave by entering their details.")

    tab1, tab2 = st.tabs(["Enter Employee Details", "Upload CSV"])

    with tab1:
        st.write(f"Enter employee details to predict churn (based on features: {', '.join(MODEL_FEATURES)}).")
        
        input_data = {}
        for feature, options in FEATURES.items():
            if isinstance(options, list):  # Categorical
                input_data[feature] = st.selectbox(f"{feature.capitalize()}", options)
            elif isinstance(options, tuple):  # Numerical
                min_val, max_val = options
                input_data[feature] = st.number_input(
                    f"{feature.capitalize()}",
                    min_value=min_val,
                    max_value=max_val,
                    step=1 if "salary" not in feature.lower() else 1000
                )
        
        if st.button("Predict"):
            input_df = pd.DataFrame([input_data])
            try:
                input_df = input_df[pipeline.feature_order]  # Align with training order
                prediction = pipeline.predict(input_df)[0]
                result = "Leave" if prediction == 1 else "Stay"
                st.success(f"Prediction: **{result}**")
                st.write("Input Data:")
                st.write(input_df)
            except Exception as e:
                st.error(f"Error making prediction: {e}")

    with tab2:
        st.write("Upload a CSV file to predict churn for multiple employees.")
        uploaded_file = st.file_uploader("Upload CSV", type=["csv"])
        if uploaded_file is not None:
            new_data = pd.read_csv(uploaded_file)
            id_cols = ["emp_no"]
            available_id_cols = [col for col in id_cols if col in new_data.columns]
            if available_id_cols:
                ids = new_data[available_id_cols]
                new_data = new_data.drop(columns=available_id_cols)
            else:
                ids = None
            try:
                new_data = new_data[pipeline.feature_order]  # Only use model features
                predictions = pipeline.predict(new_data)
                new_data["Prediction"] = ["Leave" if p == 1 else "Stay" for p in predictions]
                total_employees = len(new_data)
                employees_leaving = sum(predictions)
                attrition_rate = (employees_leaving / total_employees) * 100 if total_employees > 0 else 0
                if ids is not None:
                    new_data = pd.concat([ids, new_data], axis=1)
                st.metric(
                    label="Predicted Attrition Rate",
                    value=f"{attrition_rate:.2f}%",
                    delta=f"{employees_leaving} out of {total_employees} employees"
                )
                st.write("Prediction Results:")
                st.write(new_data)
                csv = new_data.to_csv(index=False).encode("utf-8")
                st.download_button("Download Predictions", csv, "predictions.csv", "text/csv")
            except KeyError:
                st.error(f"Uploaded CSV must have columns: {', '.join(pipeline.feature_order)}")

# Conditional rendering based on authentication state
if not st.session_state["authenticated"]:
    st.title("Login")
    st.write("Please log in to access the Employee Churn Prediction app.")
    username = st.text_input("Username", value="")
    password = st.text_input("Password", type="password", value="")
    if st.button("Login"):
        if check_login(username, password):
            st.session_state["authenticated"] = True
            st.rerun()
else:
    main_app()