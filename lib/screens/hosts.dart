import 'package:flutter/material.dart' hide Text;
import '../widgets.dart';
import '../data.dart';
import '../ssh_service.dart';
import '../theme.dart';
import 'terminal.dart';

class HostsScreen extends StatefulWidget {
  const HostsScreen({super.key});
  @override
  State<HostsScreen> createState() => _HostsScreenState();
}

class _HostsScreenState extends State<HostsScreen> {
  final _q = TextEditingController();
  bool _search = false;
  String? _group; // null = tous

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  List<Host> _visible() {
    final q = _q.text.trim().toLowerCase();
    final l = data.hosts.where((h) {
      if (_group != null && h.group != _group) return false;
      if (q.isEmpty) return true;
      return h.label.toLowerCase().contains(q) ||
          h.address.toLowerCase().contains(q) ||
          h.username.toLowerCase().contains(q) ||
          h.group.toLowerCase().contains(q) ||
          h.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
    l.sort((a, b) {
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
      if (a.lastUsed != b.lastUsed) return b.lastUsed.compareTo(a.lastUsed);
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return l;
  }

  void _connect(Host h) {
    data.touchHost(h);
    final s = hub.open(h);
    Navigator.push(context, MaterialPageRoute(builder: (_) => TerminalScreen(session: s)));
  }

  void _edit([Host? h]) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => HostForm(host: h)));
  }

  Future<void> _action(String a, Host h) async {
    switch (a) {
      case 'edit':
        _edit(h);
        break;
      case 'dup':
        final j = h.toJson();
        j['id'] = newId();
        j['label'] = '${h.label} (copie)';
        j['favorite'] = false;
        j['lastUsed'] = 0;
        final nh = Host.fromJson(j);
        await data.saveHost(nh);
        final pw = await data.secret('pw_${h.id}');
        if (pw != null) await data.setSecret('pw_${nh.id}', pw);
        break;
      case 'fav':
        h.favorite = !h.favorite;
        await data.saveHost(h);
        break;
      case 'del':
        if (await confirm(context, 'Supprimer cet hôte ?', '« ${h.label} » sera retiré de votre liste.')) {
          await data.deleteHost(h);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _Fab(onTap: () => _edit()),
      body: ListenableBuilder(
        listenable: Listenable.merge([data, hub]),
        builder: (context, _) {
          if (_group != null && !data.groups.contains(_group)) _group = null;
          final list = _visible();
          return Column(
            children: [
              ScreenHeader(
                title: 'Hôtes',
                subtitle: data.hosts.isEmpty
                    ? 'Vos serveurs, à portée de main'
                    : '${data.hosts.length} serveur${data.hosts.length > 1 ? 's' : ''}',
                actions: [
                  IconButton(
                    icon: Icon(_search ? Icons.close_rounded : Icons.search_rounded),
                    onPressed: () => setState(() {
                      _search = !_search;
                      if (!_search) _q.clear();
                    }),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: _search
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: TextField(
                          controller: _q,
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                          decoration: fieldDeco(context, 'Rechercher un hôte'),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              if (data.groups.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    children: [
                      _chip('Tous', _group == null, () => setState(() => _group = null)),
                      for (final g in data.groups)
                        _chip(g, _group == g, () => setState(() => _group = g)),
                    ],
                  ),
                ),
              Expanded(
                child: data.hosts.isEmpty
                    ? EmptyState(
                        title: 'Aucun hôte pour l\'instant',
                        text: 'Ajoutez votre premier serveur pour vous y connecter en SSH en quelques secondes.',
                        action: 'Ajouter un hôte',
                        onAction: () => _edit(),
                      )
                    : list.isEmpty
                        ? Center(child: Text('Aucun résultat', style: TextStyle(color: c.muted)))
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 96),
                            itemCount: list.length,
                            itemBuilder: (_, i) => _card(list[i], i),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) {
    final c = C.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: sel ? Pal.violet.withOpacity(0.20) : c.surface,
            border: Border.all(color: sel ? Pal.violet : c.line),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Pal.violet : c.muted)),
        ),
      ),
    );
  }

  Widget _card(Host h, int i) {
    final c = C.of(context);
    final t = Theme.of(context).textTheme;
    final live = hub.isConnected(h);
    return Enter(
      index: i,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Pressable(
          onTap: () => _connect(h),
          onLongPress: () => _edit(h),
          child: Panel(
            child: Row(
              children: [
                GradTile(
                  icon: h.auth == AuthType.key ? Icons.vpn_key_rounded : Icons.dns_rounded,
                  colors: kGrads[h.color % kGrads.length],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(h.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        if (h.favorite)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.star_rounded, size: 16, color: Pal.amber),
                          ),
                      ]),
                      const SizedBox(height: 3),
                      Text(h.target,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: 'JetBrainsMono', fontSize: 12, color: c.muted)),
                      if (h.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(spacing: 6, runSpacing: 4, children: [
                            for (final tag in h.tags.take(4))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: c.surface2,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(tag, style: TextStyle(fontSize: 10.5, color: c.muted)),
                              ),
                          ]),
                        ),
                    ],
                  ),
                ),
                if (live)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Pal.mint.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Connecté',
                        style: TextStyle(color: Pal.mint, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: c.muted),
                  color: c.surface2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (a) => _action(a, h),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    const PopupMenuItem(value: 'dup', child: Text('Dupliquer')),
                    PopupMenuItem(
                        value: 'fav',
                        child: Text(h.favorite ? 'Retirer des favoris' : 'Ajouter aux favoris')),
                    const PopupMenuItem(value: 'del', child: Text('Supprimer')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  final VoidCallback onTap;
  const _Fab({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          gradient: Pal.aurora,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Pal.violet.withOpacity(0.45), blurRadius: 22, offset: const Offset(0, 8)),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('Nouvel hôte',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ form

class HostForm extends StatefulWidget {
  final Host? host;
  const HostForm({super.key, this.host});
  @override
  State<HostForm> createState() => _HostFormState();
}

class _HostFormState extends State<HostForm> {
  Host? get _h => widget.host;
  late final TextEditingController _label = TextEditingController(text: _h?.label ?? '');
  late final TextEditingController _addr = TextEditingController(text: _h?.address ?? '');
  late final TextEditingController _port = TextEditingController(text: '${_h?.port ?? 22}');
  late final TextEditingController _user = TextEditingController(text: _h?.username ?? '');
  late final TextEditingController _group = TextEditingController(text: _h?.group ?? '');
  late final TextEditingController _tags = TextEditingController(text: (_h?.tags ?? []).join(', '));
  late final TextEditingController _env = TextEditingController(text: _h?.env ?? '');
  final _pw = TextEditingController();
  late AuthType _auth = _h?.auth ?? AuthType.password;
  late String? _keyId = _h?.keyId;
  late int _color = _h?.color ?? 0;
  late bool _ctrlH = _h?.ctrlH ?? false;
  late String _jump = _h?.jumpId ?? '';
  late String _snippet = _h?.snippetId ?? '';
  late int _palette = _h?.palette ?? -1;
  late int _charset = _h?.charset ?? 0;
  bool _hide = true;
  String? _err;

  @override
  void dispose() {
    for (final c in [_label, _addr, _port, _user, _group, _tags, _env, _pw]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final addr = _addr.text.trim();
    final user = _user.text.trim();
    final port = int.tryParse(_port.text.trim());
    if (addr.isEmpty || user.isEmpty) {
      setState(() => _err = 'Renseignez l\'adresse et l\'utilisateur.');
      return;
    }
    if (port == null || port < 1 || port > 65535) {
      setState(() => _err = 'Le port doit être compris entre 1 et 65535.');
      return;
    }
    if (_auth == AuthType.key && data.keyById(_keyId) == null) {
      setState(() => _err = 'Choisissez une clé du Trousseau.');
      return;
    }
    final h = _h ?? Host(id: newId(), label: addr, address: addr, username: user);
    h.label = _label.text.trim().isEmpty ? addr : _label.text.trim();
    h.address = addr;
    h.username = user;
    h.port = port;
    h.auth = _auth;
    h.keyId = _auth == AuthType.key ? _keyId : null;
    h.color = _color;
    h.group = _group.text.trim();
    h.tags = _tags.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    h.ctrlH = _ctrlH;
    h.jumpId = _jump.isEmpty ? null : _jump;
    h.snippetId = _snippet.isEmpty ? null : _snippet;
    h.env = _env.text.trim();
    h.palette = _palette;
    h.charset = _charset;
    await data.saveHost(h);
    if (_auth == AuthType.password && _pw.text.isNotEmpty) {
      await data.setSecret('pw_${h.id}', _pw.text);
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _section(String title, List<Widget> children) {
    final c = C.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
        ),
        ...children,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    final editing = _h != null;
    final others = data.hosts.where((x) => x.id != _h?.id).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Modifier l\'hôte' : 'Nouvel hôte'),
        actions: [
          IconButton(icon: const Icon(Icons.check_rounded), onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _section('Général', [
            TextField(controller: _label, decoration: fieldDeco(context, 'Nom', hint: 'Mon serveur')),
            const SizedBox(height: 12),
            TextField(
              controller: _addr,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: fieldDeco(context, 'Adresse ou IP', hint: '192.168.1.10 ou exemple.com'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _group,
              decoration: fieldDeco(context, 'Groupe', hint: 'Production'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tags,
              decoration: fieldDeco(context, 'Étiquettes', hint: 'web, ubuntu, client'),
            ),
          ]),
          _section('Connexion SSH', [
            Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _user,
                  autocorrect: false,
                  decoration: fieldDeco(context, 'Utilisateur', hint: 'root'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _port,
                  keyboardType: TextInputType.number,
                  decoration: fieldDeco(context, 'Port'),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            SegmentedButton<AuthType>(
              segments: const [
                ButtonSegment(
                    value: AuthType.password,
                    label: Text('Mot de passe'),
                    icon: Icon(Icons.password_rounded)),
                ButtonSegment(
                    value: AuthType.key, label: Text('Clé SSH'), icon: Icon(Icons.vpn_key_rounded)),
              ],
              selected: {_auth},
              onSelectionChanged: (s) => setState(() => _auth = s.first),
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _auth == AuthType.password
                  ? TextField(
                      key: const ValueKey('pw'),
                      controller: _pw,
                      obscureText: _hide,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: fieldDeco(
                        context,
                        'Mot de passe',
                        hint: editing ? 'Laisser vide pour conserver' : null,
                        suffix: IconButton(
                          icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                    )
                  : data.keys.isEmpty
                      ? Panel(
                          key: const ValueKey('nokey'),
                          child: Text(
                            'Aucune clé enregistrée. Ajoutez-en une dans Plus › Trousseau, puis revenez ici.',
                            style: TextStyle(color: c.muted),
                          ),
                        )
                      : DropdownButtonFormField<String>(
                          key: const ValueKey('key'),
                          value: data.keyById(_keyId) == null ? null : _keyId,
                          decoration: fieldDeco(context, 'Clé'),
                          dropdownColor: c.surface2,
                          items: [
                            for (final k in data.keys)
                              DropdownMenuItem(value: k.id, child: Text(k.name)),
                          ],
                          onChanged: (v) => setState(() => _keyId = v),
                        ),
            ),
          ]),
          Panel(
            padding: EdgeInsets.zero,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                shape: const Border(),
                collapsedShape: const Border(),
                leading: const GradTile(icon: Icons.tune_rounded, colors: [Pal.violet, Pal.cyan], size: 38),
                title: const Text('Options avancées', style: TextStyle(fontWeight: FontWeight.w600)),
                children: [
                  DropdownButtonFormField<String>(
                    value: others.any((x) => x.id == _jump) ? _jump : '',
                    decoration: fieldDeco(context, 'Hôte de rebond (host chaining)'),
                    dropdownColor: c.surface2,
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Aucun')),
                      for (final x in others) DropdownMenuItem(value: x.id, child: Text(x.label)),
                    ],
                    onChanged: (v) => setState(() => _jump = v ?? ''),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: data.snippets.any((x) => x.id == _snippet) ? _snippet : '',
                    decoration: fieldDeco(context, 'Extrait lancé à la connexion'),
                    dropdownColor: c.surface2,
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Aucun')),
                      for (final x in data.snippets) DropdownMenuItem(value: x.id, child: Text(x.name)),
                    ],
                    onChanged: (v) => setState(() => _snippet = v ?? ''),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _env,
                    minLines: 2,
                    maxLines: 5,
                    autocorrect: false,
                    style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13),
                    decoration: fieldDeco(context, 'Variables d\'environnement', hint: 'LANG=fr_FR.UTF-8'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _palette < termPalettes.length ? _palette : -1,
                    decoration: fieldDeco(context, 'Couleurs du terminal'),
                    dropdownColor: c.surface2,
                    items: [
                      const DropdownMenuItem(value: -1, child: Text('Par défaut')),
                      for (var i = 0; i < termPalettes.length; i++)
                        DropdownMenuItem(value: i, child: Text(termPalettes[i].name)),
                    ],
                    onChanged: (v) => setState(() => _palette = v ?? -1),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _charset,
                    decoration: fieldDeco(context, 'Encodage des caractères'),
                    dropdownColor: c.surface2,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('UTF-8')),
                      DropdownMenuItem(value: 1, child: Text('Latin-1 (ISO-8859-1)')),
                    ],
                    onChanged: (v) => setState(() => _charset = v ?? 0),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('La touche Suppr envoie Ctrl-H'),
                    value: _ctrlH,
                    onChanged: (v) => setState(() => _ctrlH = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text('Couleur', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < kGrads.length; i++)
                GestureDetector(
                  onTap: () {
                    tap();
                    setState(() => _color = i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _color == i ? c.text : Colors.transparent, width: 2),
                    ),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: kGrads[i]),
                      ),
                      child: _color == i
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          if (_err != null) ...[
            const SizedBox(height: 18),
            Text(_err!, style: const TextStyle(color: Pal.rose)),
          ],
          const SizedBox(height: 28),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
