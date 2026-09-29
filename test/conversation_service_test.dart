import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhendu_app/data/services/cloud.dart';
import 'package:zhendu_app/data/services/conversation_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  final awa = MockFirebaseAuth(
      signedIn: true,
      mockUser:
          MockUser(uid: 'awa', email: 'awa@test.com', displayName: 'Awa'));
  final paul = MockFirebaseAuth(
      signedIn: true,
      mockUser:
          MockUser(uid: 'paul', email: 'paul@test.com', displayName: 'Paul'));
  final service = ConversationService();

  void as(MockFirebaseAuth auth) => Cloud.useForTesting(db, auth);

  setUp(() => db = FakeFirebaseFirestore());
  tearDown(() => Cloud.useForTesting(null));

  test('créer un salon, le rejoindre par code et échanger', () async {
    as(awa);
    final room = await service.create(myName: 'Awa', title: 'Famille');
    expect(room.code, hasLength(6));
    expect(room.participants, ['awa']);

    as(paul);
    final joinedId =
        await service.joinByCode(room.code.toLowerCase(), myName: 'Paul');
    expect(joinedId, room.id);
    await service.send(room.id, text: 'Bonjour Awa', myName: 'Paul');

    as(awa);
    final rooms = await service.myRooms().first;
    expect(rooms.single.participants, ['awa', 'paul']);
    expect(rooms.single.lastMessage, 'Bonjour Awa');
    expect(rooms.single.hasUnread('awa'), isTrue);

    final messages = await service.messages(room.id).first;
    expect(messages.single.senderName, 'Paul');
    expect(messages.single.text, 'Bonjour Awa');

    await service.markRead(room.id);
    final updated = await service.watch(room.id).first;
    expect(updated.hasUnread('awa'), isFalse);
  });

  test('une invitation par e-mail apparaît chez l’invité', () async {
    as(awa);
    final room = await service
        .create(myName: 'Awa', inviteEmails: ['PAUL@test.com', 'awa@test.com']);
    expect(room.invitedEmails, ['paul@test.com']);

    as(paul);
    final invitations = await service.myRooms().first;
    expect(invitations.single.id, room.id);
    expect(invitations.single.isParticipant('paul'), isFalse);

    await service.join(room.id, myName: 'Paul');
    final joined =
        Room.fromDoc(await db.collection('conversations').doc(room.id).get());
    expect(joined.isParticipant('paul'), isTrue);
    expect(joined.invitedEmails, isEmpty);
    expect(joined.displayTitle('paul'), 'Awa');
  });

  test('un code inconnu ou un salon clôturé est refusé', () async {
    as(paul);
    expect(() => service.joinByCode('ABC123', myName: 'Paul'),
        throwsA(isA<ConversationException>()));

    as(awa);
    final room = await service.create(myName: 'Awa');
    await service.leave(room);
    as(paul);
    expect(() => service.join(room.id, myName: 'Paul'),
        throwsA(isA<ConversationException>()));
  });
}
