import pandas as pd
import json

file_path = r'c:\Development\Projects\sheild_ai\ML model\SHEild_AI_Improved_Dataset.xlsx'
df = pd.read_excel(file_path, sheet_name='2_Station_Zone_Profile')

zones = []
for _, row in df.iterrows():
    zones.append({
        "name": row['Police_Station'],
        "lat": float(row['Lat_Center']),
        "lon": float(row['Lon_Center']),
        "base_score": float(row['Overall_Risk_Score_Display'])
    })

output_path = r'c:\Development\Projects\sheild_ai\brain\245e956d-5216-4f4b-89cd-f53de11be263\scratch\extracted_zones.json'
with open(output_path, 'w') as f:
    json.dump(zones, f, indent=2)

print(f"Extracted {len(zones)} zones.")
