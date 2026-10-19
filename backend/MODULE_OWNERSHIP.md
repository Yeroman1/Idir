# Idir Connect — Three-Developer Module Ownership Specification

To facilitate seamless parallel engineering across three backend developers without schema drift or merge conflicts, the codebase is partitioned into distinct module boundaries governed by a shared Prisma schema and standard API conventions.

---

## 🏛️ Shared Contracts & Architectural Invariants (All Developers)

1. **Shared Database Schema**: All entities live in [prisma/schema.prisma](file:///c:/Users/HP/Desktop/Idir/backend/prisma/schema.prisma). No developer may create rogue database branches or conflicting schemas. Schema edits require consensus.
2. **API Conventions**:
   - Base URL: `/api/v1`
   - Response Envelope: `{ "success": true, "data": ..., "message": "...", "meta": ... }`
   - Error Envelope: `{ "success": false, "error": { "code": "...", "message": "...", "details": ... } }`
3. **Data Access**: Strictly through `prisma` client with parameterized queries.
4. **Idir Scoping**: All operations within an Idir must verify permissions using `requireIdirRole([...])`.
5. **Decimal Money**: Float types are forbidden for monetary values; use Prisma `Decimal(14, 2)`.

---

## 👤 Developer 1 — Core Idir, Identity & Access Control

### Scope of Ownership
- **Authentication & Security**: User registration, login, JWT issuance, rotating refresh tokens with reuse detection family lineage, session revocation.
- **User Management**: Profile retrieval and updates, language selection (`am`, `en`, `om`), Fayda Ethiopian National ID verification.
- **Idir Management**: Creating Idirs (with automatic transactional setup of settings and Chairperson role), Idir listing, geocoding metadata (region, zone, woreda, kebele).
- **Idir Settings**: Configurable regular dues, frequencies, meeting cadences, multi-approval flags.
- **Membership Management**: Adding members (by userId or phone number), automatic member numbering (`BM-001`), role assignment, member status changes, deactivation.

### Directories & Code Owned
- `src/modules/auth/`
- `src/modules/users/`
- `src/modules/idirs/`
- `src/modules/memberships/`
- `src/middleware/authenticate.ts`
- `src/middleware/authorize.ts`
- `tests/auth.test.ts`

### Prisma Entities Owned
- `User`
- `RefreshToken`
- `Idir`
- `IdirSettings`
- `Membership`

---

## 💰 Developer 2 — Finance & Mutual Assistance

### Scope of Ownership
- **Contribution Types**: Creation and management of mandatory and voluntary dues (e.g., Monthly Dues, Funeral Mutual Support, Emergency Fund).
- **Contribution Operations**: Recording payments, idempotency handling (`clientMutationId` for offline sync), receipt generation (`REC-YYMMDD-XXXX`), payment confirmations.
- **Reversal Ledger**: Immutable transaction history. Soft reversal records with documented reasons (`reversalReason`, `reversedAt`, `reversedById`).
- **Operating Expenses**: Recording expense receipts, category tagging, approval workflow (Chairperson sign-off).
- **Mutual Assistance Cases**: Emergency and funeral case opening, deceased relative linkage, confidentiality guards.
- **Assistance Requests & Disbursements**: Request submission, review notes, disbursed receipt issuance (`DISB-YYMMDD-XXXX`).
- **Financial Reports & Audit**: Segregated Idir balance statement (Contributions - Expenses - Assistance Disbursements), immutable audit log queries.

### Directories & Code Owned
- `src/modules/contributions/`
- `src/modules/expenses/`
- `src/modules/assistance/`
- `src/modules/reports/` (Idir ledger portion)
- `src/modules/audit/`
- `tests/financial_integrity.test.ts`

### Prisma Entities Owned
- `ContributionType`
- `Contribution`
- `Expense`
- `AssistanceCase`
- `AssistanceRequest`
- `AssistanceDisbursement`
- `AuditLog`

---

## 🔄 Developer 3 — Ikub & Community

### Scope of Ownership
- **Ikub Group Management**: Creating rotating savings groups, setting frequency (weekly, biweekly, monthly), contribution amount, total rounds, and payout rules (lottery, fixed, need-based).
- **Participant Administration**: Adding participants, tracking lottery orders, verifying participation eligibility.
- **Rounds & Collections**: Scheduling rounds, collecting participant round contributions with duplicate prevention.
- **Payout Safeguards**: Enforcing single payout per round, verifying recipient participant has not already won in the cycle, completing rounds in atomic transactions (`prisma.$transaction`).
- **Strict Financial Isolation**: Ensuring Ikub pools and payouts are 100% segregated from Idir mutual funds in reporting and queries.
- **Meetings**: General assembly and committee meeting scheduling, agenda tracking, attendance recording (`PRESENT`, `ABSENT`, `EXCUSED`, `LATE`).
- **Community Announcements & Notifications**: Pinned announcements, push notifications to members with unread counters.

### Directories & Code Owned
- `src/modules/ikub/`
- `src/modules/meetings/`
- `src/modules/notifications/`
- `src/modules/reports/` (Ikub ledger portion)
- `tests/ikub_and_authorization.test.ts`

### Prisma Entities Owned
- `IkubGroup`
- `IkubParticipant`
- `IkubRound`
- `IkubContribution`
- `IkubPayout`
- `Meeting`
- `MeetingAttendance`
- `Announcement`
- `Notification`
