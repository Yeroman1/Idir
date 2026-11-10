-- Migration: Cross-Idir Cooperation Module
-- Creates enums, tables, foreign keys, indexes, and RLS policies for Cross-Idir Cooperation

-- 1. Create Enums
DO $$ BEGIN
  CREATE TYPE "CooperationStatus" AS ENUM ('PENDING', 'ACTIVE', 'COMPLETED', 'CANCELLED', 'REJECTED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "JointInitiativeCategory" AS ENUM ('EMERGENCY_ASSISTANCE', 'COMMUNITY_SUPPORT', 'JOINT_MEETING', 'OTHER');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "JointInitiativeStatus" AS ENUM ('DRAFT', 'ACTIVE', 'COMPLETED', 'CANCELLED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "CrossIdirAnnouncementCategory" AS ENUM ('EMERGENCY', 'JOINT_MEETING', 'COMMUNITY_INITIATIVE', 'GENERAL');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "CrossIdirEmergencyUrgency" AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "CrossIdirEmergencyStatus" AS ENUM ('OPEN', 'ACKNOWLEDGED', 'IN_PROGRESS', 'RESOLVED', 'CLOSED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "JointFinancialCommitmentStatus" AS ENUM ('PENDING', 'AUTHORIZED', 'CONFIRMED', 'CANCELLED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 2. Create Tables
CREATE TABLE IF NOT EXISTS "CooperationAgreement" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "idirAId" TEXT NOT NULL,
  "idirBId" TEXT NOT NULL,
  "purpose" TEXT NOT NULL,
  "description" TEXT NOT NULL,
  "status" "CooperationStatus" NOT NULL DEFAULT 'PENDING',
  "proposedDuration" INTEGER,
  "startDate" TIMESTAMP(3),
  "endDate" TIMESTAMP(3),
  "endReason" TEXT,
  "createdById" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "CooperationAgreement_idirA_fkey" FOREIGN KEY ("idirAId") REFERENCES "Idir"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "CooperationAgreement_idirB_fkey" FOREIGN KEY ("idirBId") REFERENCES "Idir"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "CooperationAgreement_createdBy_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "CooperationParticipant" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "agreementId" TEXT NOT NULL,
  "idirId" TEXT NOT NULL,
  "status" "CooperationStatus" NOT NULL DEFAULT 'PENDING',
  "authorizedById" TEXT,
  "authorizedAt" TIMESTAMP(3),
  "rejectionReason" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "CooperationParticipant_agreement_fkey" FOREIGN KEY ("agreementId") REFERENCES "CooperationAgreement"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "CooperationParticipant_idir_fkey" FOREIGN KEY ("idirId") REFERENCES "Idir"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "CooperationParticipant_authorizedBy_fkey" FOREIGN KEY ("authorizedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "CooperationParticipant_unique" UNIQUE ("agreementId", "idirId")
);

CREATE TABLE IF NOT EXISTS "JointInitiative" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "agreementId" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "description" TEXT NOT NULL,
  "objectives" TEXT NOT NULL,
  "category" "JointInitiativeCategory" NOT NULL DEFAULT 'OTHER',
  "status" "JointInitiativeStatus" NOT NULL DEFAULT 'ACTIVE',
  "ownerIdirId" TEXT NOT NULL,
  "startDate" TIMESTAMP(3),
  "endDate" TIMESTAMP(3),
  "createdById" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "JointInitiative_agreement_fkey" FOREIGN KEY ("agreementId") REFERENCES "CooperationAgreement"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "JointInitiative_ownerIdir_fkey" FOREIGN KEY ("ownerIdirId") REFERENCES "Idir"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "JointInitiative_createdBy_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "InitiativeUpdate" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "initiativeId" TEXT NOT NULL,
  "content" TEXT NOT NULL,
  "createdById" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "InitiativeUpdate_initiative_fkey" FOREIGN KEY ("initiativeId") REFERENCES "JointInitiative"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "InitiativeUpdate_createdBy_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "InitiativeTask" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "initiativeId" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "description" TEXT,
  "responsibleIdirId" TEXT NOT NULL,
  "dueDate" TIMESTAMP(3),
  "isCompleted" BOOLEAN NOT NULL DEFAULT false,
  "completedAt" TIMESTAMP(3),
  "completedById" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "InitiativeTask_initiative_fkey" FOREIGN KEY ("initiativeId") REFERENCES "JointInitiative"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "InitiativeTask_responsibleIdir_fkey" FOREIGN KEY ("responsibleIdirId") REFERENCES "Idir"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "InitiativeTask_completedBy_fkey" FOREIGN KEY ("completedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "CrossIdirAnnouncement" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "agreementId" TEXT NOT NULL,
  "publisherIdirId" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "category" "CrossIdirAnnouncementCategory" NOT NULL DEFAULT 'GENERAL',
  "isWithdrawn" BOOLEAN NOT NULL DEFAULT false,
  "withdrawnAt" TIMESTAMP(3),
  "withdrawnById" TEXT,
  "createdById" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "CrossIdirAnnouncement_agreement_fkey" FOREIGN KEY ("agreementId") REFERENCES "CooperationAgreement"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "CrossIdirAnnouncement_publisherIdir_fkey" FOREIGN KEY ("publisherIdirId") REFERENCES "Idir"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "CrossIdirAnnouncement_withdrawnBy_fkey" FOREIGN KEY ("withdrawnById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "CrossIdirAnnouncement_createdBy_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "CrossIdirEmergency" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "agreementId" TEXT NOT NULL,
  "requestingIdirId" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "description" TEXT NOT NULL,
  "emergencyType" TEXT NOT NULL,
  "urgency" "CrossIdirEmergencyUrgency" NOT NULL DEFAULT 'HIGH',
  "status" "CrossIdirEmergencyStatus" NOT NULL DEFAULT 'OPEN',
  "outcomeSummary" TEXT,
  "closedAt" TIMESTAMP(3),
  "closedById" TEXT,
  "createdById" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "CrossIdirEmergency_agreement_fkey" FOREIGN KEY ("agreementId") REFERENCES "CooperationAgreement"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "CrossIdirEmergency_requestingIdir_fkey" FOREIGN KEY ("requestingIdirId") REFERENCES "Idir"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "CrossIdirEmergency_closedBy_fkey" FOREIGN KEY ("closedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "CrossIdirEmergency_createdBy_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "EmergencyResponse" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "emergencyId" TEXT NOT NULL,
  "respondingIdirId" TEXT NOT NULL,
  "message" TEXT NOT NULL,
  "commitmentNote" TEXT,
  "respondedById" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "EmergencyResponse_emergency_fkey" FOREIGN KEY ("emergencyId") REFERENCES "CrossIdirEmergency"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "EmergencyResponse_respondingIdir_fkey" FOREIGN KEY ("respondingIdirId") REFERENCES "Idir"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "EmergencyResponse_respondedBy_fkey" FOREIGN KEY ("respondedById") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "JointFinancialCommitment" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "agreementId" TEXT NOT NULL,
  "initiativeId" TEXT,
  "contributingIdirId" TEXT NOT NULL,
  "amountCommitted" DECIMAL(14,2) NOT NULL,
  "amountConfirmed" DECIMAL(14,2) NOT NULL DEFAULT 0.00,
  "currency" TEXT NOT NULL DEFAULT 'ETB',
  "purpose" TEXT NOT NULL,
  "status" "JointFinancialCommitmentStatus" NOT NULL DEFAULT 'PENDING',
  "authorizedById" TEXT,
  "authorizedAt" TIMESTAMP(3),
  "confirmedById" TEXT,
  "confirmedAt" TIMESTAMP(3),
  "reconciliationNote" TEXT,
  "expenseId" TEXT UNIQUE,
  "createdById" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "JointFinancialCommitment_agreement_fkey" FOREIGN KEY ("agreementId") REFERENCES "CooperationAgreement"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "JointFinancialCommitment_initiative_fkey" FOREIGN KEY ("initiativeId") REFERENCES "JointInitiative"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "JointFinancialCommitment_contributingIdir_fkey" FOREIGN KEY ("contributingIdirId") REFERENCES "Idir"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "JointFinancialCommitment_expense_fkey" FOREIGN KEY ("expenseId") REFERENCES "Expense"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "JointFinancialCommitment_authorizedBy_fkey" FOREIGN KEY ("authorizedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "JointFinancialCommitment_confirmedBy_fkey" FOREIGN KEY ("confirmedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "JointFinancialCommitment_createdBy_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 3. Create Indexes
CREATE INDEX IF NOT EXISTS "CooperationAgreement_idirAId_idx" ON "CooperationAgreement"("idirAId");
CREATE INDEX IF NOT EXISTS "CooperationAgreement_idirBId_idx" ON "CooperationAgreement"("idirBId");
CREATE INDEX IF NOT EXISTS "CooperationAgreement_status_idx" ON "CooperationAgreement"("status");

CREATE INDEX IF NOT EXISTS "CooperationParticipant_agreementId_idx" ON "CooperationParticipant"("agreementId");
CREATE INDEX IF NOT EXISTS "CooperationParticipant_idirId_idx" ON "CooperationParticipant"("idirId");
CREATE INDEX IF NOT EXISTS "CooperationParticipant_status_idx" ON "CooperationParticipant"("status");

CREATE INDEX IF NOT EXISTS "JointInitiative_agreementId_idx" ON "JointInitiative"("agreementId");
CREATE INDEX IF NOT EXISTS "JointInitiative_ownerIdirId_idx" ON "JointInitiative"("ownerIdirId");
CREATE INDEX IF NOT EXISTS "JointInitiative_status_idx" ON "JointInitiative"("status");

CREATE INDEX IF NOT EXISTS "InitiativeUpdate_initiativeId_idx" ON "InitiativeUpdate"("initiativeId");
CREATE INDEX IF NOT EXISTS "InitiativeTask_initiativeId_idx" ON "InitiativeTask"("initiativeId");
CREATE INDEX IF NOT EXISTS "InitiativeTask_responsibleIdirId_idx" ON "InitiativeTask"("responsibleIdirId");

CREATE INDEX IF NOT EXISTS "CrossIdirAnnouncement_agreementId_idx" ON "CrossIdirAnnouncement"("agreementId");
CREATE INDEX IF NOT EXISTS "CrossIdirAnnouncement_publisherIdirId_idx" ON "CrossIdirAnnouncement"("publisherIdirId");

CREATE INDEX IF NOT EXISTS "CrossIdirEmergency_agreementId_idx" ON "CrossIdirEmergency"("agreementId");
CREATE INDEX IF NOT EXISTS "CrossIdirEmergency_requestingIdirId_idx" ON "CrossIdirEmergency"("requestingIdirId");
CREATE INDEX IF NOT EXISTS "CrossIdirEmergency_status_idx" ON "CrossIdirEmergency"("status");

CREATE INDEX IF NOT EXISTS "EmergencyResponse_emergencyId_idx" ON "EmergencyResponse"("emergencyId");
CREATE INDEX IF NOT EXISTS "EmergencyResponse_respondingIdirId_idx" ON "EmergencyResponse"("respondingIdirId");

CREATE INDEX IF NOT EXISTS "JointFinancialCommitment_agreementId_idx" ON "JointFinancialCommitment"("agreementId");
CREATE INDEX IF NOT EXISTS "JointFinancialCommitment_contributingIdirId_idx" ON "JointFinancialCommitment"("contributingIdirId");

