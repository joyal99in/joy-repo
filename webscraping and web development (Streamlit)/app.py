import streamlit as st
from bs4 import BeautifulSoup
import pandas as pd
import re
import matplotlib.pyplot as plt
import json
import os
import requests

# User data storage file
USER_DATA_FILE = "users.json"
# Load user data from JSON file
def load_users():
    if os.path.exists(USER_DATA_FILE):
        with open(USER_DATA_FILE, "r") as f:
            return json.load(f)
    return {}
# Save user data to JSON file
def save_users(users):
    with open(USER_DATA_FILE, "w") as f:
        json.dump(users, f)
# Initialize session state
if 'authenticated' not in st.session_state:
    st.session_state.authenticated = False
if 'users' not in st.session_state:
    st.session_state.users = load_users()
if 'current_user' not in st.session_state:
    st.session_state.current_user = None
def handle_auth():
    st.title("🔒 Web Scraper Authentication")
    choice = st.sidebar.radio("Choose Option", ["Login", "Sign Up"], key="auth_choice")
    
    if choice == "Sign Up":
        with st.form("signup_form"):
            st.subheader("Create New Account")
            new_user = st.text_input("Username")
            new_pass = st.text_input("Password", type="password", max_chars=8)
            signup_button = st.form_submit_button("Sign Up")
            
            if signup_button:
                if len(new_pass) != 8:
                    st.error("Password must be exactly 8 digits")
                elif new_user in st.session_state.users:
                    st.error("Username already exists")
                else:
                    st.session_state.users[new_user] = new_pass
                    save_users(st.session_state.users)
                    st.success("Account created! Please login.")
                    st.session_state.auth_choice = "Login"
                    st.rerun()
    
    else:  # Login
        with st.form("login_form"):
            st.subheader("Login")
            username = st.text_input("Username")
            password = st.text_input("Password", type="password", max_chars=8)
            login_button = st.form_submit_button("Login")
            
            if login_button:
                if st.session_state.users.get(username) == password:
                    st.session_state.authenticated = True
                    st.session_state.current_user = username
                    st.rerun()
                else:
                    st.error("Invalid credentials")
# Show authentication if not logged in
if not st.session_state.authenticated:
    handle_auth()
    st.stop()
    
def scrape_bigbasket(url):

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36",
        "Accept-Language": "en-US,en;q=0.9",
        "Accept-Encoding": "gzip, deflate, br",
        "Connection": "keep-alive"
    }

    response = requests.get(url, headers=headers)

    # Check if the request was successful
    if response.status_code == 200:
        soup = BeautifulSoup(response.text, "html.parser")
        product_containers = soup.find_all('div', class_='SKUDeck___StyledDiv-sc-1e5d9gk-0')

        if not product_containers:
            raise Exception("No products found - check if website is blocking requests or class names are incorrect")

        data = []
        for product in product_containers:
            name_tag = product.find('h3', class_='block m-0 line-clamp-2 font-regular text-base leading-sm text-darkOnyx-800 pt-0.5 h-full')
            weight_tag = product.find('span', string=re.compile(r'[\d.]+\s*(kg|g)', re.IGNORECASE))
            price_tag = product.find('span', class_='Label-sc-15v1nk5-0 Pricing___StyledLabel-sc-pldi2d-1 gJxZPQ AypOi')
            mrp_tag = product.find('span', class_='Label-sc-15v1nk5-0 Pricing___StyledLabel2-sc-pldi2d-2 gJxZPQ hsCgvu')

            data.append((
                name_tag.text.strip() if name_tag else None,
                weight_tag.text.strip() if weight_tag else None,
                price_tag.text.strip() if price_tag else None,
                mrp_tag.text.strip() if mrp_tag else None
            ))

        df = pd.DataFrame(data, columns=['Name', 'Quantity(kg)', 'Price', 'MRP'])
        
        # Data cleaning
        def convert_weight(value):
            if pd.isna(value):
                return None
            match = re.match(r"([\d.]+)\s*(kg|g)", value, re.IGNORECASE)
            if match:
                num = float(match.group(1))
                return num / 1000 if match.group(2).lower() == "g" else num
            return None

        df['Quantity(kg)'] = df['Quantity(kg)'].apply(convert_weight)
        df = df.dropna(subset=['Quantity(kg)', 'Price'])
        df["Price"] = df["Price"].apply(lambda x: float(x.replace("₹", "")) if isinstance(x, str) else None)
        df["MRP"] = df["MRP"].apply(lambda x: float(x.replace("₹", "")) if isinstance(x, str) else None)
        df['Price/kg'] = (df['Price'] / df['Quantity(kg)']).fillna(0).astype(int)
        df['MRP/kg'] = (df['MRP'] / df['Quantity(kg)']).fillna(0).astype(int)
        df.drop(columns=['Price', 'MRP', 'Quantity(kg)'], inplace=True)
        df.reset_index(drop=True, inplace=True)
        df = df.drop_duplicates(subset="Name", keep="first")

        if df.empty:
            raise Exception("No valid product data found")

        return df
    else:
        raise Exception(f"Failed to retrieve page. Status code: {response.status_code}")


# Main app interface
st.title("🛒 BigBasket Web Scraper")
st.markdown(f"Welcome, {st.session_state.current_user}! 👋")
# Logout button
if st.sidebar.button("Logout"):
    st.session_state.authenticated = False
    st.session_state.current_user = None
    st.rerun()
# Original scraping interface
st.markdown("Enter a **BigBasket URL** below to scrape product details.")
url = st.text_input("Enter BigBasket URL:")
    # Warning message with custom styling
st.markdown(
        """<div class="warning">
            ⚠️ <strong>Important:</strong> Only input links to categories where products are measured in grams or kilograms.
           </div>""", 
        unsafe_allow_html=True
    )
if st.button("Scrape Data"):
    if url:
        with st.spinner("Scraping data... Please wait."):
            try:
                df = scrape_bigbasket(url)
                st.success("✅ Data scraped successfully!")
                st.dataframe(df)
                st.download_button("📥 Download CSV", df.to_csv(index=False), "bigbasket_data.csv", "text/csv")
                # Tabs for Analysis
                tab1, tab2, tab3, tab4 = st.tabs([
                        "💎 Top Premium Items",
                        "💰 Best Value Picks",
                        "🎉 Maximum Discounts",
                        "⌛ Minimum Discounts"
                ])
                with tab1:
                    st.subheader("Top 10 Most Expensive Items")
                    top_10_expensive_items = df.sort_values('Price/kg', ascending=False).head(10)
                    plt.figure(figsize=(10, 5))
                    plt.bar(top_10_expensive_items['Name'], top_10_expensive_items['Price/kg'], color='royalblue', edgecolor='black')
                    plt.xticks(rotation=45, ha='right')
                    plt.xlabel('Item Name', fontsize=12, fontweight='bold')
                    plt.ylabel('Price per kg (₹)', fontsize=12, fontweight='bold')
                    plt.title('Top 10 Most Expensive Items', fontsize=14, fontweight='bold')
                    plt.grid(axis='y', linestyle='--', alpha=0.7)
                    st.pyplot(plt)
                with tab2:
                    st.subheader("Least Expensive 10 Items")
                    least_10_expensive_items = df.sort_values('Price/kg', ascending=True).head(10)
                    plt.figure(figsize=(10, 5))
                    plt.bar(least_10_expensive_items['Name'], least_10_expensive_items['Price/kg'], color='lightgreen', edgecolor='black')
                    plt.xticks(rotation=45, ha='right')
                    plt.xlabel('Item Name', fontsize=12, fontweight='bold')
                    plt.ylabel('Price per kg (₹)', fontsize=12, fontweight='bold')
                    plt.title('Least Expensive 10 Items', fontsize=14, fontweight='bold')
                    plt.grid(axis='y', linestyle='--', alpha=0.7)
                    st.pyplot(plt)
                df_non_zero_mrp = df[df['MRP/kg'] != 0]
                df_non_zero_mrp['Difference'] = df_non_zero_mrp['MRP/kg'] - df_non_zero_mrp['Price/kg']
                with tab3:
                    st.subheader("Top 5 Items with Maximum Discount Per KG")
                    top_5_max_discount = df_non_zero_mrp.sort_values('Difference', ascending=False).head(5)
                    plt.figure(figsize=(10, 6))
                    plt.bar(top_5_max_discount['Name'], top_5_max_discount['Difference'], color='lightseagreen', edgecolor='darkgreen')
                    plt.xticks(rotation=45, ha='right', fontsize=10)
                    plt.ylabel('Discount per kg (₹)', fontsize=12, fontweight='bold')
                    plt.xlabel('Item Name', fontsize=12, fontweight='bold')
                    plt.title('Top 5 Items with Maximum Discount Per KG', fontsize=14, fontweight='bold')
                    plt.grid(axis='y', linestyle='--', alpha=0.6)
                    plt.tight_layout()
                    st.pyplot(plt)
                with tab4:
                    st.subheader("Top 5 Items with Least Discount Per KG")
                    top_5_least_discount = df_non_zero_mrp.sort_values('Difference', ascending=True).head(5)
                    plt.figure(figsize=(10, 6))
                    plt.bar(top_5_least_discount['Name'], top_5_least_discount['Difference'], color='orange', edgecolor='darkgreen')
                    plt.xticks(rotation=45, ha='right', fontsize=10)
                    plt.ylabel('Discount per kg (₹)', fontsize=12, fontweight='bold')
                    plt.xlabel('Item Name', fontsize=12, fontweight='bold')
                    plt.title('Top 5 Items with Least Discount Per KG', fontsize=14, fontweight='bold')
                    plt.grid(axis='y', linestyle='--', alpha=0.6)
                    plt.tight_layout()
                    st.pyplot(plt)
            except Exception as e:
                st.error(f"❌ Error: {str(e)}")
    else:
        st.warning("⚠️ Please enter a valid URL.")