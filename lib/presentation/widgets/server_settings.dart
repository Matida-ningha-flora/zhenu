import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/l10n/tr.dart';
import '../../data/services/echosign_api_client.dart';
import '../../data/services/echosign_server.dart';
import '../../data/services/sign_media_service.dart';

/// Réglage du serveur de reconnaissance : recherche automatique sur le Wi-Fi
/// ou adresse saisie à la main. Renvoie `true` si un serveur répond.
Future<bool?> showServerSettings(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ServerSheet(),
    );

class _ServerSheet extends StatefulWidget {
  const _ServerSheet();

  @override
  State<_ServerSheet> createState() => _ServerSheetState();
}

class _ServerSheetState extends State<_ServerSheet> {
  final _address = TextEditingController();
  bool _busy = false;
  String? _result;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    EchoSignServer.manual().then((value) {
      if (mounted) _address.text = value;
    });
    _address.addListener(() => setState(() {}));
    _search(initial: true);
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  void _show(String? address, EchoSignHealth? health) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _ok = address != null;
      _result = address == null
          ? tr(
              'Aucun serveur trouvé. Vérifiez que le serveur est lancé sur le PC (--host 0.0.0.0) et que le téléphone est sur le même Wi-Fi.',
              'No server found. Check that the server runs on the PC (--host 0.0.0.0) and that the phone is on the same Wi-Fi.')
          : '${tr('Connecté', 'Connected')} : $address'
              '${health == null ? '' : ' · ${health.signCount} ${tr('signes', 'signs')} · ${health.latency.inMilliseconds} ms'}';
    });
  }

  Future<void> _search({bool initial = false}) async {
    setState(() {
      _busy = true;
      _result = initial ? null : tr('Recherche…', 'Searching…');
    });
    final address = await EchoSignServer.locate(force: !initial);
    final health = address == null
        ? null
        : await EchoSignApiClient.checkHealth(address,
            timeout: const Duration(seconds: 3));
    if (address != null) SignMediaService.instance.refresh();
    _show(address, health);
  }

  Future<void> _save() async {
    final value = _address.text.trim();
    if (value.isNotEmpty && EchoSignApiClient.resolve(value) == null) {
      setState(() {
        _ok = false;
        _result = tr('Adresse invalide. Exemple : 192.168.1.20:8000',
            'Invalid address. Example: 192.168.1.20:8000');
      });
      return;
    }
    await EchoSignServer.setManual(value);
    await _search();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Serveur de reconnaissance', 'Recognition server'),
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              tr('L’application cherche le serveur toute seule sur votre Wi-Fi. Si besoin, saisissez l’adresse affichée sur le PC.',
                  'The app looks for the server on your Wi-Fi. If needed, type the address shown on the PC.'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _address,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: tr('Adresse (facultatif)', 'Address (optional)'),
                hintText: '192.168.1.20:8000',
                prefixIcon: const Icon(Icons.dns_outlined),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            if (_busy)
              const LinearProgressIndicator()
            else if (_result != null)
              Row(children: [
                Icon(_ok ? Icons.check_circle_rounded : Icons.error_rounded,
                    size: 20,
                    color: _ok ? AppColors.success : theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_result!, style: theme.textTheme.bodySmall)),
              ]),
            const SizedBox(height: 8),
            FutureBuilder<List<String>>(
              future: EchoSignServer.deviceAddresses(),
              builder: (context, snapshot) {
                final addresses = snapshot.data ?? const [];
                if (addresses.isEmpty) return const SizedBox.shrink();
                return Text(
                  tr('Adresse de ce téléphone : ${addresses.join(', ')} — le PC doit être sur le même réseau.',
                      'This phone: ${addresses.join(', ')} — the PC must be on the same network.'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _search(),
                  icon: const Icon(Icons.wifi_find_rounded),
                  label: Text(tr('Rechercher', 'Search')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _busy
                      ? null
                      : _ok && _address.text.trim().isEmpty
                          ? () => Navigator.pop(context, true)
                          : _save,
                  child: Text(_ok && _address.text.trim().isEmpty
                      ? tr('Terminé', 'Done')
                      : tr('Enregistrer', 'Save')),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
