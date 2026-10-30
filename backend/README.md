# Idir Connect — Backend REST API & Database

Production-grade modular monolith backend for **Idir Connect** — digitizing Ethiopian community-based mutual aid associations (**Idirs**) and rotating savings groups (**Ikub**).

Built with **Node.js**, **Express.js**, **TypeScript (Strict Mode)**, **PostgreSQL**, and **Prisma ORM**.

---

## 🏛️ Architecture & Database Design

Idir Connect is engineered as a **modular monolith** with strict domain boundaries, three-tier separation (Routes $\to$ Controllers $\to$ Services $\to$ Prisma ORM), and complete financial segregation between Idir mutual-aid funds and Ikub rotating savings pools.

### Database Entity Relationship Diagram (Mermaid)

```mermaid
erDiagram
    User ||--o{ RefreshToken : has
    User ||--o{ Membership : holds
    User ||--o{ Notification : receives
    User ||--o{ AuditLog : performs

    Idir ||--|| IdirSettings : configures
    Idir ||--o{ Membership : contains
    Idir ||--o{ ContributionType : defines
    Idir ||--o{ Contribution : collects
    Idir ||--o{ Expense : incurs
    Idir ||--o{ AssistanceCase : manages
    Idir ||--o{ IkubGroup : hosts
    Idir ||--o{ Meeting : schedules
    Idir ||--o{ Announcement : broadcasts
    Idir ||--o{ AuditLog : scopes

    Membership ||--o{ Contribution : pays
    Membership ||--o{ AssistanceCase : applies_for
    Membership ||--o{ IkubParticipant : participates_in
    Membership ||--o{ MeetingAttendance : attends

    AssistanceCase ||--o{ AssistanceRequest : contains
    AssistanceRequest ||--o{ AssistanceDisbursement : fulfills

    IkubGroup ||--o{ IkubParticipant : includes
    IkubGroup ||--o{ IkubRound : divides_into
    IkubRound ||--o{ IkubContribution : aggregates
    IkubRound ||--o| IkubPayout : awards
    IkubParticipant ||--o{ IkubContribution : deposits
    IkubParticipant ||--o{ IkubPayout : receives
```

---

## 👥 Three-Developer Team Ownership

To support parallel feature engineering without merge conflicts or database drift:

| Module Domain | Owner | Included Features & Endpoints | Entities Owned |
| :--- | :--- | :--- | :--- |
| **Core Idir & Identity** | **Developer 1** | Auth, JWT rotation, Users, Fayda KYC, Idirs, Settings, Memberships | `User`, `RefreshToken`, `Idir`, `IdirSettings`, `Membership` |
| **Finance & Mutual Aid** | **Developer 2** | Contributions, Reversals, Operating Expenses, Assistance Cases, Disbursements, Reports, Audit | `ContributionType`, `Contribution`, `Expense`, `AssistanceCase`, `AssistanceRequest`, `AssistanceDisbursement`, `AuditLog` |
| **Ikub & Community** | **Developer 3** | Ikub Groups, Rounds, Pools, Payouts, Meetings, Attendance, Announcements, Notifications | `IkubGroup`, `IkubParticipant`, `IkubRound`, `IkubContribution`, `IkubPayout`, `Meeting`, `MeetingAttendance`, `Announcement`, `Notification` |

*See [MODULE_OWNERSHIP.md](file:///c:/Users/HP/Desktop/Idir/backend/MODULE_OWNERSHIP.md) for full contracts.*

---

## 🚀 Quick Start & Installation

### Prerequisites
- Node.js $\ge$ 20.x
- npm $\ge$ 10.x
- Docker & Docker Compose (or local PostgreSQL instance)

### 1. Environment Configuration
Navigate to the `backend/` directory and configure environment variables:
```bash
cd backend
cp .env.example .env
```
Default `.env` configuration:
```env
NODE_ENV=development
PORT=5000
API_PREFIX=/api/v1
DATABASE_URL="postgresql://postgres:postgrespassword@localhost:5432/idir_connect_db?schema=public"
JWT_ACCESS_SECRET="idir-connect-super-secure-jwt-access-secret-32-chars-long"
JWT_REFRESH_SECRET="idir-connect-super-secure-jwt-refresh-secret-32-chars-long"
JWT_ACCESS_EXPIRES_IN="15m"
JWT_REFRESH_EXPIRES_IN="7d"
```

### 2. Start PostgreSQL with Docker Compose
```bash
docker-compose up -d postgres
```

### 3. Generate Prisma Client & Run Migrations
```bash
npm run prisma:generate
npm run prisma:migrate
```

### 4. Seed Database with Realistic Community Data
```bash
npm run prisma:seed
```

### 5. Start Development Server
```bash
npm run dev
```
The server will boot on `http://localhost:5000` with interactive Swagger API docs at `http://localhost:5000/api/docs`.

---

## 🔑 Development Credentials for Testing

The seed script creates ready-to-test accounts pre-configured with roles in Ethiopian community Idirs:

| Account Role | Phone Number | Password | Fayda ID | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Platform Admin** | `+251911000000` | `Password123!` | — | Full administrative access |
| **Chairperson** | `+251911111111` | `Password123!` | `100020003001` | Bole Medhanealem Idir Chairperson |
| **Treasurer** | `+251911222222` | `Password123!` | `100020003002` | Financial officer & payout verifier |
| **Secretary** | `+251911333333` | `Password123!` | `100020003003` | Meeting & announcement manager |
| **Ordinary Member** | `+251911555555` | `Password123!` | — | Enrolled member & Ikub participant |

---

## 📖 API Documentation (OpenAPI / Swagger)

Interactive API documentation with request execution is accessible at:
- **Interactive UI**: `http://localhost:5000/api/docs` or `http://localhost:5000/api/v1/docs`

### Major Endpoint Groups

#### Authentication (`/api/v1/auth`)
- `POST /register`: Register user with phone, password, and optional Fayda ID.
- `POST /login`: Authenticate and receive access + refresh token.
- `POST /refresh`: Securely rotate refresh token and obtain new access token.
- `POST /logout`: Invalidate refresh token session.
- `GET /me`: Current user identity and Idir memberships.

#### Idirs & Memberships (`/api/v1/idirs`)
- `POST /`: Create an Idir (creator automatically assigned Chairperson).
- `GET /`: List accessible Idirs (paginated, searchable).
- `GET /:idirId`: Idir metadata and settings.
- `PATCH /:idirId`: Update Idir profile (Chairperson only).
- `PATCH /:idirId/settings`: Update dues amounts, frequencies, and approval rules.
- `POST /:idirId/members`: Enroll a member (duplicate membership strictly prevented).
- `GET /:idirId/members`: List Idir members with role/status filters.
- `PATCH /:idirId/members/:membershipId`: Update member role or status.
- `POST /:idirId/members/:membershipId/deactivate`: Deactivate membership.

#### Contributions & Financial Reversals (`/api/v1/idirs/:idirId/contributions`)
- `POST /types`: Create mandatory/voluntary contribution types.
- `GET /types`: List active contribution types.
- `POST /`: Record contribution (supports offline idempotency via `clientMutationId`).
- `GET /`: List contributions with date, type, and status filters.
- `POST /:contributionId/reverse`: Auditable reversal record with mandatory reason.

#### Operating Expenses (`/api/v1/idirs/:idirId/expenses`)
- `POST /`: Submit operating expense with category and receipt URL.
- `GET /`: List expenses.
- `POST /:expenseId/review`: Approve or reject expense (Chairperson only).

#### Emergency & Funeral Assistance (`/api/v1/idirs/:idirId/assistance`)
- `POST /cases`: Open funeral or emergency assistance case (confidentiality support).
- `GET /cases`: List assistance cases (confidential cases restricted to applicant/committee).
- `POST /cases/:caseId/requests`: Submit monetary support request.
- `POST /cases/:caseId/requests/:requestId/review`: Committee approval/rejection.
- `POST /requests/:requestId/disburse`: Execute disbursement with receipt generation.

#### Ikub Rotating Savings (`/api/v1/idirs/:idirId/ikub`)
- `POST /groups`: Create Ikub group (weekly/monthly, fixed amount, lottery rules).
- `GET /groups`: List Ikub groups.
- `POST /groups/:groupId/participants`: Enroll member in savings group.
- `POST /groups/:groupId/rounds`: Schedule round.
- `POST /groups/:groupId/contributions`: Record round savings contribution.
- `POST /groups/:groupId/payouts`: Award round payout (duplicate payouts strictly prevented).
- `GET /groups/:groupId/summary`: Group savings pool vs payouts summary.

#### Reports & Audit (`/api/v1/idirs/:idirId`)
- `GET /reports/finances`: Isolated Idir financial statement & separated Ikub pool balance.
- `GET /reports/members/:membershipId/contributions`: Individual member dues statement.
- `GET /audit`: Immutable audit log (Chairperson & Auditor only).

---

## 💰 Strict Financial Integrity Rules

1. **Physical & Logical Segregation**:
   - Idir funds (mutual aid, regular dues, emergency assistance, expenses) and Ikub funds (rotating savings pools, round payouts) are stored in separate relational tables.
   - Financial report endpoints calculate and return Idir ledger balances and Ikub pool balances separately:
     $$\text{Idir Net} = \text{Contributions} - (\text{Expenses} + \text{Disbursements})$$
     $$\text{Ikub Pool} = \text{Ikub Contributions} - \text{Ikub Payouts}$$
2. **Decimal Precision**: All currency amounts use `Prisma.Decimal(14, 2)`. Float math is banned.
3. **No Hard Deletes**: Confirmed contributions and payouts are never deleted. Errors are corrected via auditable reversal records (`isReversed`, `reversalReason`, `reversedAt`, `reversedById`).
4. **Duplicate Payout Prevention**: `IkubPayout` enforces a database `@@unique([roundId])` constraint and checks `hasWonPayout === false` before confirming.

---

## 📱 Flutter Offline-First Contract

To support rural or intermittent mobile connectivity in Ethiopia:
- **Client Mutation IDs**: When Flutter devices record contributions or savings offline, they include a client-generated UUID in `clientMutationId`.
- **Idempotency Guarantee**: If an offline request is retried upon reconnection, the server returns the existing transaction without double-charging or creating duplicates.
- **Pending Status**: Offline submissions default to `PENDING` until validated and accepted by the server.

---

## 🧪 Automated Testing & Verification

The test suite runs using **Vitest** and **Supertest**:

```bash
# Run automated test suite
npm test

# Run TypeScript type check
npm run lint

# Compile production bundle
npm run build
```

---

## 🚢 Production Deployment with Docker

To build and run the full production stack:
```bash
docker-compose up --build -d
```
This launches:
1. `idir_connect_postgres`: Hardened PostgreSQL 16 Alpine container with persistent volume.
2. `idir_connect_api`: Multi-stage built Node.js runtime container running the compiled Express API.


---

## 👥 Multi-Idir Architecture & System Isolation

Idir Connect provides a **Telegram-style multi-Idir account switcher** allowing members and administrators to participate in multiple community Idirs seamlessly while guaranteeing complete, inviolable data isolation:

### 1. Telegram-Style Community Switching
- Users can switch their active community directly from the app bar title dropdown or the switcher action in the AppBar and More screens.
- Selecting another community updates `activeIdirProvider` and persists the selection per-user.
- The switcher UI mimics Telegram's account switcher with member role badges, community initials avatars, and active checkmarks.

### 2. Strict Multi-Tenant Data Isolation
- **Backend Authorization Barrier**: All Idir operations are routed under `/api/v1/idirs/:idirId/...` and protected by `requireIdirRole`. The middleware queries `prisma.membership` for `status === 'ACTIVE'` for the requesting user and target `idirId`. If no active membership exists, requests are immediately rejected with `403 Forbidden` and logged as `ACCESS_DENIED` security audit events.
- **Frontend Reactive Scoping**: Riverpod's `activeIdirIdProvider` drives all feature repositories (`RestMembersRepository`, `RestContributionsRepository`, `RestExpensesRepository`, `RestClaimsRepository`, `RestAnnouncementsRepository`, `RestAuditLogRepository`). When the active Idir switches, existing repositories and streams are disposed and re-instantiated strictly for the new `idirId`.
- **Cache Partitioning**: Local offline caches partition data strictly by Idir ID (`cache_members_${idirId}`, `cache_contributions_${idirId}`, etc.), ensuring zero cross-community data leakage.
