import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.pipeline import Pipeline
from sklearn.compose import ColumnTransformer
from imblearn.pipeline import Pipeline as ImbPipeline
from imblearn.over_sampling import SMOTE
from xgboost import XGBClassifier
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
import joblib
import requests
import io

# Fetch dataset from Google Drive
gdrive_link = "https://drive.google.com/file/d/15mtxIvQaeA6I9WV3m-O3MGeHRGYdTpHa/view?usp=sharing"
file_id = gdrive_link.split('/d/')[1].split('/')[0]
download_url = f"https://drive.google.com/uc?export=download&id={file_id}"

# Download the file
response = requests.get(download_url)
response.raise_for_status()  # Check for errors
final_df = pd.read_csv(io.StringIO(response.text))

# ================== 1️⃣ Keep Only Required Columns ==================
categorical_cols = ['dept_name', 'title', 'Last_performance_rating']
numerical_cols = ['salary', 'no_of_projects', 'tenure']
target = 'left'

# Keep only the required columns
final_df = final_df[categorical_cols + numerical_cols + [target]]

X = final_df.drop(columns=[target])  # Features
y = final_df[target].astype(int)  # Target (Convert to int: 0 = stayed, 1 = left)

# Store feature order before transformation
feature_order = X.columns.tolist()

# ================== 2️⃣ Train-Test Split ==================
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

# ================== 3️⃣ Define Preprocessing Pipeline ==================
preprocessor = ColumnTransformer([
    ('num', StandardScaler(), numerical_cols),
    ('cat', OneHotEncoder(handle_unknown='ignore', sparse_output=False), categorical_cols)
])

# ================== 4️⃣ Define Full Pipeline with SMOTE & XGBoost ==================
pipeline = ImbPipeline([
    ('preprocessor', preprocessor),
    ('smote', SMOTE(random_state=42)),
    ('classifier', XGBClassifier(n_estimators=100, learning_rate=0.1, max_depth=6, random_state=42))
])

# ================== 5️⃣ Train Model ==================
pipeline.fit(X_train, y_train)

# Store feature order inside pipeline
pipeline.feature_order = feature_order

# Save the trained pipeline
joblib.dump(pipeline, "ML Model/model_pipeline.pkl")
