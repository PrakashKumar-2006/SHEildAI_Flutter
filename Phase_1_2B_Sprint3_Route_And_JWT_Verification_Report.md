# Phase 1.2B Sprint 3 Route & JWT Verification Report

## 1. Executive Summary
This report presents the security audit and verification results of Sprint 3 for user-facing API routes, ownership validation mechanisms, and JWT signature configurations. All API endpoints have been analyzed for protection gaps, and live tests have confirmed the presence of major vulnerabilities.

### Audit Summary Table

| Finding | Description | Status |
| :--- | :--- | :---: |
| **1. User Route Exposure** | User profile and location synchronisation endpoints are publicly exposed without authentication checks. | **VERIFIED** |
| **2. Contact Route Exposure** | All emergency contact CRUD routes (GET, POST, DELETE, PATCH) are publicly accessible. | **VERIFIED** |
| **3. SOS Route Exposure** | SOS trigger and status update APIs are publicly accessible without verification. | **VERIFIED** |
| **4. Community Route Exposure** | WebSocket event handlers for community reports are public with zero identity validation. | **VERIFIED** |
| **5. Missing Ownership Validation** | Even if authenticated, the backend fails to verify that the requesting user owns the resource they are accessing/modifying. | **VERIFIED** |
| **6. JWT Secret Fallback Vulnerability** | Code contains silent hardcoded fallback keys (`'sheildai_secret'`) in case environment secrets are missing. | **VERIFIED** |

---

## 2. Route Inventory
Below is a complete inventory of user-facing APIs on the backend server:

| Method | Path | Controller | Middleware Applied | Auth Required? | Ownership Validation? | Code Evidence |
| :--- | :--- | :--- | :--- | :---: | :---: | :--- |
| **POST** | `/api/auth/token` | `getToken` | None | **NO** (Firebase Token in body) | NO | [authRoutes.js:L6](file:///c:/Development/Projects/sheild_ai/backend/src/routes/authRoutes.js#L6) |
| **POST** | `/api/auth/register` | Stub | None | **NO** | NO | [authRoutes.js:L9](file:///c:/Development/Projects/sheild_ai/backend/src/routes/authRoutes.js#L9) |
| **POST** | `/api/auth/login` | Stub | None | **NO** | NO | [authRoutes.js:L10](file:///c:/Development/Projects/sheild_ai/backend/src/routes/authRoutes.js#L10) |
| **POST** | `/api/users/location` | `updateLocation` | None | **NO** | NO | [userRoutes.js:L6](file:///c:/Development/Projects/sheild_ai/backend/src/routes/userRoutes.js#L6) |
| **GET** | `/api/users/profile/:userId` | `getProfile` | None | **NO** | NO | [userRoutes.js:L9](file:///c:/Development/Projects/sheild_ai/backend/src/routes/userRoutes.js#L9) |
| **GET** | `/api/contacts/:userPhone` | `getContacts` | None | **NO** | NO | [contactRoutes.js:L8](file:///c:/Development/Projects/sheild_ai/backend/src/routes/contactRoutes.js#L8) |
| **POST** | `/api/contacts/:userPhone` | `addContact` | None | **NO** | NO | [contactRoutes.js:L9](file:///c:/Development/Projects/sheild_ai/backend/src/routes/contactRoutes.js#L9) |
| **DELETE**| `/api/contacts/:userPhone/:contactPhone` | `removeContact` | None | **NO** | NO | [contactRoutes.js:L10](file:///c:/Development/Projects/sheild_ai/backend/src/routes/contactRoutes.js#L10) |
| **PATCH** | `/api/contacts/:userPhone/:contactPhone/primary`| `setPrimary` | None | **NO** | NO | [contactRoutes.js:L11](file:///c:/Development/Projects/sheild_ai/backend/src/routes/contactRoutes.js#L11) |
| **POST** | `/api/sos/trigger` | `triggerSOS` | None | **NO** | NO | [sosRoutes.js:L7](file:///c:/Development/Projects/sheild_ai/backend/src/routes/sosRoutes.js#L7) |
| **PUT** | `/api/sos/:sosId/status` | `updateStatus` | None | **NO** | NO | [sosRoutes.js:L8](file:///c:/Development/Projects/sheild_ai/backend/src/routes/sosRoutes.js#L8) |
| **Socket**| `community_report` event | WebSocket handler | None | **NO** | NO | [index.js:L174](file:///c:/Development/Projects/sheild_ai/backend/src/index.js#L174) |

---

## 3. User Route Audit
**Result:** **VERIFIED** (Vulnerable)

Unauthenticated users can fully interact with user profiles and location synchronisation heartbeats.
* **Profile Reading:** `GET /api/users/profile/:userId` has no protection checks.
* **Profile Editing:** Covered under `updateLocation` flow which automatically creates/modifies user profiles in MongoDB without any authentication headers.
* **Location Access:** Anyone can POST coordinates for any `user_id` to update their tracking points.
* **Cross-User Access:** An attacker can query User B's profile simply by replacing the parameter `:userId` with User B's email, phone, or Firebase UID.

---

## 4. Contact Route Audit
**Result:** **VERIFIED** (Vulnerable)

Emergency contact routes have no protection:
* Unauthenticated requests to `GET`, `POST`, `DELETE`, and `PATCH` under `/api/contacts/*` succeed.
* User A can manipulate User B's contacts by sending a POST request to `/api/contacts/UserBPhone` or delete User B's contact via `/api/contacts/UserBPhone/ContactPhone`.

---

## 5. SOS Route Audit
**Result:** **VERIFIED** (Vulnerable)

SOS routes are completely unprotected:
* **Triggering SOS:** Anyone can trigger a live SOS alert on behalf of any phone number by making an unauthenticated `POST /api/sos/trigger` request.
* **Modifying SOS Status:** Anyone can update status to `resolved` or `false_alarm` using `PUT /api/sos/:sosId/status`.
* **Cross-User Triggering:** User A can trigger an alert on behalf of User B by modifying the `user_id` parameter in the request payload.

---

## 6. Community Route Audit
**Result:** **VERIFIED** (Vulnerable)

Community reports do not have dedicated REST endpoints (404 on this version of the backend for `/api/community-reports`), but are handled via WebSockets:
* **Create reports:** The WebSocket listener for the `community_report` event accepts any payload from any socket connection without checking authentication.
* **Edit/Delete reports:** Not implemented in user-facing websocket/HTTP API.
* **Spoofing risk:** User A can connect to the websocket and spoof reports for User B since no credentials/token signature verification checks exist on connection or event message.

---

## 7. Ownership Validation Audit
**Result:** **VERIFIED** (Vulnerable)

* **Ownership Check Present?** No.
* **Description:** There is no logic inside `authController.js`, `contactController.js`, or `sosController.js` verifying that `req.user.id` or `req.user.phone` matches the target resource owner.
* **Evidence:** For example, [contactController.js:L9](file:///c:/Development/Projects/sheild_ai/backend/src/controllers/contactController.js#L9) retrieves phone parameters directly:
  ```javascript
  const { userPhone } = req.params;
  const contacts = await contactRepository.findByUser(userPhone, traceId);
  res.status(200).json(contacts);
  ```
  It returns contacts for `userPhone` without verifying if `req.user.phone` matches `userPhone`.

---

## 8. JWT Configuration Audit
**Result:** **VERIFIED** (Vulnerable)

The hardcoded fallback signature key `'sheildai_secret'` is active in 2 locations:

### 1. Verification Middleware: [auth.js:L13](file:///c:/Development/Projects/sheild_ai/backend/src/middleware/auth.js#L13)
```javascript
const decoded = jwt.verify(token, process.env.JWT_SECRET || 'sheildai_secret');
```
* **Purpose:** Validates client JWT signatures. Falls back if environment variables are not found.

### 2. Token Issuance Controller: [authController.js:L70](file:///c:/Development/Projects/sheild_ai/backend/src/controllers/authController.js#L70)
```javascript
process.env.JWT_SECRET || 'sheildai_secret',
```
* **Purpose:** Signs issued JWTs. Falls back silently if `process.env.JWT_SECRET` is missing.

---

## 9. JWT Fallback Risk Assessment
**Result:** **INSECURE**

If `JWT_SECRET` is missing from the environment:
1. **Fallback Key Active:** The server silently falls back to `'sheildai_secret'` without printing any warnings or throwing errors.
2. **Tokens Still Issued:** The server continues to sign tokens using `'sheildai_secret'`.
3. **Tokens Validated:** Verification is performed using `'sheildai_secret'`.
4. **Forging Vulnerability:** An attacker who knows this codebase can sign valid JWTs locally with the string `'sheildai_secret'` and successfully compromise all protected routes on the server.

---

## 10. Live Security Tests

A local test environment simulated client requests against the server. Below are the actual results:

* **TEST A: Access profile without token**
  * Expected: `401 Unauthorized`
  * Actual: `200 OK` (Returned User B's profile document)
  * Status: **FAIL** (Vulnerable)
* **TEST B: Access contacts without token**
  * Expected: `401 Unauthorized`
  * Actual: `200 OK` (Returned User B's contacts list)
  * Status: **FAIL** (Vulnerable)
* **TEST C: Trigger SOS without token**
  * Expected: `401 Unauthorized`
  * Actual: `200 OK` (Successfully triggered SOS for User B)
  * Status: **FAIL** (Vulnerable)
* **TEST D: User A accesses User B profile**
  * Expected: `403 Forbidden`
  * Actual: `200 OK` (Returned User B's profile details)
  * Status: **FAIL** (Vulnerable)
* **TEST E: User A modifies User B contacts**
  * Expected: `403 Forbidden`
  * Actual: `201 Created` (Added a contact to User B's profile)
  * Status: **FAIL** (Vulnerable)
* **TEST F: User A triggers SOS for User B**
  * Expected: `403 Forbidden`
  * Actual: `200 OK` (Successfully persisted SOS alert under User B's phone number)
  * Status: **FAIL** (Vulnerable)
* **TEST G: Attempt JWT creation without configured `JWT_SECRET`**
  * Expected: Fails to validate tokens using a custom secret.
  * Actual: Successfully created token using default fallback, and validated it using the key `'sheildai_secret'`.
  * Status: **FAIL** (Vulnerable)

---

## 11. Verified Vulnerabilities
1. **User Route Exposure** — **VERIFIED**
2. **Contact Route Exposure** — **VERIFIED**
3. **SOS Route Exposure** — **VERIFIED**
4. **Community Route Exposure** — **VERIFIED**
5. **Missing Ownership Validation** — **VERIFIED**
6. **JWT Secret Fallback Vulnerability** — **VERIFIED**

## 12. False Positives
* None.

## 13. Not Verified Findings
* None.

## 14. Recommendations
* Attach the JWT authentication `protect` middleware to all user-facing endpoints in `userRoutes.js`, `contactRoutes.js`, and `sosRoutes.js`.
* Add ownership validation checks inside the controllers (`userPhone === req.user.phone` or `req.user._id` matching request target).
* Throw a hard error in `index.js` or `db.js` if `process.env.JWT_SECRET` is undefined, preventing the server from starting with unsafe fallbacks in production.
