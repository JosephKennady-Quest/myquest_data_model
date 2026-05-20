import pandas as pd
import numpy as np

# Create one row per calendar date
df_date = pd.DataFrame({
    "date": pd.date_range(start="2020-01-01", end="2030-12-31", freq="D")
})

# Create date dimension fields
df_date["date_id"] = df_date["date"].dt.strftime("%Y%m%d").astype(int)
df_date["day"] = df_date["date"].dt.day
df_date["week"] = df_date["date"].dt.isocalendar().week.astype(int)   # Monday-based week
df_date["month"] = df_date["date"].dt.month
df_date["quarter"] = df_date["date"].dt.quarter
df_date["year"] = df_date["date"].dt.year

# Financial year: April to March
df_date["financial_year"] = np.where(
    df_date["month"] >= 4,
    df_date["year"].astype(str) + "-" + (df_date["year"] + 1).astype(str),
    (df_date["year"] - 1).astype(str) + "-" + df_date["year"].astype(str)
)

# Weekend flag: Saturday or Sunday
df_date["is_weekend"] = df_date["date"].dt.dayofweek.isin([5, 6]).astype(int)

# Reorder columns
df_date = df_date[
    [
        "date_id",
        "date",
        "day",
        "week",
        "month",
        "quarter",
        "year",
        "financial_year",
        "is_weekend"
    ]
]

print(df_date.head())
print(df_date.tail())