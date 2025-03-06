import streamlit as st
import pandas as pd
import joblib

# Load trained model
pipeline = joblib.load("model_pipeline.pkl")

# Define the features used in the model and input
MODEL_FEATURES = ['sex', 'title', 'dept_name', 'Last_performance_rating', 'age_group', 'tenure_group']
INPUT_FEATURES = ['sex', 'title', 'dept_name', 'Last_performance_rating', 'age', 'tenure']

# Extract categorical options from the pipeline's OneHotEncoder
def extract_categorical_options(pipeline):
    ohe = pipeline.named_steps['preprocessor'].named_transformers_['cat']
    categorical_cols = ['sex', 'title', 'dept_name', 'Last_performance_rating', 'age_group', 'tenure_group']
    features = {}
    for i, col in enumerate(categorical_cols):
        features[col] = ohe.categories_[i].tolist()
    return features

# Define FEATURES without loading a CSV
FEATURES = extract_categorical_options(pipeline)
FEATURES['age'] = (18, 100)  # Reasonable range for age
FEATURES['tenure'] = (0, 50)  # Reasonable range for tenure

# Function to map age and tenure to their groups using stored bins
def get_groups(age, tenure, pipeline):
    age_group = pd.cut([age], bins=pipeline.age_bins, labels=pipeline.age_labels, include_lowest=True)[0]
    tenure_group = pd.cut([tenure], bins=pipeline.tenure_bins, labels=pipeline.tenure_labels, include_lowest=True)[0]
    return age_group, tenure_group

# Login function
def check_login(username, password):
    expected_username = "admin"
    expected_password = "1999"
    return username == expected_username and password == expected_password

# Main app function
def main_app():
    st.title("Employee Churn Prediction")
    st.write("Predict whether an employee will stay or leave by entering their details.")

    tab1, tab2 = st.tabs(["Enter Employee Details", "Upload CSV"])

    with tab1:
        st.write(f"Enter employee details to predict churn (based on features: {', '.join(INPUT_FEATURES)}).")
        
        input_data = {}
        for feature in INPUT_FEATURES:
            if feature in ['age', 'tenure']:
                min_val, max_val = FEATURES[feature]
                input_data[feature] = st.number_input(
                    f"{feature.capitalize()}",
                    min_value=min_val,
                    max_value=max_val,
                    step=1
                )
            else:
                input_data[feature] = st.selectbox(f"{feature.capitalize()}", FEATURES[feature])
        
        if st.button("Predict"):
            age_group, tenure_group = get_groups(input_data['age'], input_data['tenure'], pipeline)
            input_data_processed = {
                'sex': input_data['sex'],
                'title': input_data['title'],
                'dept_name': input_data['dept_name'],
                'Last_performance_rating': input_data['Last_performance_rating'],
                'age_group': age_group,
                'tenure_group': tenure_group
            }
            input_df = pd.DataFrame([input_data_processed])
            
            try:
                input_df = input_df[pipeline.feature_order]
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
            
            # Define required columns (still need dates from CSV to calculate age/tenure)
            required_cols = {'sex', 'title', 'dept_name', 'Last_performance_rating', 'hire_date', 'birth_date', 'last_date'}
            id_cols = ["emp_no"]
            
            # Check for required columns
            if not required_cols.issubset(new_data.columns):
                st.error(f"Uploaded CSV must contain columns: {', '.join(required_cols)}")
                st.stop()
            
            # Select only required columns and optional ID column
            cols_to_keep = list(required_cols) + [col for col in id_cols if col in new_data.columns]
            new_data = new_data[cols_to_keep]
            
            # Extract IDs if present
            available_id_cols = [col for col in id_cols if col in new_data.columns]
            if available_id_cols:
                ids = new_data[available_id_cols]
            else:
                ids = None
            
            # Preprocess raw date columns to calculate age and tenure
            new_data['hire_date'] = pd.to_datetime(new_data['hire_date'], format='%Y-%m-%d')
            new_data['birth_date'] = pd.to_datetime(new_data['birth_date'], format='%Y-%m-%d')
            new_data['last_date'] = pd.to_datetime(new_data['last_date'], format='%Y-%m-%d')
            new_data['last_date'] = new_data['last_date'].fillna(new_data['last_date'].max())
            new_data['age'] = (new_data['last_date'] - new_data['birth_date']).dt.days // 365
            new_data['tenure'] = (new_data['last_date'] - new_data['hire_date']).dt.days // 365
            new_data['age_group'] = pd.cut(new_data['age'], 
                                          bins=pipeline.age_bins, 
                                          labels=pipeline.age_labels, 
                                          include_lowest=True)
            new_data['tenure_group'] = pd.cut(new_data['tenure'], 
                                             bins=pipeline.tenure_bins, 
                                             labels=pipeline.tenure_labels, 
                                             include_lowest=True)
            
            # Prepare data for prediction
            try:
                predict_data = new_data[MODEL_FEATURES]
                predict_data = predict_data[pipeline.feature_order]
                predictions = pipeline.predict(predict_data)
                
                # Use INPUT_FEATURES (with age and tenure) for display instead of dates
                original_data = new_data[INPUT_FEATURES].copy()
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
                st.error(f"Error: Ensure CSV has required columns: {', '.join(pipeline.feature_order)}")

# Conditional rendering for login
if "authenticated" not in st.session_state:
    st.session_state["authenticated"] = False

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