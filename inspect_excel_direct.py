import openpyxl
import sys

try:
    wb = openpyxl.load_workbook('errordata.xlsx', read_only=True, data_only=True)
    ws = wb.active
    print("Successfully opened workbook.")
    for row in ws.iter_rows(min_row=1, max_row=5, values_only=True):
        print(row)
except Exception as e:
    print(f"Error: {e}")
