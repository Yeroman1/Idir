import { PrismaClient, Prisma } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting database seeding for Idir Connect...');

  const passwordHash = await bcrypt.hash('Password123!', 10);

  // 1. Create Platform Admin
  const adminUser = await prisma.user.upsert({
    where: { phoneNumber: '+251911000000' },
    update: {},
    create: {
      fullName: 'System Administrator',
      phoneNumber: '+251911000000',
      email: 'admin@idirconnect.et',
      passwordHash,
      preferredLanguage: 'en',
      status: 'ACTIVE',
      isPlatformAdmin: true,
    },
  });

  // 2. Create Realistic Community Users
  const chairpersonUser = await prisma.user.upsert({
    where: { phoneNumber: '+251911111111' },
    update: {},
    create: {
      fullName: 'Abebe Tadesse Kebede',
      phoneNumber: '+251911111111',
      email: 'abebe.tadesse@example.com',
      passwordHash,
      preferredLanguage: 'am',
      faydaId: '100020003001',
      status: 'ACTIVE',
    },
  });

  const treasurerUser = await prisma.user.upsert({
    where: { phoneNumber: '+251911222222' },
    update: {},
    create: {
      fullName: 'Chaltu Bekele Gemeda',
      phoneNumber: '+251911222222',
      email: 'chaltu.bekele@example.com',
      passwordHash,
      preferredLanguage: 'om',
      faydaId: '100020003002',
      status: 'ACTIVE',
    },
  });

  const secretaryUser = await prisma.user.upsert({
    where: { phoneNumber: '+251911333333' },
    update: {
      fullName: 'Dawit Abdi Hailu',
      email: 'dawit.abdi@example.com',
    },
    create: {
      fullName: 'Dawit Abdi Hailu',
      phoneNumber: '+251911333333',
      email: 'dawit.abdi@example.com',
      passwordHash,
      preferredLanguage: 'am',
      faydaId: '100020003003',
      status: 'ACTIVE',
    },
  });

  const committeeUser = await prisma.user.upsert({
    where: { phoneNumber: '+251911444444' },
    update: {},
    create: {
      fullName: 'Fatima Mohammed Ali',
      phoneNumber: '+251911444444',
      email: 'fatima.mohammed@example.com',
      passwordHash,
      preferredLanguage: 'am',
      faydaId: '100020003004',
      status: 'ACTIVE',
    },
  });

  const memberUser1 = await prisma.user.upsert({
    where: { phoneNumber: '+251911555555' },
    update: {},
    create: {
      fullName: 'Alemayehu Hailemariam',
      phoneNumber: '+251911555555',
      email: 'alemayehu@example.com',
      passwordHash,
      preferredLanguage: 'am',
      status: 'ACTIVE',
    },
  });

  const memberUser2 = await prisma.user.upsert({
    where: { phoneNumber: '+251911666666' },
    update: {},
    create: {
      fullName: 'Tigist Mengistu Desta',
      phoneNumber: '+251911666666',
      email: 'tigist.m@example.com',
      passwordHash,
      preferredLanguage: 'am',
      status: 'ACTIVE',
    },
  });

  console.log('✅ Users created.');

  // 3. Create Sample Idir
  const idir = await prisma.idir.upsert({
    where: { id: '00000000-0000-0000-0000-000000000001' },
    update: {},
    create: {
      id: '00000000-0000-0000-0000-000000000001',
      name: 'Bole Medhanealem Yebego Adragot Idir',
      description: 'Long-standing community mutual-aid association established in Bole, Addis Ababa.',
      region: 'Addis Ababa',
      zone: 'Bole Sub-City',
      woreda: 'Woreda 03',
      kebele: 'Kebele 07',
      address: 'Near Bole Medhanealem Cathedral',
      contactPhone: '+251911111111',
      contactEmail: 'contact@boleidir.et',
      currency: 'ETB',
      status: 'ACTIVE',
    },
  });

  // Settings
  await prisma.idirSettings.upsert({
    where: { idirId: idir.id },
    update: {},
    create: {
      idirId: idir.id,
      regularDuesAmount: new Prisma.Decimal(200.0),
      duesFrequency: 'MONTHLY',
      latePaymentGraceDays: 15,
      meetingFrequency: 'MONTHLY',
      allowIkub: true,
      maxAssistancePerYear: new Prisma.Decimal(50000.0),
      requireMultiApproval: true,
    },
  });

  console.log('✅ Idir and settings configured.');

  // 4. Enroll Memberships
  const mChairperson = await prisma.membership.upsert({
    where: { idirId_userId: { idirId: idir.id, userId: chairpersonUser.id } },
    update: {},
    create: {
      idirId: idir.id,
      userId: chairpersonUser.id,
      memberNumber: 'BM-001',
      role: 'CHAIRPERSON',
      status: 'ACTIVE',
    },
  });

  const mTreasurer = await prisma.membership.upsert({
    where: { idirId_userId: { idirId: idir.id, userId: treasurerUser.id } },
    update: {},
    create: {
      idirId: idir.id,
      userId: treasurerUser.id,
      memberNumber: 'BM-002',
      role: 'TREASURER',
      status: 'ACTIVE',
    },
  });

  const mSecretary = await prisma.membership.upsert({
    where: { idirId_userId: { idirId: idir.id, userId: secretaryUser.id } },
    update: {
      role: 'AUDITOR',
    },
    create: {
      idirId: idir.id,
      userId: secretaryUser.id,
      memberNumber: 'BM-003',
      role: 'AUDITOR',
      status: 'ACTIVE',
    },
  });

  const mCommittee = await prisma.membership.upsert({
    where: { idirId_userId: { idirId: idir.id, userId: committeeUser.id } },
    update: {},
    create: {
      idirId: idir.id,
      userId: committeeUser.id,
      memberNumber: 'BM-004',
      role: 'COMMITTEE',
      status: 'ACTIVE',
    },
  });

  const mMember1 = await prisma.membership.upsert({
    where: { idirId_userId: { idirId: idir.id, userId: memberUser1.id } },
    update: {},
    create: {
      idirId: idir.id,
      userId: memberUser1.id,
      memberNumber: 'BM-005',
      role: 'MEMBER',
      status: 'ACTIVE',
    },
  });

  const mMember2 = await prisma.membership.upsert({
    where: { idirId_userId: { idirId: idir.id, userId: memberUser2.id } },
    update: {},
    create: {
      idirId: idir.id,
      userId: memberUser2.id,
      memberNumber: 'BM-006',
      role: 'MEMBER',
      status: 'ACTIVE',
    },
  });

  console.log('✅ Memberships enrolled.');

  // 5. Contribution Types
  const duesType = await prisma.contributionType.create({
    data: {
      idirId: idir.id,
      name: 'Regular Monthly Dues',
      description: 'Monthly dues for association operations and mutual fund',
      defaultAmount: new Prisma.Decimal(200.0),
      isMandatory: true,
      isActive: true,
    },
  });

  const funeralType = await prisma.contributionType.create({
    data: {
      idirId: idir.id,
      name: 'Funeral Mutual Support',
      description: 'One-off contribution for deceased member family',
      defaultAmount: new Prisma.Decimal(500.0),
      isMandatory: true,
      isActive: true,
    },
  });

  // 6. Contributions
  await prisma.contribution.create({
    data: {
      idirId: idir.id,
      membershipId: mMember1.id,
      contributionTypeId: duesType.id,
      amount: new Prisma.Decimal(200.0),
      currency: 'ETB',
      paymentDate: new Date(),
      paymentMethod: 'TELEBIRR',
      paymentReference: 'TLB-293847291',
      receiptNumber: 'REC-261019-001',
      status: 'CONFIRMED',
      recordedById: treasurerUser.id,
      confirmedById: treasurerUser.id,
      confirmedAt: new Date(),
    },
  });

  await prisma.contribution.create({
    data: {
      idirId: idir.id,
      membershipId: mMember2.id,
      contributionTypeId: duesType.id,
      amount: new Prisma.Decimal(200.0),
      currency: 'ETB',
      paymentDate: new Date(),
      paymentMethod: 'CBE_BIRR',
      paymentReference: 'CBE-982371923',
      receiptNumber: 'REC-261019-002',
      status: 'CONFIRMED',
      recordedById: treasurerUser.id,
      confirmedById: treasurerUser.id,
      confirmedAt: new Date(),
    },
  });

  // 7. Operating Expense
  await prisma.expense.create({
    data: {
      idirId: idir.id,
      category: 'EVENT_TENT',
      amount: new Prisma.Decimal(3500.0),
      currency: 'ETB',
      expenseDate: new Date(),
      description: 'Tent and chair rental for community gathering',
      status: 'APPROVED',
      recordedById: treasurerUser.id,
      approvedById: chairpersonUser.id,
      approvedAt: new Date(),
    },
  });

  // 8. Assistance Case & Disbursement
  const assistanceCase = await prisma.assistanceCase.create({
    data: {
      idirId: idir.id,
      membershipId: mMember1.id,
      caseType: 'FUNERAL',
      title: 'Funeral support for late father',
      description: 'Funeral and burial support request according to Idir bylaws',
      deceasedName: 'Hailemariam Wolde',
      deceasedRelation: 'Father',
      status: 'APPROVED',
      isConfidential: false,
    },
  });

  const assistanceRequest = await prisma.assistanceRequest.create({
    data: {
      caseId: assistanceCase.id,
      requestedAmount: new Prisma.Decimal(20000.0),
      currency: 'ETB',
      justification: 'Hospital and burial expenses',
      submittedById: memberUser1.id,
      status: 'APPROVED',
      reviewedById: chairpersonUser.id,
      reviewedAt: new Date(),
      reviewNotes: 'Verified with family certificate. Approved in full.',
    },
  });

  await prisma.assistanceDisbursement.create({
    data: {
      requestId: assistanceRequest.id,
      idirId: idir.id,
      amount: new Prisma.Decimal(20000.0),
      currency: 'ETB',
      disbursedAt: new Date(),
      recipientName: memberUser1.fullName,
      recipientPhone: memberUser1.phoneNumber,
      paymentMethod: 'BANK_TRANSFER',
      paymentReference: 'CBE-TXN-7738291',
      receiptNumber: 'DISB-261019-001',
      recordedById: treasurerUser.id,
    },
  });

  // 9. Ikub Group (Separate Financial Pool)
  const ikubGroup = await prisma.ikubGroup.create({
    data: {
      idirId: idir.id,
      name: 'Bole Medhanealem Weekly Ikub Cycle 1',
      description: 'Rotating weekly savings pool for member business investments',
      contributionAmount: new Prisma.Decimal(1000.0),
      currency: 'ETB',
      frequency: 'WEEKLY',
      startDate: new Date(),
      totalRounds: 4,
      payoutRule: 'LOTTERY',
      status: 'ACTIVE',
    },
  });

  const p1 = await prisma.ikubParticipant.create({
    data: {
      ikubGroupId: ikubGroup.id,
      membershipId: mChairperson.id,
      payoutOrder: 1,
      status: 'ACTIVE',
      hasWonPayout: true,
    },
  });

  const p2 = await prisma.ikubParticipant.create({
    data: {
      ikubGroupId: ikubGroup.id,
      membershipId: mTreasurer.id,
      payoutOrder: 2,
      status: 'ACTIVE',
      hasWonPayout: false,
    },
  });

  const p3 = await prisma.ikubParticipant.create({
    data: {
      ikubGroupId: ikubGroup.id,
      membershipId: mMember1.id,
      payoutOrder: 3,
      status: 'ACTIVE',
      hasWonPayout: false,
    },
  });

  const p4 = await prisma.ikubParticipant.create({
    data: {
      ikubGroupId: ikubGroup.id,
      membershipId: mMember2.id,
      payoutOrder: 4,
      status: 'ACTIVE',
      hasWonPayout: false,
    },
  });

  // Round 1
  const round1 = await prisma.ikubRound.create({
    data: {
      ikubGroupId: ikubGroup.id,
      roundNumber: 1,
      scheduledDate: new Date(),
      recipientParticipantId: p1.id,
      status: 'COMPLETED',
      completedAt: new Date(),
    },
  });

  // Round 1 Contributions
  for (const p of [p1, p2, p3, p4]) {
    await prisma.ikubContribution.create({
      data: {
        roundId: round1.id,
        participantId: p.id,
        amount: new Prisma.Decimal(1000.0),
        currency: 'ETB',
        status: 'CONFIRMED',
        paymentMethod: 'TELEBIRR',
        recordedById: treasurerUser.id,
      },
    });
  }

  // Round 1 Payout (4,000 ETB)
  await prisma.ikubPayout.create({
    data: {
      roundId: round1.id,
      recipientParticipantId: p1.id,
      amount: new Prisma.Decimal(4000.0),
      currency: 'ETB',
      payoutDate: new Date(),
      status: 'CONFIRMED',
      paymentMethod: 'BANK_TRANSFER',
      paymentReference: 'IKUB-PAYOUT-001',
      approvedById: chairpersonUser.id,
      recordedById: treasurerUser.id,
    },
  });

  // Round 2 (Scheduled)
  await prisma.ikubRound.create({
    data: {
      ikubGroupId: ikubGroup.id,
      roundNumber: 2,
      scheduledDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      status: 'SCHEDULED',
    },
  });

  // 10. Meeting & Announcements
  const meeting = await prisma.meeting.create({
    data: {
      idirId: idir.id,
      title: 'Monthly General Assembly',
      agenda: 'Financial report review, election of audit committee, and upcoming holiday celebration',
      location: 'Bole Medhanealem Hall',
      scheduledAt: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
      createdById: chairpersonUser.id,
      status: 'SCHEDULED',
    },
  });

  await prisma.meetingAttendance.create({
    data: {
      meetingId: meeting.id,
      membershipId: mChairperson.id,
      status: 'PRESENT',
    },
  });

  await prisma.announcement.create({
    data: {
      idirId: idir.id,
      title: 'Upcoming General Assembly Meeting',
      body: 'All members are cordially invited to attend the upcoming monthly assembly at Bole Medhanealem Hall.',
      priority: 'NORMAL',
      isPinned: true,
      createdById: chairpersonUser.id,
    },
  });

  console.log('✅ Ikub pool, meetings, and announcements seeded.');
  console.log('\n======================================================');
  console.log('🚀 DEVELOPMENT CREDENTIALS FOR TESTING:');
  console.log('------------------------------------------------------');
  console.log('Platform Admin:  +251911000000 | Password: Password123!');
  console.log('Chairperson:     +251911111111 | Password: Password123!');
  console.log('Treasurer:       +251911222222 | Password: Password123!');
  console.log('Secretary:       +251911333333 | Password: Password123!');
  console.log('Member:          +251911555555 | Password: Password123!');
  console.log('======================================================\n');
}

main()
  .catch((e) => {
    console.error('❌ Seeding error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
