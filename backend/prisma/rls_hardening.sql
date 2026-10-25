-- ============================================================================
-- IDIR CONNECT: SUPABASE POSTGRESQL ROW LEVEL SECURITY (RLS) HARDENING SCRIPT
-- ============================================================================
-- OWASP Top 10 Category 1: Broken Access Control & Category 5: Security Misconfigurations
--
-- This script hardens all database tables against unauthorized access via
-- Supabase PostgREST endpoints (anon key / client direct access).
--
-- Architecture Notes:
-- 1. The Express backend connects via direct connection / pooler as "postgres"
--    (superuser / service_role) and enforces institutional business rules.
-- 2. Direct client PostgREST access via the anon key is restricted to deny-by-default,
--    preventing unauthorized extraction of member data, contributions, or ledgers.
-- ============================================================================

BEGIN;

-- 1. Enable Row Level Security (RLS) on all public tables
ALTER TABLE IF EXISTS "User" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "RefreshToken" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "Idir" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "IdirSettings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "Membership" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "ContributionType" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "Contribution" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "Expense" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "AssistanceCase" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "AssistanceRequest" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "AssistanceDisbursement" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "IkubGroup" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "IkubParticipant" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "IkubRound" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "IkubContribution" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "IkubPayout" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "Meeting" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "MeetingAttendance" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "Announcement" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "Notification" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "AuditLog" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "Invitation" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "Election" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "Candidate" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "Vote" ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS "Nomination" ENABLE ROW LEVEL SECURITY;

-- 2. Drop existing permissive or duplicate policies
DROP POLICY IF EXISTS "Service role full access on User" ON "User";
DROP POLICY IF EXISTS "Users can read own profile" ON "User";
DROP POLICY IF EXISTS "Users can update own profile" ON "User";
DROP POLICY IF EXISTS "Deny anon access on RefreshToken" ON "RefreshToken";
DROP POLICY IF EXISTS "Deny anon access on Contribution" ON "Contribution";
DROP POLICY IF EXISTS "Deny anon access on Expense" ON "Expense";
DROP POLICY IF EXISTS "Deny anon access on AuditLog" ON "AuditLog";

-- 3. Policy: Service Role Full Access (Ensures Backend API operation is uninterrupted)
CREATE POLICY "Service role has full access on User" ON "User"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on RefreshToken" ON "RefreshToken"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on Idir" ON "Idir"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on IdirSettings" ON "IdirSettings"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on Membership" ON "Membership"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on ContributionType" ON "ContributionType"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on Contribution" ON "Contribution"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on Expense" ON "Expense"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on AssistanceCase" ON "AssistanceCase"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on AssistanceRequest" ON "AssistanceRequest"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on AssistanceDisbursement" ON "AssistanceDisbursement"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on IkubGroup" ON "IkubGroup"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on IkubParticipant" ON "IkubParticipant"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on IkubRound" ON "IkubRound"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on IkubContribution" ON "IkubContribution"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on IkubPayout" ON "IkubPayout"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on Meeting" ON "Meeting"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on MeetingAttendance" ON "MeetingAttendance"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on Announcement" ON "Announcement"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on Notification" ON "Notification"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on AuditLog" ON "AuditLog"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on Invitation" ON "Invitation"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on Election" ON "Election"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on Candidate" ON "Candidate"
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access on Vote" ON "Vote"
  FOR ALL USING (auth.role() = 'service_role');

-- 4. User Self-Access (Authenticated GoTrue Users can only view and update their own User record)
CREATE POLICY "Authenticated users can read own User record" ON "User"
  FOR SELECT USING (auth.uid()::text = id);

CREATE POLICY "Authenticated users can update own User record" ON "User"
  FOR UPDATE USING (auth.uid()::text = id)
  WITH CHECK (auth.uid()::text = id);

-- 5. Revoke direct anon write grants on all public tables (fail-closed defense)
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM anon;

COMMIT;
