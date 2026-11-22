import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:xterm/xterm.dart';

import '../data.dart';
import '../l10n.dart';
import '../ssh_service.dart';
import '../theme.dart';
import '../widgets.dart';

class TerminalScreen extends StatefulWidget {
  final SshSession session;
  const TerminalScreen({super.key, required this.session});
  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  SshSession get s => widget.session;

  @override
  void initState() {
    super.initState();
    if (data.wakelock) WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _copy() async {
    final sel = s.controller.selection;
    if (sel == null) {
      toast(context, 'Sélectionnez d\'abord du texte (appui long).');
      return;
    }
    await Clipboard.setData(ClipboardData(text: s.terminal.buffer.getText(sel)));
    s.controller.clearSelection();
    if (mounted) toast(context, 'Texte copié');
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData('text/plain');
    final t = d?.text;
    if (t != null && t.isNotEmpty) s.terminal.paste(t);
  }

  void _snippets() {
    final c = C.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 10),
                child: Text('Extraits de commandes',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (data.snippets.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Aucun extrait. Créez-en dans Plus › Extraits.',
                      style: TextStyle(color: c.muted)),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final sn in data.snippets)
                      ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        leading: const GradTile(
                            icon: Icons.bolt_rounded, colors: [Pal.amber, Color(0xFFFF6B4A)], size: 40),
                        title: Text(sn.name),
                        subtitle: Text(sn.command,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12)),
                        onTap: () {
                          Navigator.pop(ctx);
                          s.sendText('${sn.command}\r');
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([s, data]),
      builder: (context, _) {
        final pIdx = s.host.palette >= 0 && s.host.palette < termPalettes.length
            ? s.host.palette
            : data.termPalette.clamp(0, termPalettes.length - 1).toInt();
        final pal = termPalettes[pIdx].theme;
        final lightBg = pal.background.computeLuminance() > 0.5;
        final fg = lightBg ? const Color(0xFF1C2340) : Colors.white;
        final ready = s.status == SessionStatus.connected || s.status == SessionStatus.closed;
        final dot = switch (s.status) {
          SessionStatus.connected => Pal.mint,
          SessionStatus.connecting => Pal.amber,
          _ => Pal.rose,
        };
        return Scaffold(
          backgroundColor: pal.background,
          appBar: AppBar(
            foregroundColor: fg,
            titleSpacing: 0,
            title: Row(children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.host.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w600)),
                    Text('${s.host.username}@${s.host.address}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: fg.withOpacity(0.6), fontSize: 11.5)),
                  ],
                ),
              ),
            ]),
            actions: [
              if (s.status == SessionStatus.connected) ...[
                IconButton(icon: const Icon(Icons.bolt_rounded), tooltip: tr('Extraits'), onPressed: _snippets),
                IconButton(icon: const Icon(Icons.content_paste_rounded), tooltip: tr('Coller'), onPressed: _paste),
              ],
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                color: C.of(context).surface2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (a) {
                  if (a == 'copy') _copy();
                  if (a == 'clear') s.terminal.write('\x1b[2J\x1b[H');
                  if (a == 'close') {
                    hub.remove(s);
                    Navigator.pop(context);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'copy', child: Text('Copier la sélection')),
                  PopupMenuItem(value: 'clear', child: Text('Effacer l\'écran')),
                  PopupMenuItem(value: 'close', child: Text('Fermer la session')),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 380),
                    child: ready
                        ? TerminalView(
                            s.terminal,
                            key: const ValueKey('term'),
                            controller: s.controller,
                            theme: pal,
                            textStyle: TerminalStyle(
                                fontSize: data.fontSize, fontFamily: 'JetBrainsMono'),
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                            autofocus: true,
                          )
                        : _Status(
                            key: ValueKey(s.status),
                            session: s,
                            fg: fg,
                          ),
                  ),
                ),
                if (s.status == SessionStatus.connected) _ExtraKeys(session: s, fg: fg, bg: pal.background),
                if (s.status == SessionStatus.closed)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    child: FilledButton.icon(
                      onPressed: s.connect,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Se reconnecter'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Status extends StatelessWidget {
  final SshSession session;
  final Color fg;
  const _Status({super.key, required this.session, required this.fg});

  @override
  Widget build(BuildContext context) {
    final failed = session.status == SessionStatus.failed;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            failed
                ? const GradTile(
                    icon: Icons.link_off_rounded,
                    colors: [Pal.rose, Color(0xFFFF8A4D)],
                    size: 72)
                : Pulse(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset('assets/icon/icon.png', width: 84, height: 84),
                    ),
                  ),
            const SizedBox(height: 24),
            Text(failed ? 'Connexion impossible' : 'Connexion en cours…',
                style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              failed
                  ? (session.error ?? 'Une erreur est survenue.')
                  : '${session.host.username}@${session.host.address}:${session.host.port}',
              textAlign: TextAlign.center,
              style: TextStyle(color: fg.withOpacity(0.65), height: 1.4),
            ),
            if (failed) ...[
              const SizedBox(height: 22),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      hub.remove(session);
                      Navigator.pop(context);
                    },
                    child: const Text('Fermer'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: session.connect,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExtraKeys extends StatelessWidget {
  final SshSession session;
  final Color fg, bg;
  const _ExtraKeys({required this.session, required this.fg, required this.bg});

  Widget _key(String label, VoidCallback onTap, {bool on = false, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: on ? Pal.violet : fg.withOpacity(0.09),
          ),
          child: icon != null
              ? Icon(icon, size: 20, color: on ? Colors.white : fg)
              : Text(label,
                  style: TextStyle(
                      color: on ? Colors.white : fg,
                      fontFamily: 'JetBrainsMono',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = session.terminal;
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: fg.withOpacity(0.10))),
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: session.ctrl,
        builder: (_, ctrl, __) => ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          children: [
            _key('Esc', () => t.keyInput(TerminalKey.escape)),
            _key('Tab', () => t.keyInput(TerminalKey.tab)),
            _key('Ctrl', () => session.ctrl.value = !session.ctrl.value, on: ctrl),
            _key('', () => t.keyInput(TerminalKey.arrowLeft), icon: Icons.keyboard_arrow_left_rounded),
            _key('', () => t.keyInput(TerminalKey.arrowDown), icon: Icons.keyboard_arrow_down_rounded),
            _key('', () => t.keyInput(TerminalKey.arrowUp), icon: Icons.keyboard_arrow_up_rounded),
            _key('', () => t.keyInput(TerminalKey.arrowRight), icon: Icons.keyboard_arrow_right_rounded),
            _key('|', () => session.sendText('|')),
            _key('/', () => session.sendText('/')),
            _key('-', () => session.sendText('-')),
            _key('~', () => session.sendText('~')),
            _key('_', () => session.sendText('_')),
            _key('Home', () => t.keyInput(TerminalKey.home)),
            _key('End', () => t.keyInput(TerminalKey.end)),
            _key('PgUp', () => t.keyInput(TerminalKey.pageUp)),
            _key('PgDn', () => t.keyInput(TerminalKey.pageDown)),
          ],
        ),
      ),
    );
  }
}
