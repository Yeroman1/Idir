-- CreateEnum
CREATE TYPE "ElectionStatus" AS ENUM ('DRAFT', 'NOMINATING', 'VOTING', 'TALLYING', 'DISPUTED', 'COMPLETED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "VotingMethod" AS ENUM ('SIMPLE_MAJORITY', 'RUNOFF');

-- CreateEnum
CREATE TYPE "BallotType" AS ENUM ('SECRET', 'OPEN');

-- CreateEnum
CREATE TYPE "NominationStatus" AS ENUM ('PENDING', 'ACCEPTED', 'DECLINED', 'WITHDRAWN');

-- CreateEnum
CREATE TYPE "DisputeStatus" AS ENUM ('PENDING', 'RESOLVED', 'DISMISSED');

-- CreateEnum
CREATE TYPE "NoConfidenceStatus" AS ENUM ('ACTIVE', 'PASSED', 'FAILED', 'FAILED_NO_QUORUM', 'CANCELLED');

-- CreateEnum
CREATE TYPE "NoConfidenceChoice" AS ENUM ('SUPPORT', 'OPPOSE');

-- DropIndex
DROP INDEX "User_faydaId_key";

-- DropIndex
DROP INDEX "User_faydaId_idx";

-- DropIndex
DROP INDEX "IkubPayout_roundId_key";

-- DropIndex
DROP INDEX "Invitation_idirId_phoneNumber_key";

-- AlterTable
ALTER TABLE "User" DROP COLUMN "faydaId",
ADD COLUMN     "address" TEXT,
ADD COLUMN     "dateOfBirth" TIMESTAMP(3),
ADD COLUMN     "firstName" TEXT,
ADD COLUMN     "lastName" TEXT,
ADD COLUMN     "middleName" TEXT;

-- AlterTable
ALTER TABLE "IkubGroup" ADD COLUMN     "drawMode" TEXT NOT NULL DEFAULT 'DIGITAL_LOTTERY',
ADD COLUMN     "winnersPerRound" INTEGER NOT NULL DEFAULT 1;

-- AlterTable
ALTER TABLE "IkubRound" ADD COLUMN     "drawSeed" TEXT,
ADD COLUMN     "drawnAt" TIMESTAMP(3),
ADD COLUMN     "drawnById" TEXT;

-- AlterTable
ALTER TABLE "Invitation" ADD COLUMN     "email" TEXT,
ALTER COLUMN "phoneNumber" DROP NOT NULL;

-- CreateTable
CREATE TABLE "IkubJoinRequest" (
    "id" TEXT NOT NULL,
    "ikubGroupId" TEXT NOT NULL,
    "membershipId" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "note" TEXT,
    "requestedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "reviewedById" TEXT,
    "reviewedAt" TIMESTAMP(3),

    CONSTRAINT "IkubJoinRequest_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Election" (
    "id" TEXT NOT NULL,
    "idirId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "roles" "MembershipRole"[],
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3) NOT NULL,
    "nominationStartDate" TIMESTAMP(3),
    "nominationEndDate" TIMESTAMP(3),
    "termLengthMonths" INTEGER NOT NULL DEFAULT 12,
    "votingMethod" "VotingMethod" NOT NULL DEFAULT 'SIMPLE_MAJORITY',
    "ballotType" "BallotType" NOT NULL DEFAULT 'SECRET',
    "quorumPercentage" DECIMAL(5,2) NOT NULL DEFAULT 50.00,
    "minMembershipTenureDays" INTEGER NOT NULL DEFAULT 0,
    "requiresGoodStanding" BOOLEAN NOT NULL DEFAULT true,
    "status" "ElectionStatus" NOT NULL DEFAULT 'DRAFT',
    "disputeWindowHours" INTEGER NOT NULL DEFAULT 48,
    "handoverDate" TIMESTAMP(3),
    "createdById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Election_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ElectionCommitteeMember" (
    "id" TEXT NOT NULL,
    "electionId" TEXT NOT NULL,
    "membershipId" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'COMMITTEE_MEMBER',
    "assignedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ElectionCommitteeMember_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ElectionNomination" (
    "id" TEXT NOT NULL,
    "electionId" TEXT NOT NULL,
    "role" "MembershipRole" NOT NULL,
    "nomineeMembershipId" TEXT NOT NULL,
    "nominatedByMembershipId" TEXT,
    "statement" TEXT,
    "status" "NominationStatus" NOT NULL DEFAULT 'PENDING',
    "acceptedAt" TIMESTAMP(3),
    "declinedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ElectionNomination_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VoteReceipt" (
    "id" TEXT NOT NULL,
    "electionId" TEXT NOT NULL,
    "membershipId" TEXT NOT NULL,
    "role" "MembershipRole" NOT NULL,
    "votedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "receiptTokenHash" TEXT,

    CONSTRAINT "VoteReceipt_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Ballot" (
    "id" TEXT NOT NULL,
    "electionId" TEXT NOT NULL,
    "role" "MembershipRole" NOT NULL,
    "candidateNominationId" TEXT,
    "voterMembershipId" TEXT,
    "castAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Ballot_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ElectionResult" (
    "id" TEXT NOT NULL,
    "electionId" TEXT NOT NULL,
    "role" "MembershipRole" NOT NULL,
    "winnerNominationId" TEXT,
    "totalVotesCast" INTEGER NOT NULL DEFAULT 0,
    "votesReceived" INTEGER NOT NULL DEFAULT 0,
    "quorumReached" BOOLEAN NOT NULL DEFAULT false,
    "isFinal" BOOLEAN NOT NULL DEFAULT false,
    "disputeWindowEndsAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ElectionResult_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ElectionDispute" (
    "id" TEXT NOT NULL,
    "electionId" TEXT NOT NULL,
    "filedByMembershipId" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "status" "DisputeStatus" NOT NULL DEFAULT 'PENDING',
    "resolution" TEXT,
    "resolvedAt" TIMESTAMP(3),
    "resolvedById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ElectionDispute_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RoleTerm" (
    "id" TEXT NOT NULL,
    "idirId" TEXT NOT NULL,
    "membershipId" TEXT NOT NULL,
    "role" "MembershipRole" NOT NULL,
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3) NOT NULL,
    "electionId" TEXT,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RoleTerm_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NoConfidenceVote" (
    "id" TEXT NOT NULL,
    "idirId" TEXT NOT NULL,
    "targetMembershipId" TEXT NOT NULL,
    "targetRole" "MembershipRole" NOT NULL,
    "initiatedByMembershipId" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "thresholdPercentage" DECIMAL(5,2) NOT NULL DEFAULT 66.67,
    "quorumPercentage" DECIMAL(5,2) NOT NULL DEFAULT 50.00,
    "startDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endDate" TIMESTAMP(3) NOT NULL,
    "status" "NoConfidenceStatus" NOT NULL DEFAULT 'ACTIVE',
    "totalEligibleMembers" INTEGER NOT NULL DEFAULT 0,
    "totalVotesCast" INTEGER NOT NULL DEFAULT 0,
    "supportVotes" INTEGER NOT NULL DEFAULT 0,
    "opposeVotes" INTEGER NOT NULL DEFAULT 0,
    "resolvedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "NoConfidenceVote_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NoConfidenceBallot" (
    "id" TEXT NOT NULL,
    "voteId" TEXT NOT NULL,
    "voterMembershipId" TEXT NOT NULL,
    "choice" "NoConfidenceChoice" NOT NULL,
    "castAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "NoConfidenceBallot_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ChatMessage" (
    "id" TEXT NOT NULL,
    "idirId" TEXT NOT NULL,
    "membershipId" TEXT NOT NULL,
    "senderId" TEXT NOT NULL,
    "senderName" TEXT NOT NULL,
    "senderRole" TEXT NOT NULL DEFAULT 'MEMBER',
    "messageType" TEXT NOT NULL DEFAULT 'TEXT',
    "content" TEXT NOT NULL,
    "isEdited" BOOLEAN NOT NULL DEFAULT false,
    "replyToId" TEXT,
    "replyToSenderName" TEXT,
    "replyToContent" TEXT,
    "isForwarded" BOOLEAN NOT NULL DEFAULT false,
    "forwardedFromName" TEXT,
    "isPinned" BOOLEAN NOT NULL DEFAULT false,
    "pinnedAt" TIMESTAMP(3),
    "pinnedById" TEXT,
    "attachmentUrl" TEXT,
    "attachmentType" TEXT,
    "attachmentName" TEXT,
    "attachmentSize" INTEGER,
    "attachmentDuration" INTEGER,
    "reactions" JSONB,
    "mentions" JSONB,
    "clientMutationId" TEXT,
    "isDeleted" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ChatMessage_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "IkubJoinRequest_ikubGroupId_idx" ON "IkubJoinRequest"("ikubGroupId");

-- CreateIndex
CREATE INDEX "IkubJoinRequest_membershipId_idx" ON "IkubJoinRequest"("membershipId");

-- CreateIndex
CREATE INDEX "IkubJoinRequest_status_idx" ON "IkubJoinRequest"("status");

-- CreateIndex
CREATE UNIQUE INDEX "IkubJoinRequest_ikubGroupId_membershipId_key" ON "IkubJoinRequest"("ikubGroupId", "membershipId");

-- CreateIndex
CREATE INDEX "Election_idirId_idx" ON "Election"("idirId");

-- CreateIndex
CREATE INDEX "Election_status_idx" ON "Election"("status");

-- CreateIndex
CREATE INDEX "Election_startDate_endDate_idx" ON "Election"("startDate", "endDate");

-- CreateIndex
CREATE INDEX "ElectionCommitteeMember_electionId_idx" ON "ElectionCommitteeMember"("electionId");

-- CreateIndex
CREATE INDEX "ElectionCommitteeMember_membershipId_idx" ON "ElectionCommitteeMember"("membershipId");

-- CreateIndex
CREATE UNIQUE INDEX "ElectionCommitteeMember_electionId_membershipId_key" ON "ElectionCommitteeMember"("electionId", "membershipId");

-- CreateIndex
CREATE INDEX "ElectionNomination_electionId_status_idx" ON "ElectionNomination"("electionId", "status");

-- CreateIndex
CREATE INDEX "ElectionNomination_nomineeMembershipId_idx" ON "ElectionNomination"("nomineeMembershipId");

-- CreateIndex
CREATE UNIQUE INDEX "ElectionNomination_electionId_role_nomineeMembershipId_key" ON "ElectionNomination"("electionId", "role", "nomineeMembershipId");

-- CreateIndex
CREATE INDEX "VoteReceipt_electionId_idx" ON "VoteReceipt"("electionId");

-- CreateIndex
CREATE INDEX "VoteReceipt_membershipId_idx" ON "VoteReceipt"("membershipId");

-- CreateIndex
CREATE UNIQUE INDEX "VoteReceipt_electionId_role_membershipId_key" ON "VoteReceipt"("electionId", "role", "membershipId");

-- CreateIndex
CREATE INDEX "Ballot_electionId_idx" ON "Ballot"("electionId");

-- CreateIndex
CREATE INDEX "Ballot_candidateNominationId_idx" ON "Ballot"("candidateNominationId");

-- CreateIndex
CREATE INDEX "ElectionResult_electionId_idx" ON "ElectionResult"("electionId");

-- CreateIndex
CREATE UNIQUE INDEX "ElectionResult_electionId_role_key" ON "ElectionResult"("electionId", "role");

-- CreateIndex
CREATE INDEX "ElectionDispute_electionId_idx" ON "ElectionDispute"("electionId");

-- CreateIndex
CREATE INDEX "ElectionDispute_filedByMembershipId_idx" ON "ElectionDispute"("filedByMembershipId");

-- CreateIndex
CREATE INDEX "RoleTerm_idirId_idx" ON "RoleTerm"("idirId");

-- CreateIndex
CREATE INDEX "RoleTerm_membershipId_idx" ON "RoleTerm"("membershipId");

-- CreateIndex
CREATE INDEX "NoConfidenceVote_idirId_idx" ON "NoConfidenceVote"("idirId");

-- CreateIndex
CREATE INDEX "NoConfidenceVote_targetMembershipId_idx" ON "NoConfidenceVote"("targetMembershipId");

-- CreateIndex
CREATE INDEX "NoConfidenceVote_status_idx" ON "NoConfidenceVote"("status");

-- CreateIndex
CREATE INDEX "NoConfidenceBallot_voteId_idx" ON "NoConfidenceBallot"("voteId");

-- CreateIndex
CREATE INDEX "NoConfidenceBallot_voterMembershipId_idx" ON "NoConfidenceBallot"("voterMembershipId");

-- CreateIndex
CREATE UNIQUE INDEX "NoConfidenceBallot_voteId_voterMembershipId_key" ON "NoConfidenceBallot"("voteId", "voterMembershipId");

-- CreateIndex
CREATE INDEX "ChatMessage_idirId_createdAt_idx" ON "ChatMessage"("idirId", "createdAt");

-- CreateIndex
CREATE INDEX "ChatMessage_idirId_isPinned_idx" ON "ChatMessage"("idirId", "isPinned");

-- CreateIndex
CREATE INDEX "ChatMessage_senderId_idx" ON "ChatMessage"("senderId");

-- CreateIndex
CREATE INDEX "ChatMessage_membershipId_idx" ON "ChatMessage"("membershipId");

-- CreateIndex
CREATE INDEX "ChatMessage_clientMutationId_idx" ON "ChatMessage"("clientMutationId");

-- CreateIndex
CREATE UNIQUE INDEX "IkubPayout_roundId_recipientParticipantId_key" ON "IkubPayout"("roundId", "recipientParticipantId");

-- CreateIndex
CREATE INDEX "Invitation_idirId_phoneNumber_idx" ON "Invitation"("idirId", "phoneNumber");

-- CreateIndex
CREATE INDEX "Invitation_idirId_email_idx" ON "Invitation"("idirId", "email");

-- AddForeignKey
ALTER TABLE "IkubJoinRequest" ADD CONSTRAINT "IkubJoinRequest_ikubGroupId_fkey" FOREIGN KEY ("ikubGroupId") REFERENCES "IkubGroup"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "IkubJoinRequest" ADD CONSTRAINT "IkubJoinRequest_membershipId_fkey" FOREIGN KEY ("membershipId") REFERENCES "Membership"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Election" ADD CONSTRAINT "Election_idirId_fkey" FOREIGN KEY ("idirId") REFERENCES "Idir"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Election" ADD CONSTRAINT "Election_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ElectionCommitteeMember" ADD CONSTRAINT "ElectionCommitteeMember_electionId_fkey" FOREIGN KEY ("electionId") REFERENCES "Election"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ElectionCommitteeMember" ADD CONSTRAINT "ElectionCommitteeMember_membershipId_fkey" FOREIGN KEY ("membershipId") REFERENCES "Membership"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ElectionNomination" ADD CONSTRAINT "ElectionNomination_electionId_fkey" FOREIGN KEY ("electionId") REFERENCES "Election"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ElectionNomination" ADD CONSTRAINT "ElectionNomination_nomineeMembershipId_fkey" FOREIGN KEY ("nomineeMembershipId") REFERENCES "Membership"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ElectionNomination" ADD CONSTRAINT "ElectionNomination_nominatedByMembershipId_fkey" FOREIGN KEY ("nominatedByMembershipId") REFERENCES "Membership"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VoteReceipt" ADD CONSTRAINT "VoteReceipt_electionId_fkey" FOREIGN KEY ("electionId") REFERENCES "Election"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VoteReceipt" ADD CONSTRAINT "VoteReceipt_membershipId_fkey" FOREIGN KEY ("membershipId") REFERENCES "Membership"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Ballot" ADD CONSTRAINT "Ballot_electionId_fkey" FOREIGN KEY ("electionId") REFERENCES "Election"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Ballot" ADD CONSTRAINT "Ballot_candidateNominationId_fkey" FOREIGN KEY ("candidateNominationId") REFERENCES "ElectionNomination"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Ballot" ADD CONSTRAINT "Ballot_voterMembershipId_fkey" FOREIGN KEY ("voterMembershipId") REFERENCES "Membership"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ElectionResult" ADD CONSTRAINT "ElectionResult_electionId_fkey" FOREIGN KEY ("electionId") REFERENCES "Election"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ElectionResult" ADD CONSTRAINT "ElectionResult_winnerNominationId_fkey" FOREIGN KEY ("winnerNominationId") REFERENCES "ElectionNomination"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ElectionDispute" ADD CONSTRAINT "ElectionDispute_electionId_fkey" FOREIGN KEY ("electionId") REFERENCES "Election"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ElectionDispute" ADD CONSTRAINT "ElectionDispute_filedByMembershipId_fkey" FOREIGN KEY ("filedByMembershipId") REFERENCES "Membership"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RoleTerm" ADD CONSTRAINT "RoleTerm_idirId_fkey" FOREIGN KEY ("idirId") REFERENCES "Idir"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RoleTerm" ADD CONSTRAINT "RoleTerm_membershipId_fkey" FOREIGN KEY ("membershipId") REFERENCES "Membership"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NoConfidenceVote" ADD CONSTRAINT "NoConfidenceVote_idirId_fkey" FOREIGN KEY ("idirId") REFERENCES "Idir"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NoConfidenceVote" ADD CONSTRAINT "NoConfidenceVote_targetMembershipId_fkey" FOREIGN KEY ("targetMembershipId") REFERENCES "Membership"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NoConfidenceVote" ADD CONSTRAINT "NoConfidenceVote_initiatedByMembershipId_fkey" FOREIGN KEY ("initiatedByMembershipId") REFERENCES "Membership"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NoConfidenceBallot" ADD CONSTRAINT "NoConfidenceBallot_voteId_fkey" FOREIGN KEY ("voteId") REFERENCES "NoConfidenceVote"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NoConfidenceBallot" ADD CONSTRAINT "NoConfidenceBallot_voterMembershipId_fkey" FOREIGN KEY ("voterMembershipId") REFERENCES "Membership"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ChatMessage" ADD CONSTRAINT "ChatMessage_idirId_fkey" FOREIGN KEY ("idirId") REFERENCES "Idir"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ChatMessage" ADD CONSTRAINT "ChatMessage_membershipId_fkey" FOREIGN KEY ("membershipId") REFERENCES "Membership"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ChatMessage" ADD CONSTRAINT "ChatMessage_senderId_fkey" FOREIGN KEY ("senderId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

