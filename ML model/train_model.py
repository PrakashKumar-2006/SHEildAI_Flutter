"""
SHEild AI — ML Training Pipeline v3.0
=======================================
Trains Random Forest + Gradient Boosting ensemble.
Dataset : SHEild_AI_Improved_Dataset.xlsx
Run     : python train_model.py
Output  : models/sheild_risk_model.pkl
"""

import pandas as pd
import numpy as np
import os, json, warnings
warnings.filterwarnings("ignore")

from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier, VotingClassifier
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.model_selection import train_test_split, cross_val_score, StratifiedKFold
from sklearn.metrics import accuracy_score, f1_score, classification_report, confusion_matrix
import joblib

DATASET   = "SHEild_AI_Improved_Dataset.xlsx"
MODEL_DIR = "models"
os.makedirs(MODEL_DIR, exist_ok=True)

print("=" * 60)
print("  SHEild AI — ML Training Pipeline v3.0")
print("=" * 60)

# ── STEP 1: LOAD ──────────────────────────────────────────────────────────────
print("\n[1/7] Loading dataset...")
df_inc  = pd.read_excel(DATASET, sheet_name="1_Crime_Incidents",          header=1)
df_zone = pd.read_excel(DATASET, sheet_name="2_Station_Zone_Profile",     header=1)
df_time = pd.read_excel(DATASET, sheet_name="3_Time_Environment_Factors", header=1)
print(f"      Incidents : {len(df_inc):,}")
print(f"      Zones     : {len(df_zone)}")
print(f"      Time slots: {len(df_time)}")

# ── STEP 2: FEATURE ENGINEERING ───────────────────────────────────────────────
print("\n[2/7] Engineering features...")
df = df_inc.copy()

# Direct numeric
df["hour_24"]        = df["Hour_24"].astype(float)
df["crime_severity"] = df["Crime_Severity_Score"].astype(float)
df["police_dist_km"] = df["Nearest_PS_Dist_km"].astype(float)
df["is_weekend"]     = df["Is_Weekend"].astype(int)

# CCTV and lighting
df["cctv_numeric"]     = df["CCTV_Available"].str.strip().map(
                             {"Yes":1.0,"Partial":0.5,"No":0.0}).fillna(0.0)
df["lighting_numeric"] = df["Street_Lighting"].str.strip().map(
                             {"Good":0,"Moderate":1,"Poor":2,"None":3,"N/A":1}).fillna(1)

# Time flags
df["is_night"]   = ((df["hour_24"] >= 21) | (df["hour_24"] < 6)).astype(int)
df["is_evening"] = ((df["hour_24"] >= 18) & (df["hour_24"] < 21)).astype(int)
df["is_daytime"] = ((df["hour_24"] >= 10) & (df["hour_24"] < 16)).astype(int)

# Cyclic encoding
df["hour_sin"]  = np.sin(2 * np.pi * df["hour_24"] / 24)
df["hour_cos"]  = np.cos(2 * np.pi * df["hour_24"] / 24)
df["month_sin"] = np.sin(2 * np.pi * df["Month_Num"] / 12)
df["month_cos"] = np.cos(2 * np.pi * df["Month_Num"] / 12)

# Time slot features
def get_time_feats(h):
    for _, row in df_time.iterrows():
        try:
            s, e = [int(x) for x in str(row["Hour_Range"]).split("-")]
            if s <= h < e:
                return float(row["Time_Additive_Score"]), float(row["Incident_Share_Pct"])
        except:
            pass
    return 0.0, 10.0

df["time_additive"], df["incident_share"] = zip(*df["hour_24"].apply(get_time_feats))

# Zone features
df_zone2 = df_zone[["Police_Station","Zone_Base_Score","Overall_Risk_Score_Display",
                     "CCTV_Coverage_Pct","Nearest_PS_Dist_km",
                     "Drug_Alcohol_Nearby","Slum_Area",
                     "Isolated_Roads","Population_Density"]].copy()

df_zone2["drug_nearby"] = (df_zone2["Drug_Alcohol_Nearby"].str.lower() == "yes").astype(int)
df_zone2["slum_area"]   = df_zone2["Slum_Area"].str.lower().map(
                              {"yes":1,"partial":0.5,"no":0}).fillna(0)
df_zone2["isolation"]   = df_zone2["Isolated_Roads"].str.lower().map(
                              {"very high":4,"high":3,"medium":2,"low":1,"no":0}).fillna(1)
df_zone2["pop_density"] = df_zone2["Population_Density"].str.lower().str.extract(
                              r"(very high|high|medium|low|very low)")[0].map(
                              {"very high":5,"high":4,"medium":3,"low":2,"very low":1}).fillna(2)
df_zone2["zone_base"]    = pd.to_numeric(df_zone2["Zone_Base_Score"],            errors="coerce").fillna(25)
df_zone2["zone_risk"]    = pd.to_numeric(df_zone2["Overall_Risk_Score_Display"], errors="coerce").fillna(50)
df_zone2["zone_cctv"]    = pd.to_numeric(df_zone2["CCTV_Coverage_Pct"],          errors="coerce").fillna(20)
df_zone2["zone_ps_dist"] = pd.to_numeric(df_zone2["Nearest_PS_Dist_km"],         errors="coerce").fillna(2)

zs = df_zone2[["Police_Station","zone_base","zone_risk","zone_cctv","zone_ps_dist",
               "drug_nearby","slum_area","isolation","pop_density"]].drop_duplicates("Police_Station")

df = df.merge(zs, on="Police_Station", how="left")
zcols = ["zone_base","zone_risk","zone_cctv","zone_ps_dist",
         "drug_nearby","slum_area","isolation","pop_density"]
df[zcols] = df[zcols].fillna(df[zcols].median())

# Label encoders
le_crime   = LabelEncoder()
le_zone    = LabelEncoder()
le_area    = LabelEncoder()
le_victim  = LabelEncoder()
le_rel     = LabelEncoder()
le_loc     = LabelEncoder()
le_weather = LabelEncoder()

df["crime_enc"]   = le_crime.fit_transform(df["Crime_Type"].astype(str))
df["zone_enc"]    = le_zone.fit_transform(df["Zone"].astype(str))
df["area_enc"]    = le_area.fit_transform(df["Area_Type"].astype(str))
df["victim_enc"]  = le_victim.fit_transform(df["Victim_Age_Group"].astype(str))
df["rel_enc"]     = le_rel.fit_transform(df["Relation_to_Accused"].astype(str))
df["loc_enc"]     = le_loc.fit_transform(df["Location_Context"].astype(str))
df["weather_enc"] = le_weather.fit_transform(df["Weather"].astype(str))

# Interaction features
df["night_isolation"]    = df["is_night"]       * df["isolation"]
df["night_no_cctv"]      = df["is_night"]       * (1 - df["cctv_numeric"])
df["evening_isolation"]  = df["is_evening"]     * df["isolation"]
df["severity_x_night"]   = df["crime_severity"] * df["is_night"]
df["zone_risk_x_time"]   = df["zone_base"]      * df["time_additive"]
df["dist_x_isolation"]   = df["zone_ps_dist"]   * df["isolation"]
df["weekend_x_night"]    = df["is_weekend"]     * df["is_night"]
df["severity_x_evening"] = df["crime_severity"] * df["is_evening"]

FEATURES = [
    "hour_24","crime_severity","police_dist_km","cctv_numeric","lighting_numeric",
    "is_night","is_evening","is_daytime","is_weekend",
    "hour_sin","hour_cos","month_sin","month_cos",
    "time_additive","incident_share",
    "zone_base","zone_risk","zone_cctv","zone_ps_dist",
    "drug_nearby","slum_area","isolation","pop_density",
    "crime_enc","zone_enc","area_enc","victim_enc","rel_enc","loc_enc","weather_enc",
    "night_isolation","night_no_cctv","evening_isolation",
    "severity_x_night","zone_risk_x_time","dist_x_isolation",
    "weekend_x_night","severity_x_evening",
]

X = df[FEATURES].fillna(0)
y = df["Risk_Label"]
print(f"      Feature matrix : {X.shape}")
print(f"      Label dist     : {dict(y.value_counts().sort_index())}")

# ── STEP 3: SPLIT ─────────────────────────────────────────────────────────────
print("\n[3/7] Train/test split (80/20 stratified)...")
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.20, random_state=42, stratify=y
)
scaler    = StandardScaler()
X_train_s = scaler.fit_transform(X_train)
X_test_s  = scaler.transform(X_test)
print(f"      Train: {len(X_train):,}  |  Test: {len(X_test):,}")

# ── STEP 4: TRAIN ─────────────────────────────────────────────────────────────
print("\n[4/7] Training models...")

rf = RandomForestClassifier(
    n_estimators=400, max_depth=14, min_samples_split=2,
    min_samples_leaf=1, max_features="sqrt",
    class_weight="balanced", random_state=42, n_jobs=-1,
)
rf.fit(X_train_s, y_train)
rf_acc = accuracy_score(y_test, rf.predict(X_test_s))
rf_f1  = f1_score(y_test, rf.predict(X_test_s), average="weighted")
print(f"      Random Forest      -> Acc: {rf_acc:.4f}  F1: {rf_f1:.4f}")

gb = GradientBoostingClassifier(
    n_estimators=250, learning_rate=0.08, max_depth=5,
    subsample=0.85, random_state=42,
)
gb.fit(X_train_s, y_train)
gb_acc = accuracy_score(y_test, gb.predict(X_test_s))
gb_f1  = f1_score(y_test, gb.predict(X_test_s), average="weighted")
print(f"      Gradient Boosting  -> Acc: {gb_acc:.4f}  F1: {gb_f1:.4f}")

ensemble = VotingClassifier(
    estimators=[("rf", rf), ("gb", gb)],
    voting="soft", weights=[2, 1],
)
ensemble.fit(X_train_s, y_train)
ens_acc = accuracy_score(y_test, ensemble.predict(X_test_s))
ens_f1  = f1_score(y_test, ensemble.predict(X_test_s), average="weighted")
print(f"      Ensemble (RF + GB) -> Acc: {ens_acc:.4f}  F1: {ens_f1:.4f}")

# ── STEP 5: CROSS VALIDATION ──────────────────────────────────────────────────
print("\n[5/7] Cross-validation (5-fold)...")
cv        = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
X_all_s   = scaler.transform(X)
cv_scores = cross_val_score(ensemble, X_all_s, y, cv=cv, scoring="f1_weighted")
print(f"      Fold scores : {[round(s, 3) for s in cv_scores]}")
print(f"      Mean F1     : {cv_scores.mean():.3f} +/- {cv_scores.std():.4f}")

# ── STEP 6: EVALUATE ──────────────────────────────────────────────────────────
print("\n[6/7] Evaluation report...")
y_pred = ensemble.predict(X_test_s)
print(classification_report(y_test, y_pred,
      target_names=["Medium(1)","High(2)","Critical(3)"]))
print("Confusion Matrix:")
print(confusion_matrix(y_test, y_pred))

feat_imp = dict(zip(FEATURES, rf.feature_importances_))
print("\nTop 10 Features:")
for f, v in sorted(feat_imp.items(), key=lambda x: x[1], reverse=True)[:10]:
    print(f"  {f:<28} {v:.4f}  {'#' * int(v*80)}")

# ── STEP 7: SAVE ──────────────────────────────────────────────────────────────
print("\n[7/7] Saving model bundle...")

bundle = {
    "model":   ensemble,
    "scaler":  scaler,
    "features": FEATURES,
    "encoders": {
        "crime_type": le_crime, "zone":       le_zone,
        "area_type":  le_area,  "victim_age": le_victim,
        "relation":   le_rel,   "location":   le_loc,
        "weather":    le_weather,
    },
    "zone_lookup": zs.set_index("Police_Station").to_dict(orient="index"),
    "metrics": {
        "accuracy":         round(ens_acc, 4),
        "f1_weighted":      round(ens_f1, 4),
        "cv_f1_mean":       round(float(cv_scores.mean()), 4),
        "cv_f1_std":        round(float(cv_scores.std()), 4),
        "training_records": len(X_train),
        "test_records":     len(X_test),
        "total_features":   len(FEATURES),
    },
    "label_map":        {1:"MEDIUM", 2:"HIGH", 3:"CRITICAL"},
    "label_thresholds": {"MEDIUM":"0-35","HIGH":"36-62","CRITICAL":"63-100"},
    "feature_importance": feat_imp,
}

MODEL_PATH = os.path.join(MODEL_DIR, "sheild_risk_model.pkl")
joblib.dump(bundle, MODEL_PATH)

with open(os.path.join(MODEL_DIR, "model_metrics.json"), "w") as f:
    json.dump(bundle["metrics"], f, indent=2)

print(f"      Saved -> {MODEL_PATH}")
print("\n" + "=" * 60)
print(f"  Done! Accuracy: {ens_acc*100:.2f}%  |  CV F1: {cv_scores.mean():.3f}")
print(f"  Next: uvicorn main:app --reload --host 0.0.0.0 --port 8000")
print("=" * 60)
