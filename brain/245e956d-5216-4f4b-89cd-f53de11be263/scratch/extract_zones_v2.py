import pandas as pd
import json

file_path = r'c:\Development\Projects\sheild_ai\ML model\SHEild_AI_Improved_Dataset.xlsx'
df = pd.read_excel(file_path, sheet_name='4_Station_Zone_Profiles', header=1)

zones = []
for _, row in df.iterrows():
    name = str(row.get('Police_Station', 'Unknown'))
    lat = row.get('Lat_Center')
    lon = row.get('Lon_Center')
    score = row.get('Overall_Risk_Score_Display')
    
    if pd.isna(lat) or pd.isna(lon):
        continue
        
    zones.append({
        "name": name,
        "lat": float(lat),
        "lon": float(lon),
        "base_score": float(score) if not pd.isna(score) else 50.0
    })

output_path = r'c:\Development\Projects\sheild_ai\brain\245e956d-5216-4f4b-89cd-f53de11be263\scratch\extracted_zones.json'
# We also need the hour multipliers
xl = pd.ExcelFile(file_path)
df_time = pd.read_excel(file_path, sheet_name='5_Time_Environment_Factors', header=1)
multipliers = {}
for _, row in df_time.iterrows():
    try:
        hr_str = str(row.get('Hour_Range', '')).strip()
        if '-' in hr_str:
            start_h = int(hr_str.split('-')[0].split(':')[0])
            multipliers[str(start_h)] = float(row.get('Additive_Factor', 0))
    except:
        continue

final_data = {
    "zones": zones,
    "hour_multipliers": multipliers
}

with open(output_path, 'w') as f:
    json.dump(final_data, f, indent=2)

print(f"Extracted {len(zones)} zones and {len(multipliers)} hour multipliers.")
