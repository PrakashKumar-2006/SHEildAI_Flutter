import pandas as pd
import json
import os

EXCEL_PATH = "ML model/SHEild_AI_Improved_Dataset.xlsx"
OUTPUT_PATH = "assets/risk_data.json"

def sync():
    print(f"Loading {EXCEL_PATH}...")
    
    # Load Zone Profiles
    df_zone = pd.read_excel(EXCEL_PATH, sheet_name="5_All_Zone_Profiles", header=1)
    
    # Load Time Factors
    df_time = pd.read_excel(EXCEL_PATH, sheet_name="6_Time_Environment", header=1)
    
    zones = []
    for _, row in df_zone.iterrows():
        # Use Overall_Risk_Score_Display as the base score for the app
        # This reflects the user's calibrated risk values.
        base_score = float(row.get('Overall_Risk_Score_Display', 25.0))
        
        zones.append({
            "name": str(row['Police_Station']),
            "lat": float(row['Lat_Center']),
            "lon": float(row['Lon_Center']),
            "base_score": base_score
        })
    
    # Map time multipliers
    # Slots: 00-06, 06-10, 10-12, 12-16, 16-18, 18-21, 21-24
    multipliers = {}
    
    # Extract from sheet
    time_map = {}
    for _, row in df_time.iterrows():
        slot = str(row['Hour_Range'])
        score = float(row['Time_Additive_Score'])
        time_map[slot] = score
        
    for h in range(24):
        if 0 <= h < 6: m = time_map.get("00-06", 16.0)
        elif 6 <= h < 10: m = time_map.get("06-10", 0.0)
        elif 10 <= h < 12: m = time_map.get("10-12", -6.0)
        elif 12 <= h < 16: m = time_map.get("12-16", -2.0)
        elif 16 <= h < 18: m = time_map.get("16-18", 2.0)
        elif 18 <= h < 21: m = time_map.get("18-21", 10.0)
        else: m = time_map.get("21-24", 14.0)
        multipliers[str(h)] = m
        
    data = {
        "zones": zones,
        "hour_multipliers": multipliers
    }
    
    with open(OUTPUT_PATH, "w") as f:
        json.dump(data, f, indent=2)
        
    print(f"Syncing {len(zones)} zones and 24 hour multipliers...")
    print("Done!")

if __name__ == "__main__":
    sync()
