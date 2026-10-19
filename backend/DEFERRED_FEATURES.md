# Idir Connect — Deferred Features & Production Roadmap

This checklist documents architectural features, third-party integrations, and optimizations intentionally deferred or requiring external production credentials and infrastructure.

---

## 📋 Checklist of Intentionally Deferred Features

### 1. External Payment Gateway Direct Execution
- [ ] **Telebirr Direct Webhook & B2C Payout Integration**:
  - *Reason Deferred*: Requires official Ethio Telecom enterprise merchant credentials, certificate signing keys, and HTTPS webhook URLs.
  - *Current Implementation*: Payment method tracking (`TELEBIRR`, `CBE_BIRR`, `BANK_TRANSFER`, `CASH`), reference numbers, and auditable manual verification workflows are fully implemented.
- [ ] **Chapa / CBE Birr API Integration**:
  - *Reason Deferred*: Requires commercial merchant API keys and test sandboxes.

### 2. Physical File & Document Storage
- [ ] **S3 / MinIO / Google Cloud Storage Object Store**:
  - *Reason Deferred*: Requires live cloud bucket credentials (`AWS_S3_BUCKET`, `AWS_ACCESS_KEY_ID`).
  - *Current Implementation*: Receipt URLs, file metadata references, and validation are supported in the database schema.

### 3. SMS & Push Notification Dispatchers
- [ ] **Ethio Telecom / Twilio SMS OTP Gateway**:
  - *Reason Deferred*: Requires live telecom aggregator credentials.
  - *Current Implementation*: Notifications are persisted to the database and exposed via `/api/v1/notifications` with unread count badges.
- [ ] **Firebase Cloud Messaging (FCM) Device Token Sync**:
  - *Reason Deferred*: Requires `google-services.json` server key configuration.

### 4. Background Job Queuing
- [ ] **BullMQ / Redis Asynchronous Task Processing**:
  - *Reason Deferred*: Keeps the modular monolith lightweight and zero-dependency beyond PostgreSQL for local development.
  - *Future Use Case*: Automated nightly recurring dues generation, scheduled meeting reminders, batch penalty calculations.

### 5. Multi-Signatory Cryptographic Voting Workflow
- [ ] **Multi-signature On-chain or Quorum Voting**:
  - *Reason Deferred*: The current multi-approval setting (`requireMultiApproval: true`) satisfies standard bylaws through sequential Committee and Chairperson sign-offs.
