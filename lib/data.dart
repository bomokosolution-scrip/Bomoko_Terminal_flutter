import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthType { password, key }

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

class Host {
  String id, label, address, username;
  int port;
  AuthType auth;
  String? keyId;
  int color;
  int lastUsed;
  bool favorite;
  String group;
  List<String> tags;
  bool ctrlH; // la touche Suppr envoie Ctrl-H
  String? jumpId; // rebond via un autre hôte
  String? snippetId; // extrait lancé à la connexion
  String env; // variables d'environnement, une par ligne : CLE=valeur
  int palette; // -1 = palette globale
  int charset; // 0 = UTF-8, 1 = Latin-1

  Host({
    required this.id,
    required this.label,
    required this.address,
    required this.username,
    this.port = 22,
    this.auth = AuthType.password,
    this.keyId,
    this.color = 0,
    this.lastUsed = 0,
    this.favorite = false,
    this.group = '',
    this.tags = const [],
    this.ctrlH = false,
    this.jumpId,
    this.snippetId,
    this.env = '',
    this.palette = -1,
    this.charset = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'address': address,
        'username': username,
        'port': port,
        'auth': auth.index,
        'keyId': keyId,
        'color': color,
        'lastUsed': lastUsed,
        'favorite': favorite,
        'group': group,
        'tags': tags,
        'ctrlH': ctrlH,
        'jumpId': jumpId,
        'snippetId': snippetId,
        'env': env,
        'palette': palette,
        'charset': charset,
      };

  factory Host.fromJson(Map<String, dynamic> j) => Host(
        id: j['id'] as String,
        label: j['label'] as String,
        address: j['address'] as String,
        username: j['username'] as String,
        port: (j['port'] as num?)?.toInt() ?? 22,
        auth: AuthType.values[((j['auth'] as num?)?.toInt() ?? 0).clamp(0, 1).toInt()],
        keyId: j['keyId'] as String?,
        color: (j['color'] as num?)?.toInt() ?? 0,
        lastUsed: (j['lastUsed'] as num?)?.toInt() ?? 0,
        favorite: j['favorite'] as bool? ?? false,
        group: j['group'] as String? ?? '',
        tags: ((j['tags'] as List?) ?? const []).map((e) => e.toString()).toList(),
        ctrlH: j['ctrlH'] as bool? ?? false,
        jumpId: j['jumpId'] as String?,
        snippetId: j['snippetId'] as String?,
        env: j['env'] as String? ?? '',
        palette: (j['palette'] as num?)?.toInt() ?? -1,
        charset: (j['charset'] as num?)?.toInt() ?? 0,
      );

  String get target => '$username@$address${port == 22 ? '' : ':$port'}';
}

class Snippet {
  String id, name, command;
  Snippet({required this.id, required this.name, required this.command});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'command': command};
  factory Snippet.fromJson(Map<String, dynamic> j) => Snippet(
      id: j['id'] as String,
      name: j['name'] as String,
      command: j['command'] as String);
}

class KeyEntry {
  String id, name;
  KeyEntry({required this.id, required this.name});
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory KeyEntry.fromJson(Map<String, dynamic> j) =>
      KeyEntry(id: j['id'] as String, name: j['name'] as String);
}

class HistoryEntry {
  String label, address;
  int at;
  bool ok;
  HistoryEntry(
      {required this.label,
      required this.address,
      required this.at,
      required this.ok});
  Map<String, dynamic> toJson() =>
      {'label': label, 'address': address, 'at': at, 'ok': ok};
  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
      label: j['label'] as String,
      address: j['address'] as String,
      at: (j['at'] as num).toInt(),
      ok: j['ok'] as bool? ?? true);
}

class KnownHost {
  String id, type, fingerprint;
  int at;
  KnownHost(
      {required this.id,
      required this.type,
      required this.fingerprint,
      required this.at});
  Map<String, dynamic> toJson() =>
      {'id': id, 'type': type, 'fingerprint': fingerprint, 'at': at};
  factory KnownHost.fromJson(Map<String, dynamic> j) => KnownHost(
      id: j['id'] as String,
      type: j['type'] as String,
      fingerprint: j['fingerprint'] as String,
      at: (j['at'] as num).toInt());
}

class ForwardRule {
  String id, label, hostId, remoteHost;
  int localPort, remotePort;
  ForwardRule({
    required this.id,
    required this.label,
    required this.hostId,
    required this.localPort,
    required this.remoteHost,
    required this.remotePort,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'hostId': hostId,
        'localPort': localPort,
        'remoteHost': remoteHost,
        'remotePort': remotePort,
      };
  factory ForwardRule.fromJson(Map<String, dynamic> j) => ForwardRule(
        id: j['id'] as String,
        label: j['label'] as String,
        hostId: j['hostId'] as String,
        localPort: (j['localPort'] as num).toInt(),
        remoteHost: j['remoteHost'] as String,
        remotePort: (j['remotePort'] as num).toInt(),
      );
}

/// Global application state (persisted).
final AppData data = AppData();

class AppData extends ChangeNotifier {
  static const _sec = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true));
  late SharedPreferences _p;

  List<Host> hosts = [];
  List<Snippet> snippets = [];
  List<KeyEntry> keys = [];
  List<HistoryEntry> history = [];
  List<KnownHost> knownHosts = [];
  List<ForwardRule> rules = [];

  ThemeMode themeMode = ThemeMode.dark;
  int termPalette = 0;
  double fontSize = 14;
  bool haptics = true;
  bool pinEnabled = false;
  bool locked = false;
  String lang = 'fr';
  int darkVariant = 0;
  int bufferLines = 10000;
  int keepAlive = 30; // secondes, 0 = désactivé
  bool bell = true;
  bool wakelock = false;
  String termType = 'xterm-256color';

  List<T> _list<T>(String k, T Function(Map<String, dynamic>) f) {
    final raw = _p.getString(k);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => f(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(String k, List<Map<String, dynamic>> v) =>
      _p.setString(k, jsonEncode(v));

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    hosts = _list('hosts', Host.fromJson);
    snippets = _list('snippets', Snippet.fromJson);
    keys = _list('keys', KeyEntry.fromJson);
    history = _list('history', HistoryEntry.fromJson);
    knownHosts = _list('known', KnownHost.fromJson);
    rules = _list('rules', ForwardRule.fromJson);
    themeMode = ThemeMode.values[(_p.getInt('themeMode') ?? 2).clamp(0, 2).toInt()];
    termPalette = _p.getInt('termPalette') ?? 0;
    fontSize = _p.getDouble('fontSize') ?? 14;
    haptics = _p.getBool('haptics') ?? true;
    pinEnabled = _p.getBool('pinEnabled') ?? false;
    locked = pinEnabled;
    lang = _p.getString('lang') ?? 'fr';
    darkVariant = (_p.getInt('darkVariant') ?? 0).clamp(0, 2).toInt();
    bufferLines = _p.getInt('bufferLines') ?? 10000;
    keepAlive = _p.getInt('keepAlive') ?? 30;
    bell = _p.getBool('bell') ?? true;
    wakelock = _p.getBool('wakelock') ?? false;
    termType = _p.getString('termType') ?? 'xterm-256color';
    if (snippets.isEmpty) {
      snippets = [
        Snippet(id: newId(), name: 'Mises à jour (apt)', command: 'sudo apt update && sudo apt upgrade -y'),
        Snippet(id: '${newId()}1', name: 'Espace disque', command: 'df -h'),
        Snippet(id: '${newId()}2', name: 'Processus gourmands', command: 'top -o %CPU'),
      ];
      await _save('snippets', snippets.map((e) => e.toJson()).toList());
    }
  }

  // ---- secrets (Android Keystore) ----
  Future<String?> secret(String k) => _sec.read(key: k);
  Future<void> setSecret(String k, String v) => _sec.write(key: k, value: v);
  Future<void> delSecret(String k) => _sec.delete(key: k);

  // ---- hosts ----
  Future<void> saveHost(Host h) async {
    final i = hosts.indexWhere((e) => e.id == h.id);
    if (i >= 0) {
      hosts[i] = h;
    } else {
      hosts.add(h);
    }
    await _save('hosts', hosts.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  Future<void> deleteHost(Host h) async {
    hosts.removeWhere((e) => e.id == h.id);
    rules.removeWhere((e) => e.hostId == h.id);
    await delSecret('pw_${h.id}');
    await _save('hosts', hosts.map((e) => e.toJson()).toList());
    await _save('rules', rules.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  Future<void> touchHost(Host h) async {
    h.lastUsed = DateTime.now().millisecondsSinceEpoch;
    await saveHost(h);
  }

  // ---- snippets ----
  Future<void> saveSnippet(Snippet s) async {
    final i = snippets.indexWhere((e) => e.id == s.id);
    if (i >= 0) {
      snippets[i] = s;
    } else {
      snippets.add(s);
    }
    await _save('snippets', snippets.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  Future<void> deleteSnippet(Snippet s) async {
    snippets.removeWhere((e) => e.id == s.id);
    await _save('snippets', snippets.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  // ---- keychain ----
  KeyEntry? keyById(String? id) {
    for (final k in keys) {
      if (k.id == id) return k;
    }
    return null;
  }

  Future<void> addKey(KeyEntry k, String pem, String passphrase) async {
    keys.add(k);
    await setSecret('key_${k.id}', pem);
    await setSecret('kp_${k.id}', passphrase);
    await _save('keys', keys.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  Future<void> deleteKey(KeyEntry k) async {
    keys.removeWhere((e) => e.id == k.id);
    await delSecret('key_${k.id}');
    await delSecret('kp_${k.id}');
    await _save('keys', keys.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  // ---- history ----
  Future<void> addHistory(HistoryEntry e) async {
    history.insert(0, e);
    if (history.length > 200) history = history.sublist(0, 200);
    await _save('history', history.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  Future<void> clearHistory() async {
    history = [];
    await _save('history', []);
    notifyListeners();
  }

  // ---- known hosts ----
  Future<void> saveKnownHost(KnownHost k) async {
    knownHosts.removeWhere((e) => e.id == k.id);
    knownHosts.add(k);
    await _save('known', knownHosts.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  Future<void> deleteKnownHost(KnownHost k) async {
    knownHosts.removeWhere((e) => e.id == k.id);
    await _save('known', knownHosts.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  // ---- port forwarding rules ----
  Future<void> saveRule(ForwardRule r) async {
    rules.removeWhere((e) => e.id == r.id);
    rules.add(r);
    await _save('rules', rules.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  Future<void> deleteRule(ForwardRule r) async {
    rules.removeWhere((e) => e.id == r.id);
    await _save('rules', rules.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  // ---- settings ----
  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    await _p.setInt('themeMode', m.index);
    notifyListeners();
  }

  Future<void> setPalette(int i) async {
    termPalette = i;
    await _p.setInt('termPalette', i);
    notifyListeners();
  }

  Future<void> setFontSize(double v) async {
    fontSize = v;
    await _p.setDouble('fontSize', v);
    notifyListeners();
  }

  Future<void> setHaptics(bool v) async {
    haptics = v;
    await _p.setBool('haptics', v);
    notifyListeners();
  }

  Future<void> setLang(String v) async {
    lang = v;
    await _p.setString('lang', v);
    notifyListeners();
  }

  Future<void> setDarkVariant(int v) async {
    darkVariant = v;
    await _p.setInt('darkVariant', v);
    notifyListeners();
  }

  Future<void> setBufferLines(int v) async {
    bufferLines = v;
    await _p.setInt('bufferLines', v);
    notifyListeners();
  }

  Future<void> setKeepAlive(int v) async {
    keepAlive = v;
    await _p.setInt('keepAlive', v);
    notifyListeners();
  }

  Future<void> setBell(bool v) async {
    bell = v;
    await _p.setBool('bell', v);
    notifyListeners();
  }

  Future<void> setWakelock(bool v) async {
    wakelock = v;
    await _p.setBool('wakelock', v);
    notifyListeners();
  }

  Future<void> setTermType(String v) async {
    termType = v;
    await _p.setString('termType', v);
    notifyListeners();
  }

  List<String> get groups {
    final g = hosts.map((h) => h.group).where((e) => e.isNotEmpty).toSet().toList();
    g.sort();
    return g;
  }

  // ---- PIN lock ----
  Future<void> enablePin(String pin) async {
    await setSecret('pin', pin);
    pinEnabled = true;
    await _p.setBool('pinEnabled', true);
    notifyListeners();
  }

  Future<void> disablePin() async {
    await delSecret('pin');
    pinEnabled = false;
    locked = false;
    await _p.setBool('pinEnabled', false);
    notifyListeners();
  }

  Future<bool> tryUnlock(String pin) async {
    final stored = await secret('pin');
    if (stored == pin) {
      locked = false;
      notifyListeners();
      return true;
    }
    return false;
  }

  void lockNow() {
    if (pinEnabled && !locked) {
      locked = true;
      notifyListeners();
    }
  }
}
