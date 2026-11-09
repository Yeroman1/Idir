-- ============================================================================
-- IDIR CONNECT: NOTIFICATIONS, PREFERENCES & REMINDERS SCHEMA MIGRATION
-- ============================================================================
-- Feature: Reliable In-App Notifications, Contribution & Meeting Reminders,
--          Multi-Channel Delivery, Device Tokens, and User Notification Preferences
-- ============================================================================

BEGIN;

-- 1. Safely add new NotificationType enum values if PostgreSQL enum exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'NotificationType') THEN
        ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'MEMBERSHIP_UPDATE';
        ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'INVITATION';
        ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'IDIR_STATUS';
        ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'GOVERNANCE';
        ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'FINANCIAL_REPORT';
        ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'URGENT_ALERT';
    END IF;
END$$;

-- 2. Create NotificationChannel and DeliveryStatus enums if they do not exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'NotificationChannel') THEN
        CREATE TYPE "NotificationChannel" AS ENUM ('IN_APP', 'PUSH', 'SMS', 'EMAIL');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'DeliveryStatus') THEN
        CREATE TYPE "DeliveryStatus" AS ENUM ('PENDING', 'SENT', 'FAILED', 'SKIPPED');
    END IF;
END$$;

-- 3. Enhance Notification table
ALTER TABLE "Notification" ADD COLUMN IF NOT EXISTS "idempotencyKey" TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS "Notification_idempotencyKey_key" ON "Notification"("idempotencyKey");
CREATE INDEX IF NOT EXISTS "Notification_userId_createdAt_idx" ON "Notification"("userId", "createdAt" DESC);
CREATE INDEX IF NOT EXISTS "Notification_userId_readAt_idx" ON "Notification"("userId", "readAt");

-- 4. Create NotificationPreference table
CREATE TABLE IF NOT EXISTS "NotificationPreference" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "inAppEnabled" BOOLEAN NOT NULL DEFAULT TRUE,
    "pushEnabled" BOOLEAN NOT NULL DEFAULT TRUE,
    "smsEnabled" BOOLEAN NOT NULL DEFAULT TRUE,
    "emailEnabled" BOOLEAN NOT NULL DEFAULT TRUE,
    "reminderMeetings" BOOLEAN NOT NULL DEFAULT TRUE,
    "reminderContributions" BOOLEAN NOT NULL DEFAULT TRUE,
    "notifyAnnouncements" BOOLEAN NOT NULL DEFAULT TRUE,
    "notifyGovernance" BOOLEAN NOT NULL DEFAULT TRUE,
    "notifyAssistance" BOOLEAN NOT NULL DEFAULT TRUE,
    "quietHoursEnabled" BOOLEAN NOT NULL DEFAULT FALSE,
    "quietHoursStart" TEXT,
    "quietHoursEnd" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "NotificationPreference_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "NotificationPreference_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "NotificationPreference_userId_key" ON "NotificationPreference"("userId");
CREATE INDEX IF NOT EXISTS "NotificationPreference_userId_idx" ON "NotificationPreference"("userId");

-- 5. Create DeviceToken table for Push Notifications
CREATE TABLE IF NOT EXISTS "DeviceToken" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "platform" TEXT NOT NULL DEFAULT 'android',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DeviceToken_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "DeviceToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "DeviceToken_token_key" ON "DeviceToken"("token");
CREATE INDEX IF NOT EXISTS "DeviceToken_userId_idx" ON "DeviceToken"("userId");

-- 6. Create NotificationDelivery table
CREATE TABLE IF NOT EXISTS "NotificationDelivery" (
    "id" TEXT NOT NULL,
    "notificationId" TEXT NOT NULL,
    "channel" "NotificationChannel" NOT NULL,
    "status" "DeliveryStatus" NOT NULL DEFAULT 'PENDING',
    "recipient" TEXT NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "lastAttemptAt" TIMESTAMP(3),
    "error" TEXT,
    "idempotencyKey" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "NotificationDelivery_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "NotificationDelivery_notificationId_fkey" FOREIGN KEY ("notificationId") REFERENCES "Notification"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "NotificationDelivery_idempotencyKey_key" ON "NotificationDelivery"("idempotencyKey");
CREATE INDEX IF NOT EXISTS "NotificationDelivery_notificationId_idx" ON "NotificationDelivery"("notificationId");
CREATE INDEX IF NOT EXISTS "NotificationDelivery_status_idx" ON "NotificationDelivery"("status");

-- 7. Configure Row-Level Security (RLS) policies
ALTER TABLE "NotificationPreference" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "DeviceToken" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "NotificationDelivery" ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Users can read own notification preferences" ON "NotificationPreference";
    CREATE POLICY "Users can read own notification preferences"
        ON "NotificationPreference" FOR SELECT
        USING (auth.uid()::text = "userId");

    DROP POLICY IF EXISTS "Users can update own notification preferences" ON "NotificationPreference";
    CREATE POLICY "Users can update own notification preferences"
        ON "NotificationPreference" FOR ALL
        USING (auth.uid()::text = "userId");

    DROP POLICY IF EXISTS "Users can manage own device tokens" ON "DeviceToken";
    CREATE POLICY "Users can manage own device tokens"
        ON "DeviceToken" FOR ALL
        USING (auth.uid()::text = "userId");
END$$;

COMMIT;
