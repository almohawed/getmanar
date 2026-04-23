import pandas as pd
import os

try:
    df = pd.read_excel('excl/1.xlsx')
    print("Columns:", df.columns.tolist())
    print("First 5 rows:")
    print(df.head().to_string())
except Exception as e:
    print(f"Error: {e}")
