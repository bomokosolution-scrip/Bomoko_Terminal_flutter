import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart' hide Text;

import '../data.dart';
import '../l10n.dart';
import '../ssh_service.dart';
import '../theme.dart';
import '../widgets.dart';

class _Entry {
  final String name;
  final bool dir;
  final int size;
  _Entry(this.name, this.dir, this.size);
}

class SftpScreen extends StatefulWidget {
  const SftpScreen({super.key});
  @override
  State<SftpScreen> createState() => _SftpScreenState();
}

class _SftpScreenState extends State<SftpScreen> {
  Host? _host;
  SSHClient? _client;
  SftpClient? _sftp;
  String _path = '/';
  List<_Entry> _entries = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  Future<void> _open(Host h) async {
    setState(() {
      _host = h;
      _loading = true;
      _error = null;
    });
    try {
      final c = await hub.openClient(h);
      final sftp = await c.sftp();
      String start = '/';
      try {
        start = await sftp.absolute('.');
      } catch (_) {}
      _client = c;
      _sftp = sftp;
      await _list(start);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
        _host = null;
      });
    }
  }

  Future<void> _list(String path) async {
    final sftp = _sftp;
    if (sftp == null) return;
    setState(() => _loading = true);
    try {
      final items = await sftp.listdir(path);
      final l = <_Entry>[];
      for (final i in items) {
        if (i.filename == '.' || i.filename == '..') continue;
        l.add(_Entry(i.filename, i.longname.startsWith('d'), i.attr.size ?? 0));
      }
      l.sort((a, b) {
        if (a.dir != b.dir) return a.dir ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      if (!mounted) return;
      setState(() {
        _path = path;
        _entries = l;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      toast(context, friendlyError(e), error: true);
    }
  }

  String _join(String a, String b) => a.endsWith('/') ? '$a$b' : '$a/$b';

  String _parent(String p) {
    if (p == '/' || p.isEmpty) return '/';
    final i = p.lastIndexOf('/');
    return i <= 0 ? '/' : p.substring(0, i);
  }

  void _disconnect() {
    _client?.close();
    setState(() {
      _client = null;
      _sftp = null;
      _host = null;
      _entries = [];
    });
  }

  String _size(int b) {
    if (b < 1024) return '$b o';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} Ko';
    if (b < 1024 * 1024 * 1024) return '${(b / 1048576).toStringAsFixed(1)} Mo';
    return '${(b / 1073741824).toStringAsFixed(1)} Go';
  }

  Future<String?> _ask(String title, {String initial = ''}) async {
    final ctl = TextEditingController(text: initial);
    final c = C.of(context);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title),
        content: TextField(controller: ctl, autofocus: true, decoration: fieldDeco(ctx, 'Nom')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('Valider')),
        ],
      ),
    );
    return (r == null || r.isEmpty) ? null : r;
  }

  Future<void> _mkdir() async {
    final n = await _ask('Nouveau dossier');
    if (n == null) return;
    try {
      await _sftp!.mkdir(_join(_path, n));
      await _list(_path);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _rename(_Entry e) async {
    final n = await _ask('Renommer', initial: e.name);
    if (n == null || n == e.name) return;
    try {
      await _sftp!.rename(_join(_path, e.name), _join(_path, n));
      await _list(_path);
    } catch (err) {
      if (mounted) toast(context, friendlyError(err), error: true);
    }
  }

  Future<void> _delete(_Entry e) async {
    if (!await confirm(context, 'Supprimer ?', '« ${e.name} » sera supprimé du serveur.')) return;
    try {
      final p = _join(_path, e.name);
      if (e.dir) {
        await _sftp!.rmdir(p);
      } else {
        await _sftp!.remove(p);
      }
      await _list(_path);
    } catch (err) {
      if (mounted) toast(context, friendlyError(err), error: true);
    }
  }

  Future<void> _preview(_Entry e) async {
    try {
      final f = await _sftp!.open(_join(_path, e.name));
      final bytes = await f.readBytes(length: 32768);
      await f.close();
      if (!mounted) return;
      final c = C.of(context);
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: c.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (_, sc) => ListView(
            controller: sc,
            padding: const EdgeInsets.all(20),
            children: [
              Text(e.name, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Aperçu des 32 premiers Ko', style: TextStyle(color: c.muted, fontSize: 12)),
              const SizedBox(height: 14),
              SelectableText(
                utf8.decode(bytes, allowMalformed: true),
                style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12.5, height: 1.4),
              ),
            ],
          ),
        ),
      );
    } catch (err) {
      if (mounted) toast(context, friendlyError(err), error: true);
    }
  }

  // ------------------------------------------------------------ transferts

  String? _tLabel;
  double _tValue = 0;
  bool _tUp = false;

  Future<void> _run(String label, bool up,
      Future<void> Function(void Function(double) progress) body) async {
    setState(() {
      _tLabel = label;
      _tValue = 0;
      _tUp = up;
    });
    try {
      await body((v) {
        final nv = v.clamp(0.0, 1.0).toDouble();
        if (mounted && ((nv - _tValue).abs() >= 0.01 || nv >= 1)) setState(() => _tValue = nv);
      });
    } finally {
      if (mounted) setState(() => _tLabel = null);
    }
  }

  Future<void> _upload() async {
    final r = await FilePicker.platform.pickFiles(allowMultiple: true, withReadStream: true);
    if (r == null || _sftp == null) return;
    var done = 0;
    for (final f in r.files) {
      final stream = f.readStream;
      if (stream == null) continue;
      final remote = _join(_path, f.name);
      try {
        await _run(f.name, true, (progress) async {
          final file = await _sftp!.open(
            remote,
            mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
          );
          var sent = 0;
          final counted = stream.map((chunk) {
            sent += chunk.length;
            if (f.size > 0) progress(sent / f.size);
            return Uint8List.fromList(chunk);
          });
          await file.write(counted);
          await file.close();
        });
        done++;
      } catch (e) {
        if (mounted) toast(context, 'Échec de l\'envoi de ${f.name} : ${friendlyError(e)}', error: true);
      }
    }
    if (done > 0 && mounted) toast(context, done == 1 ? 'Fichier envoyé' : '$done fichiers envoyés');
    await _list(_path);
  }

  Future<void> _download(_Entry e) async {
    final sftp = _sftp;
    if (sftp == null) return;
    final tmpDir = await getTemporaryDirectory();
    final tmp = File('${tmpDir.path}/${e.name.replaceAll('/', '_')}');
    try {
      await _run(e.name, false, (progress) async {
        final f = await sftp.open(_join(_path, e.name));
        final sink = tmp.openWrite();
        var got = 0;
        try {
          await for (final chunk in f.read()) {
            sink.add(chunk);
            got += chunk.length;
            if (e.size > 0) progress(got / e.size);
          }
        } finally {
          await sink.close();
          await f.close();
        }
      });
      final len = await tmp.length();
      if (len <= 80 * 1024 * 1024) {
        final saved = await FilePicker.platform.saveFile(
          dialogTitle: tr('Enregistrer le fichier'),
          fileName: e.name,
          bytes: await tmp.readAsBytes(),
        );
        if (saved != null && mounted) toast(context, 'Fichier enregistré');
      } else {
        final dir = await getExternalStorageDirectory();
        if (dir != null) {
          final dest = '${dir.path}/${e.name}';
          await tmp.copy(dest);
          if (mounted) toast(context, 'Fichier volumineux enregistré dans : $dest');
        }
      }
    } catch (err) {
      if (mounted) toast(context, friendlyError(err), error: true);
    } finally {
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
    }
  }

  void _fabMenu() {
    final c = C.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: GradTile(icon: Icons.upload_file_rounded, colors: kGrads[0], size: 42),
              title: const Text('Envoyer des fichiers'),
              subtitle: const Text('Du téléphone vers ce dossier'),
              onTap: () {
                Navigator.pop(ctx);
                _upload();
              },
            ),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: GradTile(icon: Icons.create_new_folder_rounded, colors: kGrads[4], size: 42),
              title: const Text('Nouveau dossier'),
              onTap: () {
                Navigator.pop(ctx);
                _mkdir();
              },
            ),
          ]),
        ),
      ),
    );
  }

  Widget _transferBar(C c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Panel(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(_tUp ? Icons.upload_rounded : Icons.download_rounded, size: 18, color: Pal.cyan),
            const SizedBox(width: 8),
            Expanded(child: Text(_tLabel ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text('${(_tValue * 100).round()} %', style: TextStyle(color: c.muted, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: _tValue, minHeight: 6),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        if (_sftp == null && !_loading) return _picker(c, t);
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: _sftp == null
              ? null
              : FloatingActionButton(
                  onPressed: _fabMenu,
                  backgroundColor: Pal.violet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.add_rounded),
                ),
          body: Column(
            children: [
              ScreenHeader(
                title: 'SFTP',
                subtitle: _host?.label,
                actions: [
                  if (_sftp != null) ...[
                    IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => _list(_path)),
                    IconButton(icon: const Icon(Icons.link_off_rounded), onPressed: _disconnect),
                  ],
                ],
              ),
              if (_sftp != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(children: [
                    IconButton.filledTonal(
                      onPressed: _path == '/' ? null : () => _list(_parent(_path)),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.line),
                        ),
                        child: Text(_path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12.5)),
                      ),
                    ),
                  ]),
                ),
              if (_tLabel != null) _transferBar(c),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _entries.isEmpty
                        ? Center(child: Text('Dossier vide', style: TextStyle(color: c.muted)))
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 90),
                            itemCount: _entries.length,
                            itemBuilder: (_, i) {
                              final e = _entries[i];
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child: Pressable(
                                  onTap: () => e.dir ? _list(_join(_path, e.name)) : _preview(e),
                                  child: Panel(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Row(children: [
                                      GradTile(
                                        icon: e.dir ? Icons.folder_rounded : Icons.description_rounded,
                                        colors: e.dir ? kGrads[4] : kGrads[7],
                                        size: 40,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(e.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                                            if (!e.dir)
                                              Text(_size(e.size),
                                                  style: TextStyle(color: c.muted, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: Icon(Icons.more_vert_rounded, color: c.muted),
                                        color: c.surface2,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        onSelected: (a) {
                                          if (a == 'dl') {
                                            _download(e);
                                          } else if (a == 'ren') {
                                            _rename(e);
                                          } else {
                                            _delete(e);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          if (!e.dir)
                                            const PopupMenuItem(value: 'dl', child: Text('Télécharger')),
                                          const PopupMenuItem(value: 'ren', child: Text('Renommer')),
                                          const PopupMenuItem(value: 'del', child: Text('Supprimer')),
                                        ],
                                      ),
                                    ]),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _picker(C c, TextTheme t) {
    return Column(
      children: [
        const ScreenHeader(title: 'SFTP', subtitle: 'Parcourez les fichiers de vos serveurs'),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Panel(child: Text(_error!, style: const TextStyle(color: Pal.rose))),
          ),
        Expanded(
          child: data.hosts.isEmpty
              ? const EmptyState(
                  title: 'Aucun hôte', text: 'Ajoutez un hôte dans l\'onglet Hôtes pour explorer ses fichiers.')
              : ListView.builder(
                  itemCount: data.hosts.length,
                  itemBuilder: (_, i) {
                    final h = data.hosts[i];
                    return Enter(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Pressable(
                          onTap: () => _open(h),
                          child: Panel(
                            child: Row(children: [
                              GradTile(icon: Icons.folder_open_rounded, colors: kGrads[h.color % kGrads.length]),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(h.label,
                                        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                    Text('${h.username}@${h.address}',
                                        style: TextStyle(color: c.muted, fontSize: 12.5)),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: c.muted),
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
  }
}
