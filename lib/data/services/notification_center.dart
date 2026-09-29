import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin_data_service.dart';
import 'conversation_service.dart';
import 'firebase_auth_service.dart';

/// Centre de notifications de l'utilisateur.
///
/// Les annonces de l'administration arrivent en temps réel depuis Firestore
/// (collection `announcements`) lorsque le service en ligne est disponible,
/// et depuis le stockage local sinon.
class NotificationCenter extends ChangeNotifier {
  NotificationCenter._();
  static final NotificationCenter instance = NotificationCenter._();

  static const _lastReadKey = 'notifications_last_read_at';

  List<Map<String, dynamic>> _local = [];
  List<Map<String, dynamic>> _remote = [];
  DateTime? _lastRead;
  bool _enabled = true;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  Timer? _poll;
  final _incoming = StreamController<Map<String, dynamic>>.broadcast();
  final Set<String> _seenIds = {};
  bool _started = false;

  // Conversations à distance
  StreamSubscription<List<Room>>? _roomsSub;
  final Map<String, DateTime?> _roomActivity = {};
  bool _roomsPrimed = false;

  /// Salon actuellement affiché : ses messages ne déclenchent pas d'alerte.
  String? openRoomId;

  /// Invitations en attente et salons avec des messages non lus.
  int conversationAlerts = 0;

  /// Nouvelle notification reçue pendant que l'application est ouverte.
  Stream<Map<String, dynamic>> get incoming => _incoming.stream;

  List<Map<String, dynamic>> get items {
    final byId = <String, Map<String, dynamic>>{
      for (final item in [..._local, ..._remote]) item['id'].toString(): item,
    };
    final list = byId.values.toList()
      ..sort((a, b) => (b['createdAt'] as String? ?? '')
          .compareTo(a['createdAt'] as String? ?? ''));
    return _enabled ? list : const [];
  }

  int get unreadCount => items.where(_isUnread).length;

  bool isUnread(Map<String, dynamic> item) => _isUnread(item);

  bool _isUnread(Map<String, dynamic> item) {
    final created = DateTime.tryParse(item['createdAt'] as String? ?? '');
    return _lastRead == null || created == null || created.isAfter(_lastRead!);
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    final prefs = await SharedPreferences.getInstance();
    _lastRead = DateTime.tryParse(prefs.getString(_lastReadKey) ?? '');
    await refresh(announce: false);
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => refresh());
    _watchConversations();
    if (FirebaseAuthService().isFirebaseConfigured) {
      try {
        _subscription = FirebaseFirestore.instance
            .collection('announcements')
            .orderBy('createdAt', descending: true)
            .limit(30)
            .snapshots()
            .listen((snapshot) {
          _remote = snapshot.docs.map((doc) {
            final data = doc.data();
            final created = data['createdAt'];
            return {
              ...data,
              'id': doc.id,
              'createdAt': created is Timestamp
                  ? created.toDate().toIso8601String()
                  : created?.toString() ?? '',
            };
          }).toList();
          _announceNew();
          notifyListeners();
        }, onError: (Object e) => debugPrint('Notifications en ligne : $e'));
      } catch (e) {
        debugPrint('Notifications en ligne indisponibles : $e');
      }
    }
  }

  void _watchConversations() {
    final service = ConversationService();
    if (!service.available) return;
    final uid = service.uid;
    _roomsSub = service.myRooms().listen((rooms) {
      conversationAlerts =
          rooms.where((r) => !r.isParticipant(uid) || r.hasUnread(uid)).length;
      for (final room in rooms) {
        final previous = _roomActivity[room.id];
        final known = _roomActivity.containsKey(room.id);
        _roomActivity[room.id] = room.lastMessageAt;
        if (!_roomsPrimed || room.id == openRoomId) continue;
        final title = room.displayTitle(uid);
        if (!room.isParticipant(uid) && !known) {
          final host = room.names[room.createdBy] ?? '';
          _incoming.add({
            'id': 'invite_${room.id}',
            'title': 'Invitation',
            'message': '$host · $title',
          });
        } else if (known &&
            room.hasUnread(uid) &&
            room.lastMessageAt != null &&
            (previous == null || room.lastMessageAt!.isAfter(previous))) {
          _incoming.add({
            'id':
                'msg_${room.id}_${room.lastMessageAt!.millisecondsSinceEpoch}',
            'title': title,
            'message': '${room.lastSenderName} : ${room.lastMessage}',
          });
        }
      }
      _roomsPrimed = true;
      notifyListeners();
    }, onError: (Object e) => debugPrint('Conversations : $e'));
  }

  Future<void> refresh({bool announce = true}) async {
    final settings = await AdminDataService.loadSettings();
    _enabled = settings['notificationsEnabled'] != false;
    _local = await AdminDataService.loadAnnouncements();
    if (announce) {
      _announceNew();
    } else {
      _seenIds.addAll(items.map((e) => e['id'].toString()));
    }
    notifyListeners();
  }

  void _announceNew() {
    for (final item in items) {
      final id = item['id'].toString();
      if (_seenIds.add(id) && _isUnread(item)) _incoming.add(item);
    }
  }

  Future<void> markAllRead() async {
    _lastRead = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastReadKey, _lastRead!.toIso8601String());
    notifyListeners();
  }

  Future<void> stop() async {
    _started = false;
    _poll?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    await _roomsSub?.cancel();
    _roomsSub = null;
    _roomActivity.clear();
    _roomsPrimed = false;
    conversationAlerts = 0;
    _remote = [];
    _seenIds.clear();
  }
}
