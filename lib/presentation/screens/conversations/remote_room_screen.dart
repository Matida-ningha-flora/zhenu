import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../../data/services/admin_data_service.dart';
import '../../../data/services/conversation_service.dart';
import '../../../data/services/notification_center.dart';
import '../../../data/services/translation_history_service.dart';
import '../../../data/services/voice_services.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/lsf_renderer.dart';
import '../../widgets/reception_modes.dart';
import '../../widgets/ui_kit.dart';
import '../translator_screen.dart';
import 'group_conversations.dart';

void copyRoomCode(BuildContext context, String code) {
  Clipboard.setData(ClipboardData(text: code));
  ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('Code $code copié.', 'Code $code copied.'))));
}

/// Salon de conversation à distance, en temps réel.
///
/// Chaque participant est sur son propre téléphone et n'envoie que ses
/// propres messages, en texte (clavier ou voix) ou en signes (caméra).
/// Les messages des autres lui sont présentés selon sa préférence de
/// réception : avatar animé, vidéo, landmarks ou texte.
class RemoteRoomScreen extends StatefulWidget {
  final String roomId;
  final String myName;

  const RemoteRoomScreen(
      {super.key, required this.roomId, required this.myName});

  @override
  State<RemoteRoomScreen> createState() => _RemoteRoomScreenState();
}

class _RemoteRoomScreenState extends State<RemoteRoomScreen> {
  static const _autoSpeakKey = 'conversation_auto_speak';
  static const _composeKey = 'conversation_compose_mode';

  final _service = ConversationService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<Room>? _roomSub;
  StreamSubscription<List<RoomMessage>>? _messagesSub;
  Timer? _heartbeat;
  Room? _room;
  List<RoomMessage> _messages = [];
  RoomMessage? _lsfMessage;
  bool _showLsf = true;
  bool _autoSpeak = false;

  /// Je m'exprime en signes (caméra) plutôt qu'au clavier.
  bool _bySign = false;
  bool _sending = false;
  final Set<String> _seen = {};
  bool _firstBatch = true;

  String get _uid => _service.uid;

  @override
  void initState() {
    super.initState();
    NotificationCenter.instance.openRoomId = widget.roomId;
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _autoSpeak = prefs.getBool(_autoSpeakKey) ?? false;
          _bySign = prefs.getString(_composeKey) == 'sign';
        });
      }
    });
    _roomSub = _service.watch(widget.roomId).listen((room) {
      if (mounted) setState(() => _room = room);
    });
    _messagesSub = _service.messages(widget.roomId).listen(_onMessages);
    _service.heartbeat(widget.roomId).catchError((_) {});
    _heartbeat = Timer.periodic(const Duration(seconds: 30),
        (_) => _service.heartbeat(widget.roomId).catchError((_) {}));
    _input.addListener(() => setState(() {}));
  }

  void _onMessages(List<RoomMessage> messages) {
    if (!mounted) return;
    final incoming = messages
        .where((m) => m.senderId != _uid && !_seen.contains(m.id))
        .toList();
    _seen.addAll(messages.map((m) => m.id));
    setState(() {
      _messages = messages;
      if (incoming.isNotEmpty) {
        _lsfMessage = incoming.last;
      } else if (_firstBatch) {
        final others = messages.where((m) => m.senderId != _uid);
        _lsfMessage = others.isEmpty ? null : others.last;
      }
    });
    if (!_firstBatch && _autoSpeak) {
      for (final m in incoming) {
        SpeechOutput.instance.speak(m.text);
      }
    }
    _firstBatch = false;
    _service.markRead(widget.roomId).catchError((_) {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    if (NotificationCenter.instance.openRoomId == widget.roomId) {
      NotificationCenter.instance.openRoomId = null;
    }
    _saveToHistory();
    _roomSub?.cancel();
    _messagesSub?.cancel();
    _heartbeat?.cancel();
    _input.dispose();
    _scroll.dispose();
    SpeechInput.instance.stop();
    super.dispose();
  }

  void _saveToHistory() {
    final room = _room;
    if (room == null || _messages.isEmpty) return;
    TranslationHistoryService.addEntry(
      id: 'room_${room.id}',
      type: 'conversation',
      input: '${tr('Salon', 'Room')} ${room.displayTitle(_uid)}',
      output: '${_messages.length} ${tr('message(s)', 'message(s)')}',
      messages: _messages
          .skip(_messages.length > 100 ? _messages.length - 100 : 0)
          .map((m) => {
                'speaker': m.senderId == _uid ? tr('Moi', 'Me') : m.senderName,
                'text': m.text,
                'isMe': m.senderId == _uid,
                'signed': m.signed,
                'time': m.createdAt?.toIso8601String() ?? '',
              })
          .toList(),
    );
  }

  Future<void> _send({bool signed = false, String? text}) async {
    final value = (text ?? _input.text).trim();
    if (value.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _service.send(widget.roomId,
          text: value, myName: widget.myName, signed: signed);
      if (text == null) _input.clear();
      AdminDataService.recordTranslation(value);
      // Les messages signés sont lus à voix haute sur mon appareil aussi.
      if (signed) SpeechOutput.instance.speak(value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('Envoi impossible : ${cleanError(e)}',
                'Could not send: ${cleanError(e)}'))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _dictate() async {
    final speech = SpeechInput.instance;
    if (speech.listening) {
      await speech.stop();
      return;
    }
    final ok = await speech.listen((text, isFinal) {
      if (!mounted) return;
      _input.text = text;
      if (isFinal && text.trim().isNotEmpty) _send();
    });
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('Reconnaissance vocale indisponible.',
              'Speech recognition unavailable.'))));
    }
  }

  Future<void> _sign() async {
    final sentence = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SignCaptureSheet(),
    );
    if (sentence != null) await _send(signed: true, text: sentence);
  }

  Future<void> _setComposeMode(bool bySign) async {
    if (bySign) await SpeechInput.instance.stop();
    setState(() => _bySign = bySign);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_composeKey, bySign ? 'sign' : 'text');
  }

  Future<void> _toggleAutoSpeak() async {
    setState(() => _autoSpeak = !_autoSpeak);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSpeakKey, _autoSpeak);
  }

  Future<void> _invite() async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Inviter par e-mail', 'Invite by email')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
              labelText: tr('Adresse e-mail', 'Email address'),
              prefixIcon: const Icon(Icons.mail_outline_rounded)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('Annuler', 'Cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(tr('Inviter', 'Invite')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty || !mounted) return;
    if (!emailPattern.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Adresse invalide.', 'Invalid address.'))));
      return;
    }
    try {
      await _service.invite(widget.roomId, [email]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('Invitation envoyée à $email.',
                'Invitation sent to $email.'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(cleanError(e))));
      }
    }
  }

  Future<void> _leave() async {
    final room = _room;
    if (room == null) return;
    final isHost = room.createdBy == _uid;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isHost
            ? tr('Clôturer le salon ?', 'Close the room?')
            : tr('Quitter le salon ?', 'Leave the room?')),
        content: Text(isHost
            ? tr(
                'La conversation se termine pour tous les participants. Elle reste dans votre historique.',
                'The conversation ends for everyone. It stays in your history.')
            : tr('Vous ne recevrez plus les messages de ce salon.',
                'You will no longer receive messages from this room.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('Annuler', 'Cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, true),
            child:
                Text(isHost ? tr('Clôturer', 'Close') : tr('Quitter', 'Leave')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final navigator = Navigator.of(context);
    try {
      await _service.leave(room);
    } catch (_) {}
    navigator.pop();
  }

  void _showParticipants() {
    final room = _room;
    if (room == null) return;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(tr('Participants', 'Participants'),
                    style: theme.textTheme.titleMedium),
              ),
              for (final id in room.participants)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        participantColor(id).withValues(alpha: 0.15),
                    child: Text((room.names[id] ?? '?')[0].toUpperCase(),
                        style: TextStyle(
                            color: participantColor(id),
                            fontWeight: FontWeight.w700)),
                  ),
                  title: Text(id == _uid
                      ? '${room.names[id] ?? ''} (${tr('vous', 'you')})'
                      : room.names[id] ?? '?'),
                  subtitle: Text(id == room.createdBy
                      ? tr('Organisateur', 'Host')
                      : tr('Participant', 'Participant')),
                  trailing: StatusPill(
                    label: room.isOnline(id)
                        ? tr('En ligne', 'Online')
                        : tr('Absent', 'Away'),
                    color: room.isOnline(id)
                        ? AppColors.success
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              for (final email in room.invitedEmails)
                ListTile(
                  leading: const CircleAvatar(
                      child: Icon(Icons.hourglass_empty_rounded, size: 18)),
                  title: Text(email),
                  subtitle: Text(tr('Invitation envoyée', 'Invitation sent')),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final room = _room;
    final online =
        room == null ? 0 : room.participants.where(room.isOnline).length;
    final closed = room != null && !room.active;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: room == null
            ? const SizedBox.shrink()
            : InkWell(
                onTap: _showParticipants,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.displayTitle(_uid),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium),
                    Text(
                      '${room.participants.length} ${tr('participant(s)', 'participant(s)')} · $online ${tr('en ligne', 'online')}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
        actions: [
          IconButton(
            tooltip: _showLsf
                ? tr('Masquer la LSF', 'Hide LSF')
                : tr('Afficher la LSF', 'Show LSF'),
            onPressed: () => setState(() => _showLsf = !_showLsf),
            icon: Icon(_showLsf
                ? Icons.sign_language_rounded
                : Icons.sign_language_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'reception':
                  showReceptionModePicker(context);
                case 'code':
                  if (room != null) showRoomCodeSheet(context, room);
                case 'invite':
                  _invite();
                case 'people':
                  _showParticipants();
                case 'speak':
                  _toggleAutoSpeak();
                case 'leave':
                  _leave();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'reception',
                child: ListTile(
                    leading: const Icon(Icons.tune_rounded),
                    title: Text(tr(
                        'Recevoir les messages en…', 'Receive messages as…'))),
              ),
              PopupMenuItem(
                value: 'code',
                child: ListTile(
                    leading: const Icon(Icons.qr_code_2_rounded),
                    title: Text(tr('Code du salon', 'Room code'))),
              ),
              PopupMenuItem(
                value: 'invite',
                child: ListTile(
                    leading: const Icon(Icons.person_add_alt_outlined),
                    title: Text(tr('Inviter par e-mail', 'Invite by email'))),
              ),
              PopupMenuItem(
                value: 'people',
                child: ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: Text(tr('Participants', 'Participants'))),
              ),
              CheckedPopupMenuItem(
                value: 'speak',
                checked: _autoSpeak,
                child:
                    Text(tr('Lire les messages reçus', 'Read messages aloud')),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'leave',
                child: ListTile(
                  leading: Icon(Icons.logout_rounded,
                      color: theme.colorScheme.error),
                  title: Text(
                      room?.createdBy == _uid
                          ? tr('Clôturer le salon', 'Close room')
                          : tr('Quitter le salon', 'Leave room'),
                      style: TextStyle(color: theme.colorScheme.error)),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(children: [
        if (closed)
          MaterialBanner(
            content: Text(tr('Ce salon a été clôturé par l’organisateur.',
                'This room was closed by the host.')),
            leading: const Icon(Icons.lock_outline_rounded),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr('Retour', 'Back'))),
            ],
          ),
        ListenableBuilder(
          listenable: AppPreferences.instance,
          builder: (context, _) {
            final message = _lsfMessage;
            // En mode « texte », les bulles suffisent.
            if (!_showLsf ||
                message == null ||
                AppPreferences.instance.responseFormat == 'text') {
              return const SizedBox.shrink();
            }
            return Container(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.42),
              color: theme.colorScheme.surfaceContainerLow,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                            '${message.senderName} · ${tr('en LSF', 'in LSF')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                                color: participantColor(message.senderId))),
                      ),
                      const ReceptionModeButton(),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: LsfRenderer(
                        key: ValueKey(
                            '${message.id}-${AppPreferences.instance.responseFormat}'),
                        text: message.text,
                        stageHeight: 190,
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Expanded(
          child: room == null
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? EmptyState(
                      icon: Icons.forum_outlined,
                      title: tr('Salon prêt', 'Room ready'),
                      message: tr(
                          'Code du salon : ${room.code}. Vos messages sont envoyés à tous les participants.',
                          'Room code: ${room.code}. Your messages go to every participant.'),
                      action: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44)),
                        onPressed: () => copyRoomCode(context, room.code),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: Text(tr('Copier le code', 'Copy code')),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) => _Bubble(
                        message: _messages[i],
                        isMe: _messages[i].senderId == _uid,
                        showName: i == 0 ||
                            _messages[i - 1].senderId != _messages[i].senderId,
                        onShowLsf: () => setState(() {
                          _lsfMessage = _messages[i];
                          _showLsf = true;
                        }),
                      ),
                    ),
        ),
        Material(
          color: theme.colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                    segments: [
                      ButtonSegment(
                          value: false,
                          icon: const Icon(Icons.keyboard_alt_outlined),
                          label: Text(tr('Texte', 'Text'))),
                      ButtonSegment(
                          value: true,
                          icon: const Icon(Icons.front_hand_outlined),
                          label: Text(tr('Signes', 'Signs'))),
                    ],
                    selected: {_bySign},
                    onSelectionChanged:
                        closed ? null : (v) => _setComposeMode(v.first),
                  ),
                ),
                const SizedBox(height: 8),
                if (_bySign)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52)),
                      onPressed: closed || _sending ? null : _sign,
                      icon: const Icon(Icons.videocam_rounded),
                      label: Text(tr('Signer mon message', 'Sign my message')),
                    ),
                  )
                else
                  _textComposer(theme, closed),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _textComposer(ThemeData theme, bool closed) => Row(children: [
        Expanded(
          child: TextField(
            controller: _input,
            enabled: !closed,
            minLines: 1,
            maxLines: 4,
            maxLength: ConversationService.maxLength,
            buildCounter: (_,
                    {required currentLength, required isFocused, maxLength}) =>
                null,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              hintText: tr('Votre message…', 'Your message…'),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 4),
        if (_input.text.trim().isEmpty)
          ListenableBuilder(
            listenable: SpeechInput.instance,
            builder: (context, _) => IconButton.filled(
              tooltip: tr('Dicter', 'Dictate'),
              style: SpeechInput.instance.listening
                  ? IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.error)
                  : null,
              onPressed: closed ? null : _dictate,
              icon: Icon(SpeechInput.instance.listening
                  ? Icons.stop_rounded
                  : Icons.mic_rounded),
            ),
          )
        else
          IconButton.filled(
            tooltip: tr('Envoyer', 'Send'),
            onPressed: _sending || closed ? null : _send,
            icon: const Icon(Icons.send_rounded),
          ),
      ]);
}

class _Bubble extends StatelessWidget {
  final RoomMessage message;
  final bool isMe;
  final bool showName;
  final VoidCallback onShowLsf;

  const _Bubble({
    required this.message,
    required this.isMe,
    required this.showName,
    required this.onShowLsf,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = message.createdAt == null
        ? '…'
        : '${message.createdAt!.hour.toString().padLeft(2, '0')}:${message.createdAt!.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Container(
          margin: EdgeInsets.only(bottom: 6, top: showName ? 6 : 0),
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 4),
          decoration: BoxDecoration(
            color: isMe
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            border: isMe
                ? null
                : Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showName && !isMe)
                Text(message.senderName,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: participantColor(message.senderId))),
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 2),
                child: Text(message.text, style: theme.textTheme.bodyLarge),
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (message.signed)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.front_hand_outlined,
                        size: 14, color: theme.colorScheme.onSurfaceVariant),
                  ),
                Text(time,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                if (isMe)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: tr('Relire à voix haute', 'Read aloud again'),
                    onPressed: () => SpeechOutput.instance.speak(message.text),
                    icon: const Icon(Icons.volume_up_outlined, size: 18),
                  )
                else ...[
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: tr('Afficher en LSF', 'Show in LSF'),
                    onPressed: onShowLsf,
                    icon: Icon(Icons.sign_language_outlined,
                        size: 18, color: theme.colorScheme.primary),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: tr('Écouter', 'Play'),
                    onPressed: () => SpeechOutput.instance.speak(message.text),
                    icon: const Icon(Icons.volume_up_outlined, size: 18),
                  ),
                ],
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
