import 'package:flutter/material.dart' hide Text;
import '../widgets.dart';
import '../data.dart';
import '../l10n.dart';
import '../ssh_service.dart';
import '../theme.dart';
import 'terminal.dart';

class SessionsScreen extends StatefulWidget {
  final VoidCallback onGoHosts;
  const SessionsScreen({super.key, required this.onGoHosts});
  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  String _since(DateTime d) {
    final m = DateTime.now().difference(d).inMinutes;
    if (m < 1) return 'à l\'instant';
    if (m < 60) return 'depuis $m min';
    return 'depuis ${m ~/ 60} h ${m % 60} min';
  }

  /// Accepte : "ssh user@hote -p 2222", "user@hote", "user@hote:2222".
  Host? _parse(String raw) {
    final parts = raw.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isNotEmpty && parts.first == 'ssh') parts.removeAt(0);
    String? target;
    var port = 22;
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] == '-p' && i + 1 < parts.length) {
        port = int.tryParse(parts[i + 1]) ?? 22;
        i++;
      } else if (parts[i].contains('@')) {
        target = parts[i];
      }
    }
    if (target == null) return null;
    final at = target.indexOf('@');
    final user = target.substring(0, at);
    var host = target.substring(at + 1);
    final colon = host.lastIndexOf(':');
    if (colon > 0 && !host.contains(']') && host.indexOf(':') == colon) {
      port = int.tryParse(host.substring(colon + 1)) ?? port;
      host = host.substring(0, colon);
    }
    if (user.isEmpty || host.isEmpty || port < 1 || port > 65535) return null;
    return Host(id: newId(), label: '$user@$host', address: host, username: user, port: port, color: 7);
  }

  Future<String?> _askPassword(Host h) async {
    final ctl = TextEditingController();
    final c = C.of(context);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Mot de passe'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(h.target, style: TextStyle(color: c.muted)),
          const SizedBox(height: 12),
          TextField(
            controller: ctl,
            autofocus: true,
            obscureText: true,
            decoration: fieldDeco(ctx, 'Mot de passe'),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('Connecter')),
        ],
      ),
    );
    ctl.dispose();
    return r;
  }

  Future<void> _quick() async {
    final raw = _ctl.text.trim();
    if (raw.isEmpty) return;
    final h = _parse(raw);
    if (h == null) {
      toast(context, 'Format attendu : ssh utilisateur@hôte -p port', error: true);
      return;
    }
    final pw = await _askPassword(h);
    if (pw == null || !mounted) return;
    hub.tempPw[h.id] = pw;
    final s = hub.open(h);
    _ctl.clear();
    FocusScope.of(context).unfocus();
    Navigator.push(context, MaterialPageRoute(builder: (_) => TerminalScreen(session: s)));
  }

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) {
        final list = hub.sessions;
        return Column(
          children: [
            ScreenHeader(
              title: 'Terminaux',
              subtitle: list.isEmpty ? 'Sessions ouvertes' : '${hub.liveCount} active${hub.liveCount > 1 ? 's' : ''}',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Panel(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _ctl,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _quick(),
                      style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13.5),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: tr('ssh utilisateur@hôte -p port'),
                        hintStyle: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13.5, color: c.muted),
                      ),
                    ),
                  ),
                  TextButton(onPressed: _quick, child: const Text('Connecter')),
                ]),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? EmptyState(
                      title: 'Aucun terminal ouvert',
                      text: 'Touchez un hôte ou utilisez la connexion rapide. Les sessions restent disponibles ici.',
                      action: 'Choisir un hôte',
                      onAction: widget.onGoHosts,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final s = list[i];
                        final col = switch (s.status) {
                          SessionStatus.connected => Pal.mint,
                          SessionStatus.connecting => Pal.amber,
                          _ => Pal.rose,
                        };
                        final label = switch (s.status) {
                          SessionStatus.connected => 'Connecté',
                          SessionStatus.connecting => 'Connexion…',
                          SessionStatus.closed => 'Terminé',
                          SessionStatus.failed => 'Échec',
                        };
                        return Enter(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: Pressable(
                              onTap: () => Navigator.push(
                                  context, MaterialPageRoute(builder: (_) => TerminalScreen(session: s))),
                              child: Panel(
                                child: Row(children: [
                                  GradTile(
                                      icon: Icons.terminal_rounded,
                                      colors: kGrads[s.host.color % kGrads.length]),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(s.host.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Row(children: [
                                          Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                                          const SizedBox(width: 6),
                                          Text('$label · ${_since(s.startedAt)}',
                                              style: TextStyle(color: c.muted, fontSize: 12.5)),
                                        ]),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => hub.remove(s),
                                    child: const Text('Fermer'),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
