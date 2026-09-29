import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'cloud.dart';

/// Salon de conversation à distance (collection Firestore `conversations`).
class Room {
  final String id;
  final String title;
  final String code;
  final String createdBy;
  final List<String> participants;
  final Map<String, String> names;
  final List<String> invitedEmails;
  final bool active;
  final String lastMessage;
  final String lastSenderName;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final Map<String, DateTime> lastRead;
  final Map<String, DateTime> presence;

  /// Profil de chaque participant (`deaf`, `hearing`, `both`).
  final Map<String, String> userTypes;

  const Room({
    required this.id,
    required this.title,
    required this.code,
    required this.createdBy,
    required this.participants,
    required this.names,
    required this.invitedEmails,
    required this.active,
    required this.lastMessage,
    required this.lastSenderName,
    required this.lastMessageAt,
    required this.createdAt,
    required this.lastRead,
    required this.presence,
    this.userTypes = const {},
  });

  static DateTime? _date(Object? value) => switch (value) {
        Timestamp t => t.toDate(),
        DateTime d => d,
        String s => DateTime.tryParse(s),
        _ => null,
      };

  static Map<String, DateTime> _dates(Object? value) {
    final result = <String, DateTime>{};
    if (value is Map) {
      value.forEach((key, v) {
        final date = _date(v);
        if (date != null) result[key.toString()] = date;
      });
    }
    return result;
  }

  factory Room.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Room(
      id: doc.id,
      title: data['title'] as String? ?? '',
      code: data['code'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      participants: List<String>.from(data['participants'] as List? ?? []),
      names: Map<String, String>.from((data['participantNames'] as Map? ?? {})
          .map((k, v) => MapEntry(k.toString(), v.toString()))),
      invitedEmails: List<String>.from(data['invitedEmails'] as List? ?? []),
      active: data['active'] != false,
      lastMessage: data['lastMessage'] as String? ?? '',
      lastSenderName: data['lastSenderName'] as String? ?? '',
      lastMessageAt: _date(data['lastMessageAt']),
      createdAt: _date(data['createdAt']),
      lastRead: _dates(data['lastRead']),
      presence: _dates(data['presence']),
      userTypes: Map<String, String>.from(
          (data['participantProfiles'] as Map? ?? {})
              .map((k, v) => MapEntry(k.toString(), v.toString()))),
    );
  }

  bool isParticipant(String uid) => participants.contains(uid);

  /// Nom affiché : titre choisi, sinon les autres participants.
  String displayTitle(String myUid) {
    if (title.trim().isNotEmpty) return title;
    final others = participants
        .where((p) => p != myUid)
        .map((p) => names[p] ?? '?')
        .toList();
    return others.isEmpty ? code : others.join(', ');
  }

  bool hasUnread(String uid) {
    final last = lastMessageAt;
    if (last == null || lastSenderName.isEmpty) return false;
    final read = lastRead[uid];
    return read == null || last.isAfter(read);
  }

  bool isOnline(String uid) {
    final seen = presence[uid];
    return seen != null &&
        DateTime.now().difference(seen) < const Duration(seconds: 75);
  }

  DateTime get sortKey => lastMessageAt ?? createdAt ?? DateTime(2000);
}

class RoomMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final bool signed;
  final DateTime? createdAt;

  const RoomMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.signed,
    required this.createdAt,
  });

  factory RoomMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return RoomMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      text: data['text'] as String? ?? '',
      signed: data['signed'] == true,
      createdAt: Room._date(data['createdAt']),
    );
  }
}

class ConversationException implements Exception {
  final String message;
  const ConversationException(this.message);

  @override
  String toString() => message;
}

/// Conversations à distance entre plusieurs appareils, en temps réel.
///
/// Un salon est rejoint avec son code à 6 caractères, ou depuis une
/// invitation envoyée à l'adresse e-mail d'un compte.
class ConversationService {
  static const maxLength = 1000;
  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  FirebaseFirestore get _db => Cloud.db;
  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('conversations');

  bool get available => Cloud.ready;
  String get uid => Cloud.auth.currentUser!.uid;
  String get email => (Cloud.auth.currentUser!.email ?? '').toLowerCase();

  /// Salons dont je suis participant ou auxquels je suis invité, du plus
  /// récent au plus ancien.
  Stream<List<Room>> myRooms() {
    late final StreamController<List<Room>> controller;
    final byQuery = <int, List<Room>>{};
    final subs = <StreamSubscription>[];
    var expected = 0;

    void emit() {
      // Attend la première réponse de chaque requête avant de publier.
      if (byQuery.length < expected) return;
      final merged = <String, Room>{
        for (final rooms in byQuery.values)
          for (final room in rooms) room.id: room,
      };
      final list = merged.values.where((r) => r.active).toList()
        ..sort((a, b) => b.sortKey.compareTo(a.sortKey));
      controller.add(list);
    }

    controller = StreamController<List<Room>>(
      onListen: () {
        final queries = [
          _rooms.where('participants', arrayContains: uid),
          if (email.isNotEmpty)
            _rooms.where('invitedEmails', arrayContains: email),
        ];
        expected = queries.length;
        for (var i = 0; i < queries.length; i++) {
          subs.add(queries[i].snapshots().listen((snapshot) {
            byQuery[i] = snapshot.docs.map(Room.fromDoc).toList();
            emit();
          }, onError: controller.addError));
        }
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
      },
    );
    return controller.stream;
  }

  Stream<Room> watch(String roomId) =>
      _rooms.doc(roomId).snapshots().where((d) => d.exists).map(Room.fromDoc);

  Stream<List<RoomMessage>> messages(String roomId) => _rooms
      .doc(roomId)
      .collection('messages')
      .orderBy('createdAt')
      .limitToLast(300)
      .snapshots()
      .map((s) => s.docs.map(RoomMessage.fromDoc).toList());

  String _newCode() {
    final random = Random.secure();
    return List.generate(
        6, (_) => _codeAlphabet[random.nextInt(_codeAlphabet.length)]).join();
  }

  Future<Room> create({
    required String myName,
    String title = '',
    List<String> inviteEmails = const [],
  }) async {
    final room = _rooms.doc();
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _newCode();
      final codeRef = _db.collection('roomCodes').doc(code);
      final created = await _db.runTransaction<bool>((tx) async {
        final existing = await tx.get(codeRef);
        if (existing.exists) return false;
        tx.set(codeRef, {
          'roomId': room.id,
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(room, {
          'title': title.trim(),
          'code': code,
          'createdBy': uid,
          'participants': [uid],
          'participantNames': {uid: myName},
          'invitedEmails': _cleanEmails(inviteEmails),
          'active': true,
          'lastMessage': '',
          'lastSenderName': '',
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastRead': {uid: FieldValue.serverTimestamp()},
          'presence': {uid: FieldValue.serverTimestamp()},
        });
        return true;
      });
      if (created) return Room.fromDoc(await room.get());
    }
    throw const ConversationException(
        'Impossible de créer le salon. Réessayez.');
  }

  List<String> _cleanEmails(List<String> emails) => emails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.contains('@') && e != email)
      .toSet()
      .toList();

  /// Rejoint un salon avec son code. Renvoie l'identifiant du salon.
  Future<String> joinByCode(String code, {required String myName}) async {
    final clean =
        code.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean.length != 6) {
      throw const ConversationException('Le code comporte 6 caractères.');
    }
    final codeDoc = await _db.collection('roomCodes').doc(clean).get();
    final roomId = codeDoc.data()?['roomId'] as String?;
    if (roomId == null) {
      throw const ConversationException('Aucun salon ne correspond à ce code.');
    }
    await join(roomId, myName: myName);
    return roomId;
  }

  /// Ajoute l'utilisateur aux participants (invitation ou code).
  Future<void> join(String roomId, {required String myName}) async {
    final ref = _rooms.doc(roomId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw const ConversationException('Ce salon n’existe plus.');
      }
      final room = Room.fromDoc(snap);
      if (!room.active) {
        throw const ConversationException('Ce salon a été clôturé.');
      }
      if (room.isParticipant(uid)) return;
      tx.update(ref, {
        'participants': [...room.participants, uid],
        'participantNames': {...room.names, uid: myName},
        'invitedEmails': room.invitedEmails.where((e) => e != email).toList(),
      });
    });
  }

  Future<void> invite(String roomId, List<String> emails) async {
    final clean = _cleanEmails(emails);
    if (clean.isEmpty) return;
    await _rooms
        .doc(roomId)
        .update({'invitedEmails': FieldValue.arrayUnion(clean)});
  }

  Future<void> send(String roomId,
      {required String text,
      required String myName,
      bool signed = false}) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    if (clean.length > maxLength) {
      throw const ConversationException('Message trop long (1000 caractères).');
    }
    final room = _rooms.doc(roomId);
    final batch = _db.batch();
    batch.set(room.collection('messages').doc(), {
      'senderId': uid,
      'senderName': myName,
      'text': clean,
      'signed': signed,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(room, {
      'lastMessage': clean,
      'lastSenderName': myName,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastRead.$uid': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> markRead(String roomId) => _rooms
      .doc(roomId)
      .update({'lastRead.$uid': FieldValue.serverTimestamp()});

  /// Signale que l'utilisateur est présent dans le salon.
  /// Indique aux autres participants mon profil (sourd, entendant…).
  /// Sans les règles de sécurité à jour, l'écriture est refusée : le salon
  /// fonctionne quand même, sans l'indication.
  Future<void> shareUserType(String roomId, String userType) async {
    try {
      await _rooms.doc(roomId).update({'participantProfiles.$uid': userType});
    } catch (e) {
      debugPrint('Profil non partagé dans le salon : $e');
    }
  }

  Future<void> heartbeat(String roomId) => _rooms
      .doc(roomId)
      .update({'presence.$uid': FieldValue.serverTimestamp()});

  /// Quitte le salon ; le créateur le clôture pour tout le monde.
  Future<void> leave(Room room) async {
    final ref = _rooms.doc(room.id);
    if (room.createdBy == uid) {
      await ref.update({'active': false});
      await _db.collection('roomCodes').doc(room.code).delete();
      return;
    }
    await ref.update({
      'participants': FieldValue.arrayRemove([uid]),
    });
  }

  /// Refuse une invitation reçue.
  Future<void> decline(String roomId) => _rooms.doc(roomId).update({
        'invitedEmails': FieldValue.arrayRemove([email]),
      });
}
