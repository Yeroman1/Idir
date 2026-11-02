-- ============================================================================
-- IDIR CONNECT: REAL-TIME GROUP CHAT SCHEMA & ROW LEVEL SECURITY (RLS)
-- ============================================================================
-- Feature: Telegram/WhatsApp-grade Real-Time Group Chat for Idir Connect
-- Security: Restrict chat access strictly to verified, active Idir members
-- Realtime: Supabase Realtime logical replication publication
-- ============================================================================

BEGIN;

-- 1. Create ChatMessage table if it doesn't already exist
CREATE TABLE IF NOT EXISTS "ChatMessage" (
    "id" TEXT NOT NULL,
    "idirId" TEXT NOT NULL,
    "membershipId" TEXT NOT NULL,
    "senderId" TEXT NOT NULL,
    "senderName" TEXT NOT NULL,
    "senderRole" TEXT NOT NULL DEFAULT 'MEMBER',
    "messageType" TEXT NOT NULL DEFAULT 'TEXT',
    "content" TEXT NOT NULL,
    "isEdited" BOOLEAN NOT NULL DEFAULT FALSE,
    "replyToId" TEXT,
    "replyToSenderName" TEXT,
    "replyToContent" TEXT,
    "isForwarded" BOOLEAN NOT NULL DEFAULT FALSE,
    "forwardedFromName" TEXT,
    "isPinned" BOOLEAN NOT NULL DEFAULT FALSE,
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
    "isDeleted" BOOLEAN NOT NULL DEFAULT FALSE,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ChatMessage_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "ChatMessage_idirId_fkey" FOREIGN KEY ("idirId") REFERENCES "Idir"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "ChatMessage_membershipId_fkey" FOREIGN KEY ("membershipId") REFERENCES "Membership"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "ChatMessage_senderId_fkey" FOREIGN KEY ("senderId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- Safely add columns if ChatMessage table already existed from earlier schema
ALTER TABLE "ChatMessage" ADD COLUMN IF NOT EXISTS "messageType" TEXT NOT NULL DEFAULT 'TEXT';
ALTER TABLE "ChatMessage" ADD COLUMN IF NOT EXISTS "replyToId" TEXT;
ALTER TABLE "ChatMessage" ADD COLUMN IF NOT EXISTS "replyToSenderName" TEXT;
ALTER TABLE "ChatMessage" ADD COLUMN IF NOT EXISTS "replyToContent" TEXT;
ALTER TABLE "ChatMessage" ADD COLUMN IF NOT EXISTS "isForwarded" BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE "ChatMessage" ADD COLUMN IF NOT EXISTS "forwardedFromName" TEXT;
ALTER TABLE "ChatMessage" ADD COLUMN IF NOT EXISTS "isPinned" BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE "ChatMessage" ADD COLUMN IF NOT EXISTS "pinnedAt" TIMESTAMP(3);
ALTER TABLE "ChatMessage" ADD COLUMN IF NOT EXISTS "pinnedById" TEXT;
ALTER TABLE "ChatMessage" ADD COLUMN IF NOT EXISTS "attachmentUrl" TEXT;
ALTER TABLE "ChatMessage" ADD COLUMN IF NOT EXISTS "attachmentType" TEXT;
ALTER TABLE "ChatMessage" ADD COLUMN IF NOT EXISTS "attachmentName" TEXT;
ALTER TABLE "ChatMessage" ADD COLUMN IF NOT EXISTS "attachmentSize" INTEGER;
ALTER TABLE "ChatMessage" ADD COLUMN IF NOT EXISTS "attachmentDuration" INTEGER;
ALTER TABLE "ChatMessage" ADD COLUMN IF NOT EXISTS "reactions" JSONB;
ALTER TABLE "ChatMessage" ADD COLUMN IF NOT EXISTS "mentions" JSONB;
ALTER TABLE "ChatMessage" ADD COLUMN IF NOT EXISTS "clientMutationId" TEXT;
ALTER TABLE "ChatMessage" ADD COLUMN IF NOT EXISTS "isDeleted" BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Indexes for fast retrieval by Idir sorted by timestamp and pinned status
CREATE INDEX IF NOT EXISTS "ChatMessage_idirId_createdAt_idx" ON "ChatMessage"("idirId", "createdAt" ASC);
CREATE INDEX IF NOT EXISTS "ChatMessage_idirId_isPinned_idx" ON "ChatMessage"("idirId", "isPinned");
CREATE INDEX IF NOT EXISTS "ChatMessage_senderId_idx" ON "ChatMessage"("senderId");
CREATE INDEX IF NOT EXISTS "ChatMessage_membershipId_idx" ON "ChatMessage"("membershipId");
CREATE INDEX IF NOT EXISTS "ChatMessage_clientMutationId_idx" ON "ChatMessage"("clientMutationId");

-- 3. Enable Full Replica Identity so Supabase Realtime emits full record changes
ALTER TABLE "ChatMessage" REPLICA IDENTITY FULL;

-- 4. Enable Supabase Realtime Publication
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'ChatMessage'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE "ChatMessage";
  END IF;
EXCEPTION
  WHEN undefined_object THEN
    NULL; -- In local standalone postgres where publication doesn't exist
END $$;

-- 5. Enable Row Level Security (RLS)
ALTER TABLE "ChatMessage" ENABLE ROW LEVEL SECURITY;

-- 6. Clean up existing chat policies if any
DROP POLICY IF EXISTS "Service role full access on ChatMessage" ON "ChatMessage";
DROP POLICY IF EXISTS "Active Idir members can read chat messages" ON "ChatMessage";
DROP POLICY IF EXISTS "Active Idir members can insert chat messages" ON "ChatMessage";
DROP POLICY IF EXISTS "Active members or admins can update chat messages" ON "ChatMessage";

-- 7. Policy: Service Role Full Access (Backend API operations)
CREATE POLICY "Service role full access on ChatMessage" ON "ChatMessage"
  FOR ALL USING (auth.role() = 'service_role');

-- 8. Policy: Only active members of this specific Idir can read non-deleted messages
CREATE POLICY "Active Idir members can read chat messages" ON "ChatMessage"
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM "Membership" m
      WHERE m."idirId" = "ChatMessage"."idirId"
        AND m."userId" = auth.uid()::text
        AND m."status" = 'ACTIVE'
    )
  );

-- 9. Policy: Only active members can post messages as themselves
CREATE POLICY "Active Idir members can insert chat messages" ON "ChatMessage"
  FOR INSERT WITH CHECK (
    auth.uid()::text = "senderId"
    AND EXISTS (
      SELECT 1 FROM "Membership" m
      WHERE m."idirId" = "ChatMessage"."idirId"
        AND m."userId" = auth.uid()::text
        AND m."id" = "ChatMessage"."membershipId"
        AND m."status" = 'ACTIVE'
    )
  );

COMMIT;
