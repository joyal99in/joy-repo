import streamlit as st
import pandas as pd
import plotly.express as px
import numpy as np
import calendar

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
    div[data-baseweb="select"] > div {
        cursor: pointer !important;
    }
    </style>
    """,
    unsafe_allow_html=True
)

# Load and process data
@st.cache_data
def load_data():
    try:
        df = pd.read_csv("output.csv", on_bad_lines='warn')
    except Exception as e:
        st.error(f"Failed to load data: {e}")
        return None
    
    df['birth_date'] = pd.to_datetime(df['birth_date'], format='%Y-%m-%d', errors='coerce')
    df['hire_date'] = pd.to_datetime(df['hire_date'], format='%Y-%m-%d', errors='coerce')
    df['last_date'] = pd.to_datetime(df['last_date'], errors='coerce')  # Fix here
    df['hire_month'] = df['hire_date'].dt.month
    
    return df

def main_app():
    final_df = load_data()
    if final_df is None:
        st.stop()

    st.sidebar.header("Filters")

    def dropdown_with_select_all(label, options, default_label="Select All"):
        options_with_all = [default_label] + options
        selected_option = st.sidebar.selectbox(label, options_with_all)
        return options if selected_option == default_label else [selected_option]

    dept_filter = dropdown_with_select_all("Select Department", final_df['dept_name'].unique().tolist())
    title_filter = dropdown_with_select_all("Select Job Title", final_df['title'].unique().tolist())
    gender_filter = dropdown_with_select_all("Select Gender", final_df['sex'].unique().tolist())
    left_filter = dropdown_with_select_all("Select Employment Status", final_df['left'].unique().tolist())

    filtered_df = final_df[
        (final_df['dept_name'].isin(dept_filter)) &
        (final_df['title'].isin(title_filter)) &
        (final_df['sex'].isin(gender_filter)) &
        (final_df['left'].isin(left_filter))
    ]

    st.title("Employee Data Analytics Dashboard")
    st.markdown("### Interactive Workforce Insights")

    if filtered_df.empty:
        st.warning("⚠️ No data available! Please select appropriate categories in filters to display the graph.")
        st.stop()
    
    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Total Employees", filtered_df['emp_no'].nunique())
    col2.metric("Average Age", f"{filtered_df['age'].mean():.1f} years")
    col3.metric("Average Salary", f"${filtered_df['salary'].mean():,.0f}")
    col4.metric("Turnover Rate", f"{(len(filtered_df[filtered_df['left'] == True]) / len(filtered_df) * 100):.1f}%")

    tab1, tab2, tab3,tab4 = st.tabs(["Demographics Analysis", "Compensation Analysis", "Performance Analysis","Hiring & Attrition Analysis"])

    with tab1:
        col1, col2 = st.columns(2)
        
        with col1:
            filtered_df = filtered_df.drop_duplicates(subset='emp_no', keep='first')
            fig = px.histogram(
                filtered_df, 
                x='age', 
                title='Age Distribution', 
                nbins=20, 
                color_discrete_sequence=['skyblue']
            )

            # Update Y-axis title
            fig.update_layout(yaxis_title="Number of Employees")

            st.plotly_chart(fig, use_container_width=True)

        
        with col2:
            filtered_df=filtered_df.drop_duplicates(subset='emp_no',keep='first')
            fig = px.pie(filtered_df, names='sex', title='Gender Distribution')
            st.plotly_chart(fig, use_container_width=True)
        
        col3, col4 = st.columns(2)

        with col3:
            fig = px.pie(filtered_df, names='dept_name', title='Employee Distribution by Department')
            st.plotly_chart(fig, use_container_width=True)

        with col4:
            filtered_df=filtered_df.drop_duplicates(subset='emp_no',keep='first')
            fig = px.pie(filtered_df, names='title', title='Employee Distribution by Job Title')
            st.plotly_chart(fig, use_container_width=True)

    with tab2:
        col1, col2 = st.columns(2)
        
        with col1:
            data = filtered_df.sort_values(by='salary', ascending=False)
            fig = px.box(data, x='dept_name', y='salary', title='Salary Distribution by Department')
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            data = filtered_df.drop_duplicates(subset=['emp_no']).sort_values(by='salary', ascending=False)
            fig = px.box(data, x='title', y='salary', title='Salary Distribution by Job Title')
            st.plotly_chart(fig, use_container_width=True)

    with tab3:
        col1 = st.columns([1])[0]
        with col1:
            filtered_df = filtered_df.drop_duplicates(subset='emp_no', keep='first')
        
            ratings = filtered_df['Last_performance_rating'].value_counts().reset_index()
            ratings.columns = ['Rating', 'Count']
            
            fig = px.pie(ratings, names='Rating', values='Count', title='Performance Rating Distribution', color_discrete_sequence=px.colors.sequential.Sunset)
            
            st.plotly_chart(fig, use_container_width=True)


    with tab4:
        col1, col2 = st.columns(2)

        with col1:
            filtered_df = filtered_df.drop_duplicates(subset='emp_no', keep='first')
            hires = filtered_df.groupby(filtered_df['hire_date'].dt.year)['emp_no'].count()
            leaves = filtered_df.groupby(filtered_df['last_date'].dt.year)['emp_no'].count()

            fig = px.line(title="Yearly Employee Hires & Attrition")
            fig.add_scatter(x=hires.index, y=hires.values, mode='lines+markers', name='Hires')
            fig.add_scatter(x=leaves.index, y=leaves.values, mode='lines+markers', name='Attrition', yaxis="y2")

            fig.update_layout(
                xaxis_title="Year",  # Added X-axis title
                yaxis=dict(title="Number of Hires"),
                yaxis2=dict(title="Number of Attrition", overlaying="y", side="right"),
            )

            st.plotly_chart(fig, use_container_width=True)


        with col2:
            filtered_df = filtered_df.drop_duplicates(subset='emp_no', keep='first')
            all_months = np.arange(1, 13)
            data = filtered_df.groupby('hire_month')['emp_no'].count().reindex(all_months, fill_value=0)

            # Convert numeric month index to actual month names
            month_names = [calendar.month_name[m] for m in data.index]  

            fig = px.line(x=month_names, y=data.values, markers=True, title="Monthly Hiring Trend")
            fig.update_layout(xaxis_title="Month", yaxis_title="Number of Hires")

            st.plotly_chart(fig, use_container_width=True)


        
    st.markdown("---")
    st.caption("Employee Analytics Dashboard - Created with Streamlit")

main_app()
