# Phase 1.2B Sprint 7 Secrets Rotation & Environment Security Plan

## 1. Executive Summary
This document provides a comprehensive secrets audit, Git tracking analysis, and a zero-downtime rotation strategy for the SHEild AI platform. 

Currently, the backend has been secured against API exposures, rate-limiting abuse, and hardcoded fallbacks. However, the platform remains exposed to major credential leaks because critical secrets—including MongoDB Atlas cluster connection URIs (with cleartext database usernames and passwords), Google Maps API keys, and JWT signatures—are actively tracked in source control and committed to the Git repository.

This plan catalogues all discovered credentials, defines security reviews for Google Maps, Firebase, and MongoDB Atlas, and establishes a sequential, zero-downtime rotation roadmap to move SHEild AI from git-exposed credential storage to a zero-trust production environment.

---

## 2. Secrets Inventory
The following is an inventory of all secrets, API keys, and private configuration items used across the SHEild AI backend and client systems:

| Secret Name | Scope | Purpose | Location | Hardcoded? | Risk Level |
| :--- | :--- | :--- | :--- | :---: | :---: |
| `JWT_SECRET` | Backend Server | Signs and verifies SHEild AI user session JWTs | Loaded from root `.env` (`JWT_SECRET`) | **NO** (Strictly env-loaded) | **HIGH** (Committed to Git) |
| `MONGO_URI` | Backend Server | Connects backend to MongoDB Atlas database | Loaded from root `.env` (`MONGO_URI`) | **NO** (Strictly env-loaded) | **CRITICAL** (Cleartext credentials in Git) |
| `MONGO_DB_CONNECTION_STRING` | Backend Server | Alternative connection identifier | Loaded from root `.env` | **NO** | **CRITICAL** (Committed to Git) |
| `GOOGLE_MAPS_API_KEY` | Mobile (Android) | Renders Google Maps SDK components | Defined in `.env` and `android/gradle.properties` | **NO** (Property-loaded) | **HIGH** (Billing/quota theft risk) |
| `current_key` (Firebase Key) | Mobile (Android) | Connects client SDK to Firebase Auth | Hardcoded in [google-services.json:L31](file:///c:/Development/Projects/sheild_ai/android/app/google-services.json#L31) | **YES** (Compiled config) | **MEDIUM** (Metadata exposure) |
| `GOOGLE_APPLICATION_CREDENTIALS` | Backend Server | Service account path for Firebase verification | Expected env variable at startup | **NO** (Loaded at boot) | **LOW** (Safe configuration) |

---

## 3. Source Control Exposure Audit
The repository's version control structure was audited to check if private environment files or credentials are tracked:

### A. Root `.gitignore` Vulnerability:
* **Evidence:** In the root [.gitignore:L47-L51](file:///c:/Development/Projects/sheild_ai/.gitignore#L47-L51) file, the environment configurations are commented out:
  ```text
  # Environment variables - contains sensitive credentials
  # .env
  # .env*
  # .env.example
  ```
* **Impact:** Because these lines are disabled, the root `.env` file (containing database credentials, maps keys, and JWT secrets) is tracked by Git. Any developer clone or repository leak fully exposes the live database and signature system.

### B. Client-side Secrets Exposure:
* **Android Google Services:** In [.gitignore:L58](file:///c:/Development/Projects/sheild_ai/.gitignore#L58), the GMS config is commented out:
  ```text
  #/android/app/google-services.json
  ```
  Consequently, [google-services.json](file:///c:/Development/Projects/sheild_ai/android/app/google-services.json) containing Google OAuth secrets and Firebase API keys is committed.
* **Gradle Properties:** [gradle.properties](file:///c:/Development/Projects/sheild_ai/android/gradle.properties) containing the Google Maps API Key (`MAPS_API_KEY`) in cleartext is tracked in source control.

---

## 4. Deployment Configuration Audit
We reviewed how environment variables are loaded and validated on start:

* **Startup Configuration Validation:** In [index.js](file:///c:/Development/Projects/sheild_ai/backend/src/index.js#L21-L71), the backend implements a fail-fast validator ensuring the server refuses to run unless `MONGO_URI`, `JWT_SECRET` (minimum 32 characters), and Firebase credentials are present.
* **Production Deployment Risk:** Although the backend checks for these variables, if deployed on Render or other container platforms using standard Git deployments, the server might load the committed `.env` file automatically, bypassing the environment settings of the container provider. This makes rotation impossible without modifying source files.

---

## 5. Google Maps Security Review
* **API Key:** `AIzaSyAvg-RMSYcYOzoecK98WAGWjzF_g_amVeE`
* **Storage Location:** Hardcoded in `android/gradle.properties` and `.env`.
* **Security Assessment:** **UNRESTRICTED (High Risk)**.
* **Evidence & Abuse Risks:** Because this key is tracked in cleartext in the Git repository, anyone with read access can extract it. If the key lacks API restrictions or application restrictions in the GCP Console, it can be hijacked to query other paid APIs (e.g. Geocoding, Places API), resulting in massive billing charges.
* **Mitigation Requirements:**
  1. **API Restrictions:** Restrict the key to only authorize queries for the **Maps SDK for Android**.
  2. **Application Restrictions:** Restrict the key to allow calls only from package name `com.shieldai.app` matching the SHA-1 signing certificate fingerprint: `72:B9:36:48:45:38:CA:80:49:31:AD:8B:42:09:99:6C:FF:79:DE:66`.

---

## 6. Firebase Security Review
* **Strategy:** Backend uses `firebase-admin` initialized with `{ projectId: 'sheild-flutter' }` and expects Google credentials to be loaded at runtime.
* **Security Assessment:** **PARTIALLY SECURED**.
* **Analysis:** 
  * The backend config checks prevent the application from starting without a valid credentials environment.
  * However, the client-side Firebase API key (`AIzaSyBS8OqXkdTGlEwtpn58_6OZJTHZCl2jiZw`) is hardcoded in the committed `google-services.json`. 
  * While client keys are inherently public, they must be locked down in the Firebase Console to prevent unauthorized calls to services like Firestore or Firebase Functions.

---

## 7. MongoDB Security Review
* **Database URI:** `mongodb+srv://prakashkumarbiswal503_db_user:Prakash083@cluster0.lrjfnxd.mongodb.net/?appName=Cluster0`
* **Security Assessment:** **INSECURE (Critical Risk)**.
* **Analysis:**
  * Cleartext database credentials (`prakashkumarbiswal503_db_user` and password `Prakash083`) are checked into the Git repository.
  * This grant provides full read/write access to the database collections, allowing unauthorized actors to wipe database tables, alter profiles, or delete SOS incident records.

---

## 8. Rotation Impact Analysis
Rotating keys immediately can cause production downtime if clients are not migrated gracefully:

* **JWT Secret Rotation Impact:** Invalidation of all existing active user sessions, forcing all mobile app users to re-login immediately.
* **MongoDB Credentials Rotation Impact:** If the connection is updated abruptly, backend instances will fail to connect, crashing the application under the fail-fast startup checks.
* **Google Maps API Key Rotation Impact:** Invalidation of maps rendering for older client installations if updated keys are not bundled in Play Store releases.

---

## 9. Recommended Zero-Downtime Rotation Plan
We propose the following zero-downtime credentials rotation roadmap:

```mermaid
graph TD
    A["Stage 1: Mongo Credentials"] -->|Create secondary DB user in Atlas| B["Stage 2: JWT Secrets"]
    B -->|Enable dual-secret validation| C["Stage 3: Maps API Key"]
    C -->|Generate restricted key & deploy Play Store update| D["Stage 4: Git Cleanups"]
    D -->|Remove .env and google-services from Git cache| E["Stage 5: Deprecate Old Keys"]
```

### Phase 1: MongoDB Credentials Rotation (Zero-Downtime)
1. **Create Secondary User:** Log in to MongoDB Atlas and create a new database user (e.g. `sheildai_prod_user_v2`) with a cryptographically strong password.
2. **Update Environment Variable:** Set the new URI string on Render/production server environment settings (DO NOT commit this to the `.env` file).
3. **Trigger Rolling Deploy:** Restart the server nodes. Mongoose will connect using the new credentials.
4. **Delete Old User:** Once telemetry confirms all active nodes connect via `sheildai_prod_user_v2`, delete the old user account (`prakashkumarbiswal503_db_user`) from the Atlas database.

### Phase 2: JWT Secret Rotation (Zero-Downtime)
1. **Enable Dual-Verification:** Modify `auth.js` middleware to accept an array of secrets:
   ```javascript
   const secrets = [process.env.JWT_SECRET, process.env.OLD_JWT_SECRET];
   // Iterate and verify
   ```
2. **Configure Variables:** Set the new 32+ character JWT_SECRET as primary, and move the old secret to `OLD_JWT_SECRET`.
3. **Sign with New Key:** Configure `authController.js` to sign new tokens exclusively with the new `JWT_SECRET`.
4. **Deprecate Fallback:** After 7 days (the expiration time of the old tokens), remove `OLD_JWT_SECRET` from the environment.

### Phase 3: Google Maps API Key Rotation (Graceful Migration)
1. **Generate Restricted Key:** Create a new API key in the Google Cloud Console. Apply API restrictions (Maps SDK only) and Android restrictions (package ID and SHA-1 fingerprint).
2. **Update Mobile App:** Replace `MAPS_API_KEY` in `android/gradle.properties` with the new key.
3. **Release Update:** Publish the update to the Google Play Store.
4. **Decommission:** Keep the old key active in GCP Console until metrics show that old client version usage is below 1%. Then, delete the old key from the GCP Console.

---

## 10. Rollback Procedures
If any rotation phase introduces failures, the DevSecOps team must trigger immediate rollback actions:

* **MongoDB Connection Failures:** Re-enable the original Atlas user (`prakashkumarbiswal503_db_user`) in the MongoDB console, and revert the server environment variable to the old URI string.
* **JWT Token Validation Rejection:** Set the `JWT_SECRET` environment variable back to the original fallback secret string (`sheildai_production_secure_jwt_secret_key_with_over_32_chars`), allowing existing client tokens to authenticate.
* **Maps Render Failures:** Re-enable billing/unrestricted configuration on the old API key in the GCP Console.

---

## 11. Recommended Actions
1. **Un-track `.env` from Git Cache:** Run `git rm --cached .env` to stop tracking changes while preserving the local file.
2. **Un-track Google Services:** Run `git rm --cached android/app/google-services.json` to stop tracking Firebase client metadata.
3. **Uncomment `.gitignore` Entries:** Modify the root `.gitignore` to uncomment `.env` and `google-services.json` entries to prevent accidental commits.
4. **Setup Production Key Injection:** Move all local configuration files to template setups (e.g. create `.env.example` with dummy values) and inject production configurations exclusively via container environment settings.
