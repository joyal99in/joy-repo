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

# Define the features used in the model and input
MODEL_FEATURES = ['sex', 'title', 'Last_performance_rating', 'age_group', 'tenure_group']
INPUT_FEATURES = ['sex', 'title', 'Last_performance_rating', 'age', 'tenure']

# Extract features and their possible values/ranges from output.csv
def extract_features(data, input_features):
    features = {}
    for column in input_features:
        if column in data.columns:
            if data[column].dtype == "object" or data[column].nunique() < 10:
                features[column] = sorted(data[column].dropna().unique().tolist())
            elif column in ['age', 'tenure']:
                min_val = int(data[column].min())
                max_val = int(data[column].max())
                features[column] = (min_val, max_val)
        else:
            st.error(f"Column '{column}' not found in {csv_path}. Please check your CSV.")
            st.stop()
    return features

FEATURES = extract_features(default_data, INPUT_FEATURES)

# Function to map age and tenure to their respective groups
def get_groups(data, age, tenure):
    # Find the matching row in output.csv (assuming age and tenure combinations are unique enough)
    matching_row = data[(data['age'] == age) & (data['tenure'] == tenure)]
    if not matching_row.empty:
        return matching_row['age_group'].iloc[0], matching_row['tenure_group'].iloc[0]
    else:
        # Fallback: Find closest age and tenure if exact match not found
        closest_age = data.loc[(data['age'] - age).abs().idxmin()]
        closest_tenure = data.loc[(data['tenure'] - tenure).abs().idxmin()]
        return closest_age['age_group'], closest_tenure['tenure_group']

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
        st.write(f"Enter employee details to predict churn (based on features: {', '.join(INPUT_FEATURES)}).")
        
        input_data = {}
        for feature, options in FEATURES.items():
            if isinstance(options, list):  # Categorical
                input_data[feature] = st.selectbox(f"{feature.capitalize()}", options)
            elif isinstance(options, tuple):  # Numerical (age, tenure)
                min_val, max_val = options
                input_data[feature] = st.number_input(
                    f"{feature.capitalize()}",
                    min_value=min_val,
                    max_value=max_val,
                    step=1
                )
        
        if st.button("Predict"):
            # Map age and tenure to their groups from output.csv
            age_group, tenure_group = get_groups(default_data, input_data['age'], input_data['tenure'])
            input_data_processed = {
                'sex': input_data['sex'],
                'title': input_data['title'],
                'Last_performance_rating': input_data['Last_performance_rating'],
                'age_group': age_group,
                'tenure_group': tenure_group
            }
            input_df = pd.DataFrame([input_data_processed])
            
            try:
                input_df = input_df[pipeline.feature_order]  # Align with training order
                prediction = pipeline.predict(input_df)[0]
                result = "Leave" if prediction == 1 else "Stay"
                st.success(f"Prediction: **{result}**")
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
            
            # Keep original age and tenure for display
            if 'age' in new_data.columns and 'tenure' in new_data.columns:
                original_data = new_data[INPUT_FEATURES].copy()  # Store input features for display
                new_data[['age_group', 'tenure_group']] = new_data.apply(
                    lambda row: pd.Series(get_groups(default_data, row['age'], row['tenure'])), 
                    axis=1
                )
            else:
                original_data = new_data[INPUT_FEATURES].copy()  # If no age/tenure, use what's available
            
            try:
                predict_data = new_data[MODEL_FEATURES]  # Use model features for prediction
                predict_data = predict_data[pipeline.feature_order]  # Align with training order
                predictions = pipeline.predict(predict_data)
                # Create result table with original input features and prediction
                result_data = original_data.copy()
                result_data["Prediction"] = ["Leave" if p == 1 else "Stay" for p in predictions]
                total_employees = len(result_data)
                employees_leaving = sum(predictions)
                attrition_rate = (employees_leaving / total_employees) * 100 if total_employees > 0 else 0
                if ids is not None:
                    result_data = pd.concat([ids, result_data], axis=1)
                st.metric(
                    label="Predicted Attrition Rate",
                    value=f"{attrition_rate:.2f}%",
                    delta=f"{employees_leaving} out of {total_employees} employees"
                )
                st.write("Prediction Results:")
                st.write(result_data)
                csv = result_data.to_csv(index=False).encode("utf-8")
                st.download_button("Download Predictions", csv, "predictions.csv", "text/csv")
            except KeyError:
                st.error(f"Uploaded CSV must have columns: {', '.join(pipeline.feature_order)} or 'age' and 'tenure'")

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