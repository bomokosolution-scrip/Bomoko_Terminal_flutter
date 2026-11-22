import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../data.dart';
import '../ssh_service.dart';
import '../theme.dart';
import '../widgets.dart';

Future<void> _sheet(BuildContext context, WidgetBuilder b) {
  final c = C.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 22, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(child: b(ctx)),
    ),
  );
}

Widget _fab(String label, IconData icon, VoidCallback onTap) {
  return Pressable(
    onTap: onTap,
    child: Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: Pal.aurora,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Pal.violet.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ------------------------------------------------------------ forwarding

class ForwardingScreen extends StatelessWidget {
  const ForwardingScreen({super.key});

  Future<void> _toggle(BuildContext context, ForwardRule r, bool on) async {
    try {
      if (on) {
        await hub.startForward(r);
      } else {
        await hub.stopForward(r.id);
      }
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e), error: true);
    }
  }

  void _add(BuildContext context) {
    if (data.hosts.isEmpty) {
      toast(context, 'Ajoutez d\'abord un hôte.');
      return;
    }
    final label = TextEditingController();
    final lp = TextEditingController(text: '8080');
    final rh = TextEditingController(text: '127.0.0.1');
    final rp = TextEditingController(text: '80');
    String hostId = data.hosts.first.id;
    String? err;
    _sheet(context, (ctx) {
      return StatefulBuilder(builder: (ctx, set) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nouvelle redirection',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(controller: label, decoration: fieldDeco(ctx, 'Nom', hint: 'Base de données')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: hostId,
              decoration: fieldDeco(ctx, 'Passer par l\'hôte'),
              dropdownColor: C.of(ctx).surface2,
              items: [for (final h in data.hosts) DropdownMenuItem(value: h.id, child: Text(h.label))],
              onChanged: (v) => set(() => hostId = v ?? hostId),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                    controller: lp,
                    keyboardType: TextInputType.number,
                    decoration: fieldDeco(ctx, 'Port local')),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(controller: rh, decoration: fieldDeco(ctx, 'Destination')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                    controller: rp,
                    keyboardType: TextInputType.number,
                    decoration: fieldDeco(ctx, 'Port')),
              ),
            ]),
            if (err != null) ...[
              const SizedBox(height: 10),
              Text(err!, style: const TextStyle(color: Pal.rose)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () async {
                  final l = int.tryParse(lp.text.trim());
                  final r = int.tryParse(rp.text.trim());
                  if (l == null || r == null || l < 1024 || l > 65535 || r < 1 || r > 65535) {
                    set(() => err = 'Port local entre 1024 et 65535, port distant entre 1 et 65535.');
                    return;
                  }
                  final dest = rh.text.trim().isEmpty ? '127.0.0.1' : rh.text.trim();
                  await data.saveRule(ForwardRule(
                    id: newId(),
                    label: label.text.trim().isEmpty ? 'Redirection $l' : label.text.trim(),
                    hostId: hostId,
                    localPort: l,
                    remoteHost: dest,
                    remotePort: r,
                  ));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Enregistrer'),
              ),
            ),
          ],
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return SubPage(
      title: 'Redirection de ports',
      subtitle: 'Accédez à un service distant comme s\'il était local',
      fab: _fab('Ajouter', Icons.add_rounded, () => _add(context)),
      body: ListenableBuilder(
        listenable: Listenable.merge([data, hub]),
        builder: (context, _) {
          if (data.rules.isEmpty) {
            return const EmptyState(
              title: 'Aucune redirection',
              text: 'Créez un tunnel pour atteindre une base de données ou une interface web du serveur.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: data.rules.length,
            itemBuilder: (_, i) {
              final r = data.rules[i];
              final on = hub.isForwarding(r.id);
              String hostName = '?';
              for (final h in data.hosts) {
                if (h.id == r.hostId) hostName = h.label;
              }
              return Enter(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Panel(
                    child: Row(children: [
                      GradTile(
                          icon: Icons.swap_horiz_rounded,
                          colors: on ? [Pal.mint, Pal.cyan] : kGrads[3]),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          const SizedBox(height: 3),
                          Text('127.0.0.1:${r.localPort} → ${r.remoteHost}:${r.remotePort}',
                              style: TextStyle(
                                  fontFamily: 'JetBrainsMono', fontSize: 11.5, color: c.muted)),
                          Text('via $hostName', style: TextStyle(color: c.muted, fontSize: 12)),
                        ]),
                      ),
                      Switch(value: on, onChanged: (v) => _toggle(context, r, v)),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: c.muted),
                        onPressed: () async {
                          if (await confirm(context, 'Supprimer la redirection ?', r.label)) {
                            await hub.stopForward(r.id);
                            await data.deleteRule(r);
                          }
                        },
                      ),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// -------------------------------------------------------------- snippets

class SnippetsScreen extends StatelessWidget {
  const SnippetsScreen({super.key});

  void _edit(BuildContext context, [Snippet? sn]) {
    final name = TextEditingController(text: sn?.name ?? '');
    final cmd = TextEditingController(text: sn?.command ?? '');
    _sheet(context, (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sn == null ? 'Nouvel extrait' : 'Modifier l\'extrait',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(controller: name, decoration: fieldDeco(ctx, 'Nom')),
            const SizedBox(height: 12),
            TextField(
              controller: cmd,
              minLines: 3,
              maxLines: 6,
              autocorrect: false,
              style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13),
              decoration: fieldDeco(ctx, 'Commande'),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () async {
                  if (name.text.trim().isEmpty || cmd.text.trim().isEmpty) return;
                  await data.saveSnippet(Snippet(
                      id: sn?.id ?? newId(), name: name.text.trim(), command: cmd.text.trim()));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Enregistrer'),
              ),
            ),
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return SubPage(
      title: 'Extraits',
      subtitle: 'Vos commandes favorites, en un geste',
      fab: _fab('Ajouter', Icons.add_rounded, () => _edit(context)),
      body: ListenableBuilder(
        listenable: data,
        builder: (context, _) {
          if (data.snippets.isEmpty) {
            return const EmptyState(
                title: 'Aucun extrait', text: 'Enregistrez les commandes que vous tapez souvent.');
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: data.snippets.length,
            itemBuilder: (_, i) {
              final s = data.snippets[i];
              return Enter(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Pressable(
                    onTap: () => _edit(context, s),
                    child: Panel(
                      child: Row(children: [
                        GradTile(icon: Icons.bolt_rounded, colors: kGrads[4]),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            const SizedBox(height: 3),
                            Text(s.command,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: 'JetBrainsMono', fontSize: 12, color: c.muted)),
                          ]),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: c.muted),
                          onPressed: () async {
                            if (await confirm(context, 'Supprimer l\'extrait ?', s.name)) {
                              await data.deleteSnippet(s);
                            }
                          },
                        ),
                      ]),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// -------------------------------------------------------------- keychain

class KeychainScreen extends StatelessWidget {
  const KeychainScreen({super.key});

  void _add(BuildContext context) {
    final name = TextEditingController();
    final pem = TextEditingController();
    final pass = TextEditingController();
    String? err;
    _sheet(context, (ctx) => StatefulBuilder(builder: (ctx, set) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ajouter une clé privée',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Elle est chiffrée dans le coffre sécurisé de l\'appareil.',
                  style: TextStyle(color: C.of(ctx).muted)),
              const SizedBox(height: 16),
              TextField(controller: name, decoration: fieldDeco(ctx, 'Nom', hint: 'Clé du serveur')),
              const SizedBox(height: 12),
              TextField(
                controller: pem,
                minLines: 4,
                maxLines: 8,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11.5),
                decoration: fieldDeco(
                  ctx,
                  'Clé privée (PEM / OpenSSH)',
                  hint: '-----BEGIN OPENSSH PRIVATE KEY-----',
                  suffix: IconButton(
                    icon: const Icon(Icons.content_paste_rounded),
                    onPressed: () async {
                      final d = await Clipboard.getData('text/plain');
                      if (d?.text != null) pem.text = d!.text!;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pass,
                obscureText: true,
                decoration: fieldDeco(ctx, 'Phrase secrète (optionnelle)'),
              ),
              if (err != null) ...[
                const SizedBox(height: 10),
                Text(err!, style: const TextStyle(color: Pal.rose)),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () async {
                    final text = pem.text.trim();
                    if (name.text.trim().isEmpty || text.isEmpty) {
                      set(() => err = 'Renseignez un nom et collez la clé.');
                      return;
                    }
                    try {
                      SSHKeyPair.fromPem(text, pass.text.isEmpty ? null : pass.text);
                    } catch (_) {
                      set(() => err = 'Clé invalide, ou phrase secrète incorrecte.');
                      return;
                    }
                    await data.addKey(KeyEntry(id: newId(), name: name.text.trim()), text, pass.text);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Enregistrer la clé'),
                ),
              ),
            ],
          );
        }));
  }

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return SubPage(
      title: 'Trousseau',
      subtitle: 'Vos clés SSH, protégées',
      fab: _fab('Ajouter', Icons.add_rounded, () => _add(context)),
      body: ListenableBuilder(
        listenable: data,
        builder: (context, _) {
          if (data.keys.isEmpty) {
            return const EmptyState(
                title: 'Aucune clé', text: 'Collez une clé privée pour vous connecter sans mot de passe.');
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: data.keys.length,
            itemBuilder: (_, i) {
              final k = data.keys[i];
              return Enter(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Panel(
                    child: Row(children: [
                      GradTile(icon: Icons.vpn_key_rounded, colors: kGrads[0]),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(k.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: c.muted),
                        onPressed: () async {
                          if (await confirm(context, 'Supprimer la clé ?',
                              '« ${k.name} » sera effacée de cet appareil.')) {
                            await data.deleteKey(k);
                          }
                        },
                      ),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --------------------------------------------------------------- history

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return SubPage(
      title: 'Historique',
      subtitle: 'Vos connexions récentes',
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_sweep_rounded),
          onPressed: () async {
            if (data.history.isNotEmpty &&
                await confirm(context, 'Vider l\'historique ?', 'Toutes les entrées seront supprimées.', ok: 'Vider')) {
              await data.clearHistory();
            }
          },
        ),
      ],
      body: ListenableBuilder(
        listenable: data,
        builder: (context, _) {
          if (data.history.isEmpty) {
            return const EmptyState(title: 'Historique vide', text: 'Vos connexions apparaîtront ici.');
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: data.history.length,
            itemBuilder: (_, i) {
              final h = data.history[i];
              return Enter(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Panel(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(children: [
                      GradTile(
                        icon: h.ok ? Icons.check_rounded : Icons.close_rounded,
                        colors: h.ok ? kGrads[2] : kGrads[1],
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(h.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(h.address, style: TextStyle(color: c.muted, fontSize: 12)),
                        ]),
                      ),
                      Text(fmtDate(h.at), style: TextStyle(color: c.muted, fontSize: 12)),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ----------------------------------------------------------- known hosts

class KnownHostsScreen extends StatelessWidget {
  const KnownHostsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return SubPage(
      title: 'Hôtes connus',
      subtitle: 'Empreintes des serveurs de confiance',
      body: ListenableBuilder(
        listenable: data,
        builder: (context, _) {
          if (data.knownHosts.isEmpty) {
            return const EmptyState(
                title: 'Aucune empreinte', text: 'Les serveurs que vous approuvez seront listés ici.');
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: data.knownHosts.length,
            itemBuilder: (_, i) {
              final k = data.knownHosts[i];
              return Enter(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Panel(
                    child: Row(children: [
                      GradTile(icon: Icons.fingerprint_rounded, colors: kGrads[5]),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(k.id, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          const SizedBox(height: 3),
                          Text(k.fingerprint,
                              maxLines: 2,
                              style: TextStyle(
                                  fontFamily: 'JetBrainsMono', fontSize: 10.5, color: c.muted)),
                        ]),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: c.muted),
                        onPressed: () => data.deleteKnownHost(k),
                      ),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
