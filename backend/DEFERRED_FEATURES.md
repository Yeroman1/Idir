# Idir Connect — Deferred Features & Production Roadmap

This checklist documents architectural features, third-party integrations, and optimizations intentionally deferred or requiring external production credentials and infrastructure.

---

## 📋 Checklist of Intentionally Deferred Features

### 1. External Payment Gateway Direct Execution

- [ ] **Telebirr Direct Webhook & B2C Payout Integration**:
  - _Reason Deferred_: Requires official Ethio Telecom enterprise merchant credentials, certificate signing keys, and HTTPS webhook URLs.
  - _Current Implementation_: Payment method tracking (`TELEBIRR`, `CBE_BIRR`, `BANK_TRANSFER`, `CASH`), reference numbers, and auditable manual verification workflows are fully implemented.
- [ ] **Chapa / CBE Birr API Integration**:
  - _Reason Deferred_: Requires commercial merchant API keys and test sandboxes.

### 2. Physical File & Document Storage

- [ ] **S3 / MinIO / Google Cloud Storage Object Store**:
  - _Reason Deferred_: Requires live cloud bucket credentials (`AWS_S3_BUCKET`, `AWS_ACCESS_KEY_ID`).
  - _Current Implementation_: Receipt URLs, file metadata references, and validation are supported in the database schema.

### 3. SMS & Push Notification Dispatchers

- [ ] **Ethio Telecom / Twilio SMS OTP Gateway**:
  - _Reason Deferred_: Requires live telecom aggregator credentials.
  - _Current Implementation_: Notifications are persisted to the database and exposed via `/api/v1/notifications` with unread count badges.
- [ ] **Firebase Cloud Messaging (FCM) Device Token Sync**:
  - _Reason Deferred_: Requires `google-services.json` server key configuration.

### 4. Background Job Queuing

- [ ] **BullMQ / Redis Asynchronous Task Processing**:
  - _Reason Deferred_: Keeps the modular monolith lightweight and zero-dependency beyond PostgreSQL for local development.
  - _Future Use Case_: Automated nightly recurring dues generation, scheduled meeting reminders, batch penalty calculations.

### 5. Multi-Signatory Cryptographic Voting Workflow

- [ ] **Multi-signature On-chain or Quorum Voting**:
  - _Reason Deferred_: The current multi-approval setting (`requireMultiApproval: true`) satisfies standard bylaws through sequential Committee and Chairperson sign-offs.
