# Idir Connect (እድር ኮኔክት) — Full-Stack Community Platform

A digital platform modernizing Ethiopian community mutual-aid associations (**Idir** / እድር) and rotating savings/credit groups (**Ikub** / ዕቁብ) with offline-first synchronization, indigenous governance bylaws, and cryptographic audit integrity.

[![Flutter](https://img.shields.io/badge/Flutter-3.22+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.5+-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org)
[![Express](https://img.shields.io/badge/Express-4.21+-000000?logo=express&logoColor=white)](https://expressjs.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Prisma](https://img.shields.io/badge/Prisma-5.19-2D3748?logo=prisma&logoColor=white)](https://www.prisma.io)
[![License: ISC](https://img.shields.io/badge/License-ISC-blue.svg)](https://opensource.org/licenses/ISC)

---

## 🌟 Key Application Features & Innovations

1. **Algorithmic Enforcement of Indigenous Bylaws**:
   - **Four-Eyes Principle (Two-Officer Approval)**: Emergency and bereavement assistance disbursements strictly require concurring approvals from both the Chairperson (ሰብሳቢ) and Treasurer (ገንዘብ ያዥ).
   - **Strict Self-Approval Ban**: Officers submitting personal or family claims are programmatically barred from voting on their own claims.
   - **Rule 3 Solvency Equation**: Real-time mathematical verification of reserve fund solvency:
     $$\text{Closing Reserve} = \text{Opening Balance} + \sum \text{Dues} - \sum \text{Disbursements} - \sum \text{Operating Expenses}$$

2. **Strict Financial Segregation & Integrity**:
   - Physical and logical database separation between communal mutual-aid funds and Ikub rotating savings pools (no co-mingling of funds).
   - All monetary amounts use high-precision decimals (`Decimal(14, 2)`). Floating point arithmetic is banned.
   - Immutable financial history: No hard deletes. Adjustments are handled via auditable soft reversals with documented reasons.

3. **Forensic Cryptographic SHA-256 Audit Chain**:
   - Append-only hash chain linking each administrative and financial transaction:
     $$\text{Block}_N.\text{hash} = \text{SHA256}(\text{Block}_{N-1}.\text{hash} + \text{actorId} + \text{action} + \text{targetId} + \text{timestamp})$$
   - Independent verification engine alerts the Auditor immediately if any historical record is altered.

4. **Offline-First Synchronization Engine**:
   - Seamless dues collection during rural network outages using client-generated mutation UUIDs (`clientMutationId`).
   - Idempotent backend transaction processing guarantees no double-charging upon network reconnection.

5. **Democratic Leadership Elections & Governance**:
   - Complete democratic election lifecycle: candidate nomination periods, candidate statements, secret balloting booth, automated vote tallying, and voter verification receipts.
   - 48-hour dispute window with committee resolution and automatic leadership role handover upon certification.
   - Leadership vacancy administration and constitutional **Votes of No-Confidence** (66.67% supermajority threshold).

6. **Trilingual Cultural Accessibility**:
   - Full native localization in **English**, **Amharic (አማርኛ)**, and **Afaan Oromoo**.
   - Custom typography rendering with Google's `Noto Sans Ethiopic`.

7. **Multi-Idir Switching & Hardware Keystore**:
   - Single account can hold memberships across multiple Idirs and seamlessly switch between them.
   - Biometric / Salted 4-digit PIN service with hardware keystore (`flutter_secure_storage`), 2-minute auto-inactivity lock, and 5-attempt brute-force protection.

8. **PDF Receipts & Balance Sheets**:
   - Instant in-app printable PDF receipts for dues contributions (`REC-YYMMDD-XXXX`) and annual association balance sheets.

---

## 📁 Repository Structure

```
Idir/
├── documentation.md          # Comprehensive Graduation Project Technical Report & Defense Guide
├── THREAT_MODEL.md           # STRIDE & OWASP Security Architecture Specification
├── README.md                 # Project Overview & Quick Start Guide
│
├── frontend/                 # Cross-Platform Mobile Client (Flutter 3.22, Dart 3.3)
│   ├── lib/
│   │   ├── main.dart         # App entry point & Riverpod ProviderScope
│   │   ├── core/             # Cross-cutting: router, network, keystore, theme, active Idir provider
│   │   ├── features/         # Domain features (auth, idirs, members, contributions, claims,
│   │   │                     #                  expenses, ikub, elections, reports, audit)
│   │   └── l10n/             # ARB localization files (Amharic, Afaan Oromoo, English)
│   ├── assets/               # Ethiopic typography (Noto Sans Ethiopic) & icons
│   ├── pubspec.yaml          # Flutter dependencies & metadata
│   └── test/                 # 25 automated unit & widget test suites
│
└── backend/                  # RESTful API Modular Monolith & Database (Express, TypeScript)
    ├── prisma/
    │   ├── schema.prisma     # 21-entity relational database schema
    │   ├── seed.ts           # Realistic Ethiopian community seed data
    │   └── migrations/       # Versioned PostgreSQL migrations
    ├── src/
    │   ├── app.ts            # Express application routing & middleware
    │   ├── server.ts         # Server bootstrap & graceful shutdown
    │   ├── middleware/       # JWT auth, RBAC authorization, rate limiter, active Idir guards
    │   ├── modules/          # 14 isolated domain modules (auth, idirs, contributions,
    │   │                     #                             assistance, ikub, elections, audit, etc.)
    │   └── docs/             # OpenAPI / Swagger specification
    ├── tests/                # 13 Vitest & Supertest automated test suites
    ├── docker-compose.yml    # Hardened PostgreSQL 16 container definition
    └── package.json          # Node.js dependencies & scripts
```

---

## 🚀 How to Run the Entire Application

To run the complete platform locally, open **two terminal windows**:

### 🖥️ Step 1: Backend REST API & PostgreSQL Database (Terminal 1)

```bash
# 1. Navigate to the backend directory
cd backend

# 2. Start PostgreSQL 16 database container in Docker
docker-compose up -d postgres

# 3. Install backend dependencies
npm install

# 4. Generate Prisma Client & apply database migrations
npm run prisma:generate
npm run prisma:migrate

# 5. Seed database with realistic Ethiopian community data & test accounts
npm run prisma:seed

# 6. Start the development server
npm run dev
```

- 🌐 **REST API Base URL**: `http://localhost:5000/api/v1`
- 📖 **Interactive Swagger API Docs**: `http://localhost:5000/api/docs`
- 💓 **Health Check**: `http://localhost:5000/health`

---

### 📱 Step 2: Frontend Mobile Application (Terminal 2)

```bash
# 1. Navigate to the frontend directory
cd frontend

# 2. Install Flutter dependencies
flutter pub get

# 3. Generate trilingual localization classes (Amharic, Afaan Oromoo, English)
flutter gen-l10n

# 4. Run the application
# For Web (Google Chrome):
flutter run -d chrome --web-port 8080

# OR for connected Android device or Emulator:
flutter run
```

---

### 🐳 Alternative: Run Complete Backend via Docker Compose

```bash
cd backend
docker-compose up --build -d
```

This builds and launches both the `idir_connect_postgres` database container and the multi-stage compiled `idir_connect_api` Node.js container.

---

## 🔑 Pre-Seeded Test Credentials

The database seed (`npm run prisma:seed`) pre-populates ready-to-test accounts representing all traditional institutional roles:

| Role                    | Phone Number    | Password       | Cultural Responsibility                                             |
| :---------------------- | :-------------- | :------------- | :------------------------------------------------------------------ |
| **Platform Admin**      | `+251911000000` | `Password123!` | System-wide administrator                                           |
| **Chairperson** (ሰብሳቢ)  | `+251911111111` | `Password123!` | Bole Medhanealem Idir Chairperson, claim approvals, elections       |
| **Treasurer** (ገንዘብ ያዥ) | `+251911222222` | `Password123!` | Dues collections, payout disbursements, expense records             |
| **Secretary** (ጸሐፊ)     | `+251911333333` | `Password123!` | Meeting minutes, announcements, attendance rosters                  |
| **Auditor** (ኦዲተር)      | `+251911444444` | `Password123!` | Rule 3 solvency reconciliation & SHA-256 audit log inspection       |
| **Member** (አባል)        | `+251911555555` | `Password123!` | Enrolled contributing member, Ikub participant, secret ballot voter |

---

## 🧪 Automated Testing & Verification

Both backend and frontend feature rigorous automated test coverage:

```bash
# Backend Automated Tests (13 Vitest suites)
cd backend
npm test

# Frontend Automated Tests (25 Flutter test suites)
cd frontend
flutter test
```

---

## 📚 Project Documentation

- **STRIDE Threat Model & Security Architecture**: [THREAT_MODEL.md](file:///c:/Users/HP/Desktop/Idir/THREAT_MODEL.md)
- **Backend Architecture & Database Specifications**: [backend/README.md](file:///c:/Users/HP/Desktop/Idir/backend/README.md)
- **Three-Developer Module Division & Ownership**: [backend/MODULE_OWNERSHIP.md](file:///c:/Users/HP/Desktop/Idir/backend/MODULE_OWNERSHIP.md)
- **Deferred Features & Production Roadmap**: [backend/DEFERRED_FEATURES.md](file:///c:/Users/HP/Desktop/Idir/backend/DEFERRED_FEATURES.md)

## Group Members

- Yeroman Diriba
- Ebisa Mitiku
- Lami Megersa
