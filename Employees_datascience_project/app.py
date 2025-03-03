# app.py
import streamlit as st
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import requests
from io import StringIO
import numpy as np

# Enable wide layout for better content spacing
st.set_page_config(layout="wide")

# Reduce sidebar width using custom CSS
st.markdown(
    """
    <style>
        [data-testid="stSidebar"] {
            min-width: 220px;
            max-width: 220px;
        }
    </style>
    """,
    unsafe_allow_html=True
)

st.markdown(
    """
    <style>
    /* Force pointer cursor for dropdowns */
    div[data-baseweb="select"] > div {
        cursor: pointer !important;
    }
    </style>
    """,
    unsafe_allow_html=True
)

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

# Load and process data
@st.cache_data
def load_data():
    # Google Drive share link
    gdrive_link = "https://drive.google.com/file/d/1bmRppo8E-HnDflQeU8tBAnd-5XN3yTFn/view?usp=sharing"
    
    # Extract file ID from the link
    file_id = gdrive_link.split('/d/')[1].split('/')[0]
    
    # Construct the direct download URL
    download_url = f"https://drive.google.com/uc?export=download&id={file_id}"
    
    # Fetch the CSV file
    try:
        response = requests.get(download_url)
        response.raise_for_status()  # Raise an error if the request fails
    except requests.exceptions.RequestException as e:
        st.error(f"Failed to fetch data from Google Drive: {e}")
        return None

    # Try to parse the CSV content
    try:
        csv_content = StringIO(response.text)
        df = pd.read_csv(csv_content, on_bad_lines='warn')
    except pd.errors.ParserError as e:
        st.error(f"Error parsing CSV: {e}")
        return None

    # Convert birth_date and hire_date to datetime format
    df['birth_date'] = pd.to_datetime(df['birth_date'], format='%Y-%m-%d', errors='coerce')
    df['hire_date'] = pd.to_datetime(df['hire_date'], format='%Y-%m-%d', errors='coerce')
    df['hire_date'] = pd.to_datetime(df['hire_date'], format='%Y-%m-%d', errors='coerce')

    # Extract hire month
    df['hire_month'] = df['hire_date'].dt.month

    return df

# Main app function
def main_app():
    # Load data
    final_df = load_data()

    # Stop if data loading failed
    if final_df is None:
        st.stop()

    # Sidebar filters
    st.sidebar.header("Filters")

    # Function to create a dropdown with "Select All"
    def dropdown_with_select_all(label, options, default_label="Select All"):
        options_with_all = [default_label] + options  # Add "Select All" at the top
        selected_option = st.sidebar.selectbox(label, options_with_all)  # No typing allowed
        return options if selected_option == default_label else [selected_option]

    # Department Filter
    dept_filter = dropdown_with_select_all("Select Department", final_df['dept_name'].unique().tolist())

    # Job Title Filter
    title_filter = dropdown_with_select_all("Select Job Title", final_df['title'].unique().tolist())

    # Gender Filter
    gender_filter = dropdown_with_select_all("Select Gender", final_df['sex'].unique().tolist())

    # Employment Status Filter
    left_filter = dropdown_with_select_all("Select Employment Status", final_df['left'].unique().tolist())

    # Apply filters
    filtered_df = final_df[
        (final_df['dept_name'].isin(dept_filter)) &
        (final_df['title'].isin(title_filter)) &
        (final_df['sex'].isin(gender_filter)) &
        (final_df['left'].isin(left_filter))
    ]

    # Main app content
    st.title("Employee Data Analytics Dashboard")
    st.markdown("### Interactive Workforce Insights")

    # Check for empty dataframe
    if filtered_df.empty:
        st.warning("⚠️ No data available! Please select appropriate categories in filters to display the graph.")
        st.stop()  # Stops Streamlit from running the rest of the code!

    # Row 1: Key Metrics
    else:
        col1, col2, col3, col4 = st.columns(4)
        col1.metric("Total Employees", filtered_df['emp_no'].nunique())
        col2.metric("Average Age", f"{filtered_df['age'].mean():.1f} years")
        col3.metric("Average Salary", f"${filtered_df['salary'].mean():,.0f}")
        col4.metric("Turnover Rate", 
                f"{(len(filtered_df[filtered_df['left'] == True]) / len(filtered_df) * 100):.1f}%")

    # Tabs for different visualizations
    tab1, tab2, tab3 = st.tabs(["Demographics", "Compensation Analysis", "Performance Metrics"])

    with tab1:
        st.header("Demographic Insights")
        
        # Define equal-width columns
        col1, col2,col3 = st.columns([1.5, 1,1])
        
        with col1:
            # Age distribution
            plt.figure(figsize=(4, 2.9))
            plt.hist(filtered_df['age'], color='skyblue')
            plt.title('Histogram of Age', fontsize=12, fontweight='bold')
            plt.ylabel('Frequency', fontweight='bold')
            st.pyplot(plt, use_container_width=False)
        
        with col2:
            # Gender distribution
            data = filtered_df['sex'].value_counts()
            plt.figure(figsize=(3,2))
            plt.pie(data, 
                    labels=data.index,
                    autopct='%1.1f%%',
                    wedgeprops={'edgecolor': 'black', 'linewidth': 1},
                    textprops={'fontsize': 6})
            plt.title('Gender Distribution', fontsize=10, fontweight='bold')
            st.pyplot(plt, use_container_width=False)
            
        col4, col5 = st.columns([1.5, 1])

        with col4:
        # Department distribution
            st.subheader("Departmental Employee Distribution")
            dept_counts = filtered_df['dept_name'].value_counts()
            plt.figure(figsize=(10,4))
            dept_counts.plot(kind='bar', color='lightgreen', edgecolor='black')
            plt.xticks(rotation=45, ha='right')
            plt.ylabel('Employee Count')
            plt.grid(axis='y', linestyle='--', alpha=0.7)
            st.pyplot(plt)

                # Show Gender Ratios by Department only when "Select All" is chosen
            if gender_filter == final_df['sex'].unique().tolist():  # "Select All" case
                st.subheader("Gender Ratios by Department")
                gender_dept = filtered_df.groupby(['dept_name', 'sex']).size().unstack()
                gender_dept['M/F Ratio'] = gender_dept['M'] / gender_dept['F']
                plt.figure(figsize=(10, 4))
                bars = plt.bar(gender_dept.index, gender_dept['M/F Ratio'], color='skyblue', edgecolor='black')
                plt.gca().bar_label(bars, fmt='%.2f')
                plt.xlabel("Department")
                plt.ylabel("Male to Female Ratio", fontweight='bold')
                plt.xticks(rotation=45, ha='right')
                plt.grid(axis='y', linestyle='--', alpha=0.7)
                plt.ylim(0, 2)
                st.pyplot(plt)
            else:
                st.warning("⚠️ M/F ratio chart cannot be displayed if Male or Female alone is selected")

    with tab2:
        st.header("Compensation Analysis")
        col1, col2 = st.columns(2)
        with col1:
            # Salary distribution
            plt.figure(figsize=(8,4.5))
            sns.boxplot(x=filtered_df['salary'], color='lightblue')
            plt.title('Salary Distribution')
            st.pyplot(plt)
        
        with col2:
            # Avg Salary by Title
            avg_salary = filtered_df.groupby('title')['salary'].mean().sort_values(ascending=False)
            plt.figure(figsize=(8,4))
            avg_salary.plot(kind='bar', color='salmon', edgecolor='black')
            plt.title('Average Salary by Job Title')
            plt.xticks(rotation=45, ha='right')
            plt.ylabel('Average Salary')
            st.pyplot(plt)
            
        # Salary by Department
        st.subheader("Salary Distribution by Department")
        plt.figure(figsize=(10,4))
        sns.boxplot(data=filtered_df, x='dept_name', y='salary')
        plt.xticks(rotation=45, ha='right')
        plt.xlabel('Department')
        plt.ylabel('Salary')
        st.pyplot(plt)

        # Salary by Title
        st.subheader("Salary Distribution by Title")
        plt.figure(figsize=(10,4))
        sns.boxplot(data=filtered_df, x='title', y='salary')
        plt.xticks(rotation=45, ha='right')
        plt.xlabel('Title')
        plt.ylabel('Salary')
        st.pyplot(plt)

    with tab3:
        col1, col2 = st.columns([2,1])
        with col1:
            st.subheader("Performance Rating of Employees")
            ratings = filtered_df['Last_performance_rating'].value_counts()
            plt.figure(figsize=(10,6))
            ratings.plot(kind='bar', color='gold', edgecolor='black')
            plt.title('Performance Rating Distribution', fontsize=16, fontweight='bold')
            plt.ylabel('Count')
            st.pyplot(plt, use_container_width=False)
        
        st.subheader("Employee Turnover")
        data = filtered_df['left'].value_counts()
        plt.figure(figsize=(1.5, 1.5))
        plt.pie(data, labels=data.index,
                autopct='%1.1f%%',
                wedgeprops={'edgecolor': 'black', 'linewidth': 0.5},
                textprops={'fontsize':5})
        plt.title('Employee Turnover', fontsize=7)
        plt.axis('equal')
        st.pyplot(plt, use_container_width=False)

    st.markdown("---")
    st.caption("Employee Analytics Dashboard - Created with Streamlit")

# Conditional rendering based on authentication state
if not st.session_state["authenticated"]:
    st.title("Login")
    st.write("Please log in to access the Employee Data Analytics Dashboard.")
    username = st.text_input("Username", value="")
    password = st.text_input("Password", type="password", value="")
    if st.button("Login"):
        if check_login(username, password):
            st.session_state["authenticated"] = True
            st.rerun()
else:
    main_app()