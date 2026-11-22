import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../l10n.dart';
import '../theme.dart';
import '../widgets.dart';
import 'tools.dart';

const String kDeveloper = 'Bomoko Solution';
const String kWhatsApp = '243891989036';
const String kTelegram = 'worldsolutiontv';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String, List<Color>, Widget)>[
      (Icons.swap_horiz_rounded, 'Redirection de ports', 'Tunnels locaux', kGrads[3], const ForwardingScreen()),
      (Icons.bolt_rounded, 'Extraits', 'Commandes rapides', kGrads[4], const SnippetsScreen()),
      (Icons.vpn_key_rounded, 'Trousseau', 'Clés SSH', kGrads[0], const KeychainScreen()),
      (Icons.history_rounded, 'Historique', 'Connexions récentes', kGrads[2], const HistoryScreen()),
      (Icons.fingerprint_rounded, 'Hôtes connus', 'Empreintes approuvées', kGrads[5], const KnownHostsScreen()),
      (Icons.palette_rounded, 'Thèmes', 'Couleurs et terminal', kGrads[6], const ThemesScreen()),
      (Icons.settings_rounded, 'Réglages', 'Police et sécurité', kGrads[7], const SettingsScreen()),
      (Icons.support_agent_rounded, 'Contact', 'Aide et développeur', kGrads[1], const AboutScreen()),
    ];
    final c = C.of(context);
    return Column(
      children: [
        const ScreenHeader(title: 'Plus', subtitle: 'Outils et réglages'),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.08,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final it = items[i];
              return Enter(
                index: i,
                child: Pressable(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => it.$5)),
                  child: Panel(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GradTile(icon: it.$1, colors: it.$4, size: 54),
                        const Spacer(),
                        Text(it.$2,
                            maxLines: 2,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(it.$3, style: TextStyle(color: c.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- themes

class ThemesScreen extends StatelessWidget {
  const ThemesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return SubPage(
      title: 'Thèmes',
      subtitle: 'Apparence de l\'application et du terminal',
      body: ListenableBuilder(
        listenable: data,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Système'), icon: Icon(Icons.brightness_auto_rounded)),
                ButtonSegment(value: ThemeMode.light, label: Text('Clair'), icon: Icon(Icons.light_mode_rounded)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Sombre'), icon: Icon(Icons.dark_mode_rounded)),
              ],
              selected: {data.themeMode},
              onSelectionChanged: (s) => data.setThemeMode(s.first),
            ),
            const SizedBox(height: 22),
            Text('Ambiance sombre', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(children: [
              for (var i = 0; i < C.darkVariants.length; i++)
                Expanded(child: _variant(context, i)),
            ]),
            const SizedBox(height: 22),
            Text('Couleurs du terminal', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            for (var i = 0; i < termPalettes.length; i++) _palette(context, i),
          ],
        ),
      ),
    );
  }

  Widget _variant(BuildContext context, int i) {
    final v = C.darkVariants[i];
    final sel = data.darkVariant == i;
    const names = ['Nuit', 'Graphite', 'Noir pur'];
    return Padding(
      padding: EdgeInsets.only(right: i == C.darkVariants.length - 1 ? 0 : 10),
      child: Pressable(
        onTap: () => data.setDarkVariant(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: v.bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: sel ? Pal.violet : C.of(context).line, width: sel ? 2.2 : 1),
          ),
          child: Column(children: [
            Container(
              height: 44,
              decoration: BoxDecoration(color: v.surface, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Container(
                width: 28,
                height: 6,
                decoration: BoxDecoration(gradient: Pal.aurora, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 8),
            Text(names[i],
                style: TextStyle(color: v.text, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _palette(BuildContext context, int i) {
    final p = termPalettes[i];
    final t = p.theme;
    final sel = data.termPalette == i;
    TextSpan sp(String s, Color col) =>
        TextSpan(text: s, style: TextStyle(color: col, fontFamily: 'JetBrainsMono', fontSize: 12.5));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Pressable(
        onTap: () => data.setPalette(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? Pal.violet : C.of(context).line, width: sel ? 2.2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(p.name,
                    style: TextStyle(color: t.foreground, fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                if (sel) const Icon(Icons.check_circle_rounded, color: Pal.violet, size: 20),
              ]),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(children: [
                  sp('root', t.red),
                  sp('@', t.foreground),
                  sp('bomoko', t.green),
                  sp(':~# ', t.foreground),
                  sp('ls -la\n', t.cyan),
                  sp('drwxr-xr-x ', t.blue),
                  sp('projets\n', t.yellow),
                  sp('-rw-r--r-- ', t.magenta),
                  sp('notes.txt', t.foreground),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                for (final col in [t.red, t.green, t.yellow, t.blue, t.magenta, t.cyan])
                  Container(
                    width: 22,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(4)),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- settings

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _setPin(BuildContext context) async {
    final a = TextEditingController();
    final b = TextEditingController();
    String? err;
    final c = C.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Code PIN'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: a,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: fieldDeco(ctx, 'Nouveau code (4 à 6 chiffres)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: b,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: fieldDeco(ctx, 'Confirmer le code'),
            ),
            if (err != null) Text(err!, style: const TextStyle(color: Pal.rose)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                final ok = RegExp(r'^\d{4,6}$').hasMatch(a.text);
                if (!ok) {
                  set(() => err = 'Le code doit contenir 4 à 6 chiffres.');
                } else if (a.text != b.text) {
                  set(() => err = 'Les deux codes sont différents.');
                } else {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Activer'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) await data.enablePin(a.text);
  }

  Widget _title(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(t, style: TextStyle(color: C.of(context).muted, fontWeight: FontWeight.w600)),
      );

  Widget _drop<T>(BuildContext context, String label, T value, List<T> items, String Function(T) name,
      ValueChanged<T> onChanged) {
    final c = C.of(context);
    return DropdownButtonFormField<T>(
      value: value,
      decoration: fieldDeco(context, label),
      dropdownColor: c.surface2,
      items: [for (final i in items) DropdownMenuItem<T>(value: i, child: Text(name(i)))],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return SubPage(
      title: 'Réglages',
      subtitle: 'Langue, terminal et sécurité',
      body: ListenableBuilder(
        listenable: data,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            _title(context, 'Langue'),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(children: [
                for (final l in kLanguages)
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    leading: const GradTile(icon: Icons.language_rounded, colors: [Pal.violet, Pal.cyan], size: 38),
                    title: Text(l.$2),
                    trailing: data.lang == l.$1
                        ? const Icon(Icons.check_circle_rounded, color: Pal.violet)
                        : Icon(Icons.circle_outlined, color: c.muted),
                    onTap: () => data.setLang(l.$1),
                  ),
              ]),
            ),
            _title(context, 'Terminal'),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const GradTile(icon: Icons.text_fields_rounded, colors: [Pal.violet, Pal.cyan], size: 40),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Taille de la police', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text('${data.fontSize.round()} pt', style: TextStyle(color: c.muted)),
                ]),
                Slider(
                  value: data.fontSize,
                  min: 10,
                  max: 22,
                  divisions: 12,
                  onChanged: data.setFontSize,
                ),
                Text('ls -la /var/www',
                    style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: data.fontSize, color: c.muted)),
                const SizedBox(height: 16),
                _drop<int>(context, 'Taille de l\'historique (lignes)', data.bufferLines,
                    const [1000, 5000, 10000, 50000], (v) => '$v', data.setBufferLines),
                const SizedBox(height: 12),
                _drop<String>(context, 'Type de terminal', data.termType,
                    const ['xterm-256color', 'xterm', 'vt100', 'linux'], (v) => v, data.setTermType),
                const SizedBox(height: 10),
                Row(children: [
                  const Expanded(
                    child: Text('Intervalle keep-alive', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text(data.keepAlive == 0 ? 'Désactivé' : '${data.keepAlive} s',
                      style: TextStyle(color: c.muted)),
                ]),
                Slider(
                  value: data.keepAlive.toDouble(),
                  min: 0,
                  max: 120,
                  divisions: 12,
                  onChanged: (v) => data.setKeepAlive(v.round()),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cloche du terminal'),
                  subtitle: const Text('Vibration lors d\'un signal de cloche'),
                  value: data.bell,
                  onChanged: data.setBell,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Empêcher la mise en veille'),
                  subtitle: const Text('Garde l\'écran allumé dans le terminal'),
                  value: data.wakelock,
                  onChanged: data.setWakelock,
                ),
              ]),
            ),
            _title(context, 'Sécurité et confidentialité'),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const GradTile(icon: Icons.lock_rounded, colors: [Pal.mint, Pal.cyan], size: 40),
                  title: const Text('Verrouillage par PIN'),
                  subtitle: const Text('Demandé à chaque retour dans l\'application'),
                  value: data.pinEnabled,
                  onChanged: (v) => v ? _setPin(context) : data.disablePin(),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const GradTile(icon: Icons.vibration_rounded, colors: [Pal.amber, Color(0xFFFF6B4A)], size: 40),
                  title: const Text('Retour haptique'),
                  value: data.haptics,
                  onChanged: data.setHaptics,
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- about

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _open(BuildContext context, String url, String fallback) async {
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && context.mounted) {
      await Clipboard.setData(ClipboardData(text: fallback));
      if (context.mounted) toast(context, 'Lien copié : $fallback');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return SubPage(
      title: 'Contact',
      subtitle: 'Une question ? Écrivez-nous',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          Panel(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Image.asset('assets/icon/icon.png', width: 92, height: 92),
              ),
              const SizedBox(height: 16),
              const Text('Bomoko Terminal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Version 1.0.0', style: TextStyle(color: c.muted)),
              const SizedBox(height: 14),
              Text('Client SSH, SFTP et redirection de ports',
                  textAlign: TextAlign.center, style: TextStyle(color: c.muted)),
            ]),
          ),
          const SizedBox(height: 14),
          _tile(context, Icons.code_rounded, kGrads[0], 'Développeur', kDeveloper, null),
          _tile(context, Icons.chat_rounded, kGrads[2], 'WhatsApp', '+$kWhatsApp',
              () => _open(context, 'https://wa.me/$kWhatsApp', 'https://wa.me/$kWhatsApp')),
          _tile(context, Icons.send_rounded, kGrads[7], 'Telegram', '@$kTelegram',
              () => _open(context, 'https://t.me/$kTelegram', 'https://t.me/$kTelegram')),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, List<Color> g, String title, String value, VoidCallback? onTap) {
    final c = C.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: onTap,
        child: Panel(
          child: Row(children: [
            GradTile(icon: icon, colors: g),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: c.muted, fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ]),
            ),
            if (onTap != null) Icon(Icons.open_in_new_rounded, color: c.muted, size: 20),
          ]),
        ),
      ),
    );
  }
}
