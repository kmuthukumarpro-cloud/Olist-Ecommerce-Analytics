
import pandas as pd
import os

print("Current working directory:", os.getcwd())

# --------------------------------------------------
# 1. Load datasets
# Run this script from the project root folder.
# --------------------------------------------------

orders = pd.read_csv("data_raw/orders.csv")
customers = pd.read_csv("data_raw/customers.csv")
order_items = pd.read_csv("data_raw/order_items.csv")
products = pd.read_csv("data_raw/products.csv")
payments = pd.read_csv("data_raw/payments.csv")
reviews = pd.read_csv("data_raw/reviews.csv")
sellers = pd.read_csv("data_raw/sellers.csv")
category_translation = pd.read_csv(
    "data_raw/category_translation.csv"
)

# Geolocation is intentionally not loaded because it is large
# and not required for the current analysis.

# --------------------------------------------------
# 2. Convert date columns
# --------------------------------------------------

date_columns = [
    "order_purchase_timestamp",
    "order_approved_at",
    "order_delivered_carrier_date",
    "order_delivered_customer_date",
    "order_estimated_delivery_date",
]

for column in date_columns:
    orders[column] = pd.to_datetime(
        orders[column],
        errors="coerce"
    )

order_items["shipping_limit_date"] = pd.to_datetime(
    order_items["shipping_limit_date"],
    errors="coerce"
)

# --------------------------------------------------
# 3. Essential data-quality checks
# --------------------------------------------------

datasets = {
    "orders": orders,
    "customers": customers,
    "order_items": order_items,
    "products": products,
    "payments": payments,
    "reviews": reviews,
    "sellers": sellers,
    "category_translation": category_translation,
}

print("\nDATASET SHAPES")

for name, df in datasets.items():
    print(f"{name}: {df.shape}")

print("\nMISSING VALUES")

for name, df in datasets.items():
    missing = df.isna().sum()
    missing = missing[missing > 0]

    if not missing.empty:
        print(f"\n{name}:")
        print(missing)

print("\nKEY DUPLICATE CHECKS")

print(
    "Duplicate order IDs:",
    orders["order_id"].duplicated().sum()
)

print(
    "Duplicate customer IDs:",
    customers["customer_id"].duplicated().sum()
)

print(
    "Duplicate order/item pairs:",
    order_items.duplicated(
        subset=["order_id", "order_item_id"]
    ).sum()
)

print(
    "Duplicate product IDs:",
    products["product_id"].duplicated().sum()
)

print("\nORDER STATUS COUNTS")
print(orders["order_status"].value_counts())

print("\nRELATIONSHIP CHECKS (expected: 0 unmatched keys)")

print(
    "Order items without a matching order:",
    (~order_items["order_id"].isin(orders["order_id"])).sum()
)

print(
    "Orders without a matching customer:",
    (~orders["customer_id"].isin(customers["customer_id"])).sum()
)

print(
    "Order items without a matching product:",
    (~order_items["product_id"].isin(products["product_id"])).sum()
)

# --------------------------------------------------
# 4. Prepare item-level sales dataset
# One row represents one item within an order.
# Price totals include all order statuses.
# They are not confirmed revenue or payment totals.
# --------------------------------------------------

sales_data = order_items.merge(
    orders[
        [
            "order_id",
            "customer_id",
            "order_status",
            "order_purchase_timestamp",
        ]
    ],
    on="order_id",
    how="left",
)

sales_data = sales_data.merge(
    customers[
        ["customer_id", "customer_unique_id"]
    ],
    on="customer_id",
    how="left",
)

sales_data = sales_data.merge(
    products[
        ["product_id", "product_category_name"]
    ],
    on="product_id",
    how="left",
)

sales_data = sales_data.merge(
    category_translation,
    on="product_category_name",
    how="left",
)

sales_data["category_for_analysis"] = (
    sales_data["product_category_name_english"]
    .fillna(sales_data["product_category_name"])
    .fillna("Unknown")
)

sales_data["purchase_month"] = (
    sales_data["order_purchase_timestamp"].dt.to_period("M")
)

print("\nPREPARED SALES DATA")
print("Shape:", sales_data.shape)
print("Distinct orders:", sales_data["order_id"].nunique())

print(
    "Missing analysis category labels:",
    sales_data["category_for_analysis"].isna().sum()
)

# --------------------------------------------------
# 5. Monthly performance summary
# --------------------------------------------------

monthly_summary = (
    sales_data.groupby("purchase_month")
    .agg(
        monthly_sales=("price", "sum"),
        total_orders=("order_id", "nunique"),
    )
    .sort_index()
)

monthly_summary["avg_order_value"] = (
    monthly_summary["monthly_sales"]
    / monthly_summary["total_orders"]
)

print("\nMONTHLY SUMMARY")
print(monthly_summary.round(2))

# --------------------------------------------------
# 6. Product category performance
# total_items counts item rows, not distinct products.
# --------------------------------------------------

category_summary = (
    sales_data.groupby("category_for_analysis")
    .agg(
        total_sales=("price", "sum"),
        total_orders=("order_id", "nunique"),
        total_items=("order_id", "size"),
    )
    .sort_values("total_sales", ascending=False)
)

print("\nTOP 10 CATEGORIES")
print(category_summary.head(10))

# --------------------------------------------------
# 7. State performance
# --------------------------------------------------

regional_data = sales_data.merge(
    customers[
        ["customer_id", "customer_state"]
    ],
    on="customer_id",
    how="left",
)

state_summary = (
    regional_data.groupby("customer_state")
    .agg(
        total_sales=("price", "sum"),
        total_orders=("order_id", "nunique"),
    )
    .sort_values("total_sales", ascending=False)
)

print("\nTOP 10 STATES")
print(state_summary.head(10))

# --------------------------------------------------
# 8. Repeat-customer analysis
# customer_unique_id identifies customers across orders.
# --------------------------------------------------

customer_data = sales_data.copy()

repeat_customers = (
    customer_data.groupby("customer_unique_id")
    .agg(
        total_sales=("price", "sum"),
        total_orders=("order_id", "nunique"),
    )
    .sort_values(
        ["total_orders", "total_sales"],
        ascending=[False, False],
    )
)

print("\nTOP 10 REPEAT CUSTOMERS BY ORDER COUNT")
print(repeat_customers.head(10))

# --------------------------------------------------
# 9. Prepare Payments Data for Power BI
# --------------------------------------------------

payments_data = payments.merge(
    orders[
        [
            "order_id",
            "order_status",
            "order_purchase_timestamp",
        ]
    ],
    on="order_id",
    how="left",
)

payments_data["purchase_month"] = (
    payments_data["order_purchase_timestamp"]
    .dt.to_period("M")
    .astype("string")
)

print("\nPAYMENTS DATA SHAPE:", payments_data.shape)

print("\nPAYMENT TYPES:")
print(
    payments_data["payment_type"].value_counts(
        dropna=False
    )
)

print("\nMISSING ORDER DETAILS:")
print(payments_data["order_status"].isna().sum())

payments_data.to_csv(
    "prepared_payments_data.csv",
    index=False,
)

# --------------------------------------------------
# 10. Prepare Reviews and Delivery Data for Power BI
# One row represents one review record.
# --------------------------------------------------

reviews_delivery_data = reviews.merge(
    orders[
        [
            "order_id",
            "order_status",
            "order_purchase_timestamp",
            "order_delivered_customer_date",
            "order_estimated_delivery_date",
        ]
    ],
    on="order_id",
    how="left",
)

# Calculate delivery delay in days

reviews_delivery_data["delivery_delay_days"] = (
    reviews_delivery_data["order_delivered_customer_date"]
    - reviews_delivery_data["order_estimated_delivery_date"]
).dt.days

# Classify delivery performance

reviews_delivery_data["delivery_performance"] = "UNKNOWN"

valid_delivery_dates = (
    reviews_delivery_data[
        "order_delivered_customer_date"
    ].notna()
    &
    reviews_delivery_data[
        "order_estimated_delivery_date"
    ].notna()
)

reviews_delivery_data.loc[
    valid_delivery_dates
    &
    (
        reviews_delivery_data["order_delivered_customer_date"]
        > reviews_delivery_data["order_estimated_delivery_date"]
    ),
    "delivery_performance",
] = "LATE"

reviews_delivery_data.loc[
    valid_delivery_dates
    &
    (
        reviews_delivery_data["order_delivered_customer_date"]
        <= reviews_delivery_data["order_estimated_delivery_date"]
    ),
    "delivery_performance",
] = "ON TIME"

# Create month for trend analysis

reviews_delivery_data["purchase_month"] = (
    reviews_delivery_data["order_purchase_timestamp"]
    .dt.to_period("M")
    .astype("string")
)

print("\nREVIEWS & DELIVERY DATA")
print("Shape:", reviews_delivery_data.shape)

print("\nDELIVERY PERFORMANCE:")
print(
    reviews_delivery_data["delivery_performance"].value_counts()
)

print("\nMISSING REVIEW SCORES:")
print(reviews_delivery_data["review_score"].isna().sum())

reviews_delivery_data.to_csv(
    "prepared_reviews_delivery_data.csv",
    index=False,
)

# --------------------------------------------------
# 11. Export datasets for Power BI
# --------------------------------------------------

monthly_summary.to_csv(
    "monthly_sales_summary.csv",
    index=True,
)

category_summary.to_csv(
    "category_sales_summary.csv",
    index=True,
)

state_summary.to_csv(
    "state_sales_summary.csv",
    index=True,
)

repeat_customers.to_csv(
    "repeat_customer_summary.csv",
    index=True,
)

sales_data.to_csv(
    "prepared_sales_data.csv",
    index=False,
)

print("\nExports completed.")

