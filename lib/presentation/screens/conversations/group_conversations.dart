import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../../data/services/conversation_service.dart';
import '../../../data/services/firebase_auth_service.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/ui_kit.dart';
import 'remote_room_screen.dart';

const _palette = AppColors.participants;

/// Couleur stable associée à un participant.
Color participantColor(String id) =>
    _palette[id.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length];

/// Onglet « Conversations » : chaque participant est connecté sur son propre
/// téléphone et n'écrit (ou ne signe) que ses propres messages.
class GroupConversationsTab extends StatelessWidget {
  const GroupConversationsTab({super.key});

  @override
  Widget build(BuildContext context) => ConversationService().available
      ? const RemoteConversationsHome()
      : const _AccountRequired();
}

/// Sans compte en ligne, aucune conversation n'est possible.
class _AccountRequired extends StatelessWidget {
  const _AccountRequired();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const IconTile(
              icon: Icons.cloud_off_rounded,
              color: AppColors.terracotta,
              size: 64),
          const SizedBox(height: 20),
          Text(tr('Compte en ligne requis', 'Online account required'),
              style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            tr('Les conversations se font entre deux téléphones : chacun se connecte à son compte, puis crée ou rejoint un salon avec son code. Vérifiez votre connexion internet et reconnectez-vous.',
                'Conversations happen between two phones: each person signs in to their account, then creates or joins a room with its code. Check your internet connection and sign in again.'),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }
}

class RemoteConversationsHome extends StatefulWidget {
  const RemoteConversationsHome({super.key});

  @override
  State<RemoteConversationsHome> createState() =>
      _RemoteConversationsHomeState();
}

class _RemoteConversationsHomeState extends State<RemoteConversationsHome> {
  final _service = ConversationService();
  late final Stream<List<Room>> _rooms = _service.myRooms();
  String _myName = '';

  @override
  void initState() {
    super.initState();
    FirebaseAuthService().getCurrentUser().then((user) {
      if (mounted) {
        setState(() => _myName = (user?['name'] as String?)?.trim() ?? '');
      }
    });
  }

  String get _name => _myName.isNotEmpty
      ? _myName
      : (_service.email.isEmpty
          ? tr('Moi', 'Me')
          : _service.email.split('@').first);

  void _open(Room room) => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RemoteRoomScreen(roomId: room.id, myName: _name)));

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(cleanError(e))));
    }
  }

  Future<void> _create() async {
    final result =
        await showModalBottomSheet<({String title, List<String> emails})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateRoomSheet(),
    );
    if (result == null) return;
    await _run(() async {
      final room = await _service.create(
          myName: _name, title: result.title, inviteEmails: result.emails);
      if (!mounted) return;
      _open(room);
      await showRoomCodeSheet(context, room);
    });
  }

  Future<void> _join() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _JoinDialog(),
    );
    if (code == null) return;
    await _run(() async {
      final roomId = await _service.joinByCode(code, myName: _name);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => RemoteRoomScreen(roomId: roomId, myName: _name)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = _service.uid;
    return StreamBuilder<List<Room>>(
      stream: _rooms,
      builder: (context, snapshot) {
        final rooms = snapshot.data ?? const <Room>[];
        final invitations = rooms.where((r) => !r.isParticipant(uid)).toList();
        final mine = rooms.where((r) => r.isParticipant(uid)).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const IconTile(
                        icon: Icons.forum_rounded,
                        color: AppColors.terracotta,
                        size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              tr('Conversations à distance',
                                  'Remote conversations'),
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            tr('Chacun sur son téléphone, en temps réel. Les messages reçus vous sont traduits en LSF.',
                                'Everyone on their own phone, in real time. Messages you receive are translated into LSF.'),
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48)),
                        onPressed: _create,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(tr('Créer', 'Create')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48)),
                        onPressed: _join,
                        icon: const Icon(Icons.login_rounded),
                        label: Text(tr('Rejoindre', 'Join')),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            if (invitations.isNotEmpty) ...[
              const SizedBox(height: 24),
              SectionHeader(tr('Invitations', 'Invitations')),
              for (final room in invitations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _InvitationCard(
                    room: room,
                    onAccept: () => _run(() async {
                      await _service.join(room.id, myName: _name);
                      if (mounted) _open(room);
                    }),
                    onDecline: () => _run(() => _service.decline(room.id)),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            SectionHeader(tr('Mes salons', 'My rooms')),
            if (snapshot.hasError)
              AppCard(
                child: Text(
                  tr('Connexion au service impossible. Vérifiez votre réseau.',
                      'Cannot reach the service. Check your connection.'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              )
            else if (!snapshot.hasData)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (mine.isEmpty)
              AppCard(
                child: Row(children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr('Aucun salon pour l’instant. Créez-en un et partagez son code.',
                          'No rooms yet. Create one and share its code.'),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ]),
              )
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (var i = 0; i < mine.length; i++) ...[
                    if (i > 0) const Divider(indent: 76),
                    _RoomTile(
                        room: mine[i], uid: uid, onTap: () => _open(mine[i])),
                  ],
                ]),
              ),
          ],
        );
      },
    );
  }
}

class _RoomTile extends StatelessWidget {
  final Room room;
  final String uid;
  final VoidCallback onTap;

  const _RoomTile({required this.room, required this.uid, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = room.hasUnread(uid);
    final title = room.displayTitle(uid);
    final preview = room.lastMessage.isEmpty
        ? '${room.participants.length} ${tr('participant(s)', 'participant(s)')} · ${tr('code', 'code')} ${room.code}'
        : '${room.lastSenderName} : ${room.lastMessage}';
    final time = room.lastMessageAt == null
        ? ''
        : relativeTime(room.lastMessageAt!.toIso8601String(),
            english: AppPreferences.instance.isEnglish);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: participantColor(room.id).withValues(alpha: 0.15),
        child: Text(title.isEmpty ? '#' : title[0].toUpperCase(),
            style: TextStyle(
                color: participantColor(room.id), fontWeight: FontWeight.w700)),
      ),
      title: Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: unread ? const TextStyle(fontWeight: FontWeight.w700) : null),
      subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(time, style: theme.textTheme.labelSmall),
          const SizedBox(height: 6),
          if (unread)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: theme.colorScheme.primary, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  final Room room;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InvitationCard(
      {required this.room, required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = room.names[room.createdBy] ?? tr('Quelqu’un', 'Someone');
    return AppCard(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.mark_email_unread_outlined,
                color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                room.title.isEmpty
                    ? tr('$host vous invite à converser',
                        '$host invites you to talk')
                    : tr('$host vous invite dans « ${room.title} »',
                        '$host invites you to “${room.title}”'),
                style: theme.textTheme.titleSmall,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: onDecline,
                child: Text(tr('Refuser', 'Decline')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: onAccept,
                child: Text(tr('Rejoindre', 'Join')),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _CreateRoomSheet extends StatefulWidget {
  const _CreateRoomSheet();

  @override
  State<_CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<_CreateRoomSheet> {
  final _title = TextEditingController();
  final _email = TextEditingController();
  final List<String> _emails = [];
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _email.dispose();
    super.dispose();
  }

  void _addEmail() {
    final value = _email.text.trim().toLowerCase();
    if (value.isEmpty) return;
    if (!emailPattern.hasMatch(value)) {
      setState(() => _error = tr('Adresse invalide.', 'Invalid address.'));
      return;
    }
    setState(() {
      if (!_emails.contains(value)) _emails.add(value);
      _email.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('Nouveau salon', 'New room'),
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText:
                      tr('Nom du salon (facultatif)', 'Room name (optional)'),
                  prefixIcon: const Icon(Icons.edit_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    onSubmitted: (_) => _addEmail(),
                    decoration: InputDecoration(
                      labelText: tr('Inviter par e-mail', 'Invite by email'),
                      prefixIcon: const Icon(Icons.person_add_alt_outlined),
                      errorText: _error,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
                  tooltip: tr('Ajouter', 'Add'),
                  onPressed: _addEmail,
                  icon: const Icon(Icons.add_rounded),
                ),
              ]),
              if (_emails.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in _emails)
                    InputChip(
                      label: Text(e),
                      onDeleted: () => setState(() => _emails.remove(e)),
                    ),
                ]),
              ],
              const SizedBox(height: 8),
              Text(
                tr('Vous pourrez aussi partager le code du salon.',
                    'You can also share the room code.'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (_email.text.trim().isNotEmpty) _addEmail();
                  if (_error != null) return;
                  Navigator.pop(context,
                      (title: _title.text.trim(), emails: List.of(_emails)));
                },
                child: Text(tr('Créer le salon', 'Create room')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinDialog extends StatefulWidget {
  const _JoinDialog();

  @override
  State<_JoinDialog> createState() => _JoinDialogState();
}

class _JoinDialogState extends State<_JoinDialog> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(tr('Rejoindre un salon', 'Join a room')),
        content: TextField(
          controller: _code,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 6),
          decoration: InputDecoration(
            hintText: 'ABC123',
            helperText: tr('Code à 6 caractères donné par l’organisateur',
                '6-character code from the organiser'),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('Annuler', 'Cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, _code.text),
            child: Text(tr('Rejoindre', 'Join')),
          ),
        ],
      );
}

/// Affiche le code d'invitation d'un salon, prêt à être partagé.
Future<void> showRoomCodeSheet(BuildContext context, Room room) =>
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(tr('Code du salon', 'Room code'),
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SelectableText(
                  room.code,
                  style: theme.textTheme.headlineLarge?.copyWith(
                      letterSpacing: 8,
                      color: theme.colorScheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr('Communiquez ce code à vos interlocuteurs : ils le saisissent dans « Rejoindre ».',
                    'Share this code: others enter it in “Join”.'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    copyRoomCode(context, room.code);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(tr('Copier le code', 'Copy code')),
                ),
              ),
            ]),
          ),
        );
      },
    );
