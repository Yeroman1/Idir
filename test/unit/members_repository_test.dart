import 'package:flutter_test/flutter_test.dart';
import 'package:idir_app/features/members/data/members_repository.dart';
import 'package:idir_app/features/members/domain/models/member.dart';

void main() {
  group('MembersRepository and Member model unit tests', () {
    late FirestoreMembersRepository repository;

    setUp(() {
      repository = FirestoreMembersRepository();
    });

    test('Loads initial sample members', () async {
      final members = await repository.getMembers();
      expect(members.length, 5);
      expect(members.first.memberId, 'MEM-001');
      expect(members.first.fullName, 'Abebe Tadesse');
      expect(members.first.dependents.length, 2);
    });

    test('generateNextMemberId generates sequential ID correctly', () async {
      final nextId = await repository.generateNextMemberId();
      expect(nextId, 'MEM-006');
    });

    test('Adds a new member successfully', () async {
      final now = DateTime.now();
      final newMember = Member(
        id: 'mem_test_new',
        memberId: 'MEM-006',
        fullName: 'Kenenisa Bekele',
        phone: '+251 91 999 8877',
        registeredAt: now,
        monthlyDues: 50.0,
        status: MemberStatus.active,
        emergencyContact: const EmergencyContact(
          name: 'Danawit Bekele',
          phone: '+251 91 888 7766',
          relationship: 'Spouse',
        ),
        dependents: const [
          Dependent(id: 'd_test', name: 'Blen Bekele', relationship: 'Daughter'),
        ],
        totalPaid: 0.0,
        balance: 0.0,
        arrears: 0.0,
        notes: 'Olympic athlete member',
        createdAt: now,
        updatedAt: now,
      );

      await repository.addMember(newMember);

      final members = await repository.getMembers();
      expect(members.length, 6);

      final fetched = await repository.getMemberById('mem_test_new');
      expect(fetched, isNotNull);
      expect(fetched!.fullName, 'Kenenisa Bekele');
      expect(fetched.emergencyContact?.name, 'Danawit Bekele');
    });

    test('Updates an existing member and status toggle', () async {
      final member = await repository.getMemberById('mem_1');
      expect(member, isNotNull);
      expect(member!.status, MemberStatus.active);

      final updated = member.copyWith(
        status: MemberStatus.suspended,
        notes: 'Updated notes',
      );
      await repository.updateMember(updated);

      final afterUpdate = await repository.getMemberById('mem_1');
      expect(afterUpdate!.status, MemberStatus.suspended);
      expect(afterUpdate.notes, 'Updated notes');
    });

    test('Deletes a member record', () async {
      await repository.deleteMember('mem_2');
      final afterDelete = await repository.getMemberById('mem_2');
      expect(afterDelete, isNull);

      final remaining = await repository.getMembers();
      expect(remaining.length, 4);
    });

    test('Member toMap and fromMap serialization roundtrip', () {
      final now = DateTime.now();
      final member = Member(
        id: 'roundtrip_id',
        memberId: 'MEM-999',
        fullName: 'Tirunesh Dibaba',
        phone: '+251 91 777 6655',
        registeredAt: now,
        monthlyDues: 75.0,
        status: MemberStatus.active,
        emergencyContact: const EmergencyContact(
          name: 'Sileshi Sihine',
          phone: '+251 91 666 5544',
          relationship: 'Spouse',
        ),
        dependents: const [
          Dependent(id: 'dep_1', name: 'Nathan Sileshi', relationship: 'Son'),
        ],
        totalPaid: 150.0,
        balance: 50.0,
        arrears: 0.0,
        notes: 'Roundtrip test',
        createdAt: now,
        updatedAt: now,
      );

      final map = member.toMap();
      final reconstructed = Member.fromMap('roundtrip_id', map);

      expect(reconstructed.id, member.id);
      expect(reconstructed.memberId, member.memberId);
      expect(reconstructed.fullName, member.fullName);
      expect(reconstructed.monthlyDues, 75.0);
      expect(reconstructed.status, MemberStatus.active);
      expect(reconstructed.emergencyContact?.name, 'Sileshi Sihine');
      expect(reconstructed.dependents.length, 1);
      expect(reconstructed.dependents.first.name, 'Nathan Sileshi');
    });
  });
}
