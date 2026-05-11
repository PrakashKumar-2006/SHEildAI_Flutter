import pandas as pd
file_path = r'c:\Development\Projects\sheild_ai\ML model\SHEild_AI_Improved_Dataset.xlsx'
xl = pd.ExcelFile(file_path)
print(xl.sheet_names)
