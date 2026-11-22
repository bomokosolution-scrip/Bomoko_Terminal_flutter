import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import 'data.dart';

typedef HostKeyAsk = Future<bool> Function(
    String host, String type, String fingerprint, bool changed);

class SshError implements Exception {
  final String message;
  SshError(this.message);
  @override
  String toString() => message;
}

/// Turns low level exceptions into short French messages.
String friendlyError(Object e) {
  if (e is SshError) return e.message;
  if (e is SocketException) return 'Hôte injoignable. Vérifiez l\'adresse, le port et votre connexion.';
  if (e is TimeoutException) return 'Délai dépassé. Le serveur ne répond pas.';
  final name = e.runtimeType.toString();
  if (name.contains('AuthFail') || name.contains('AuthAbort')) {
    return 'Authentification refusée. Vérifiez l\'utilisateur et le mot de passe ou la clé.';
  }
  if (name.contains('Hostkey')) return 'Empreinte du serveur refusée.';
  final s = e.toString();
  return s.length > 160 ? '${s.substring(0, 160)}…' : s;
}

enum SessionStatus { connecting, connected, closed, failed }

class SshSession extends ChangeNotifier {
  SshSession(this.host);

  final Host host;
  final String id = newId();
  final DateTime startedAt = DateTime.now();
  final Terminal terminal = Terminal(maxLines: data.bufferLines);
  final TerminalController controller = TerminalController();
  final ValueNotifier<bool> ctrl = ValueNotifier(false);

  SSHClient? client;
  SSHSession? shell;
  SessionStatus status = SessionStatus.connecting;
  String? error;

  bool get isLive => status == SessionStatus.connecting || status == SessionStatus.connected;

  void _set(SessionStatus s, {String? err}) {
    status = s;
    error = err;
    notifyListeners();
  }

  Uint8List _enc(String s) => host.charset == 1
      ? Uint8List.fromList(s.codeUnits.map((c) => c < 256 ? c : 63).toList())
      : Uint8List.fromList(utf8.encode(s));

  Future<void> connect() async {
    _set(SessionStatus.connecting);
    try {
      final c = await hub.openClient(host);
      client = c;

      final env = <String, String>{};
      for (final line in host.env.split('\n')) {
        final i = line.indexOf('=');
        if (i > 0) env[line.substring(0, i).trim()] = line.substring(i + 1).trim();
      }
      final sh = await c.shell(
        pty: SSHPtyConfig(
          type: data.termType,
          width: terminal.viewWidth,
          height: terminal.viewHeight,
        ),
        environment: env.isEmpty ? null : env,
      );
      shell = sh;

      final Converter<List<int>, String> dec = host.charset == 1
          ? const Latin1Decoder(allowInvalid: true)
          : const Utf8Decoder(allowMalformed: true);
      sh.stdout.cast<List<int>>().transform(dec).listen(terminal.write);
      sh.stderr.cast<List<int>>().transform(dec).listen(terminal.write);

      terminal.onOutput = (d) {
        var out = d;
        if (ctrl.value && out.length == 1) {
          final u = out.toUpperCase().codeUnitAt(0);
          if (u >= 64 && u <= 95) out = String.fromCharCode(u - 64);
          ctrl.value = false;
        }
        if (host.ctrlH && out == '\x7f') out = '\x08';
        sh.write(_enc(out));
      };
      terminal.onResize = (w, h, pw, ph) => sh.resizeTerminal(w, h);
      terminal.onBell = () {
        if (data.bell) HapticFeedback.mediumImpact();
      };

      sh.done.then((_) {
        if (shell == sh) {
          terminal.write('\r\n\x1b[90mSession terminée.\x1b[0m\r\n');
          _set(SessionStatus.closed);
        }
      });
      _set(SessionStatus.connected);
      data.addHistory(HistoryEntry(
        label: host.label,
        address: host.target,
        at: DateTime.now().millisecondsSinceEpoch,
        ok: true,
      ));

      // Extrait lancé automatiquement à la connexion.
      if (host.snippetId != null) {
        for (final sn in data.snippets) {
          if (sn.id == host.snippetId) {
            Future.delayed(const Duration(milliseconds: 600), () => sendText('${sn.command}\r'));
          }
        }
      }
    } catch (e) {
      final msg = friendlyError(e);
      data.addHistory(HistoryEntry(
        label: host.label,
        address: host.target,
        at: DateTime.now().millisecondsSinceEpoch,
        ok: false,
      ));
      _set(SessionStatus.failed, err: msg);
    }
  }

  void sendText(String text) {
    if (status == SessionStatus.connected) terminal.textInput(text);
  }

  void close() {
    final sh = shell;
    shell = null;
    try {
      sh?.close();
      client?.close();
    } catch (_) {}
    if (status != SessionStatus.failed) status = SessionStatus.closed;
    notifyListeners();
  }
}

class ActiveForward {
  final ServerSocket server;
  final SSHClient client;
  int connections = 0;
  ActiveForward(this.server, this.client);
}

final SshHub hub = SshHub();

class SshHub extends ChangeNotifier {
  final List<SshSession> sessions = [];
  final Map<String, ActiveForward> forwards = {};
  HostKeyAsk? ask;

  /// Mots de passe d'hôtes éphémères (connexion rapide), jamais enregistrés.
  final Map<String, String> tempPw = {};

  Future<SSHClient> openClient(Host h, {int depth = 0}) async {
    SSHClient? jump;
    SSHSocket socket;
    final jumpId = h.jumpId;
    if (jumpId != null && jumpId.isNotEmpty && depth < 3) {
      Host? j;
      for (final x in data.hosts) {
        if (x.id == jumpId) j = x;
      }
      if (j == null) throw SshError('Hôte de rebond introuvable.');
      jump = await openClient(j, depth: depth + 1);
      try {
        socket = await jump.forwardLocal(h.address, h.port);
      } catch (e) {
        jump.close();
        rethrow;
      }
    } else {
      socket = await SSHSocket.connect(h.address, h.port,
          timeout: const Duration(seconds: 12));
    }
    try {
      List<SSHKeyPair>? ids;
      String pw = '';
      if (h.auth == AuthType.key) {
        final pem = await data.secret('key_${h.keyId}');
        if (pem == null) {
          throw SshError('Clé introuvable. Ajoutez-la dans le Trousseau.');
        }
        final pass = await data.secret('kp_${h.keyId}');
        ids = SSHKeyPair.fromPem(pem, (pass == null || pass.isEmpty) ? null : pass);
      } else {
        pw = tempPw[h.id] ?? await data.secret('pw_${h.id}') ?? '';
      }
      final client = SSHClient(
        socket,
        username: h.username,
        identities: ids,
        onPasswordRequest: h.auth == AuthType.password ? () => pw : null,
        onVerifyHostKey: (type, fp) => _verify(h, type, fp),
        keepAliveInterval: data.keepAlive > 0 ? Duration(seconds: data.keepAlive) : null,
      );
      await client.authenticated;
      final jc = jump;
      if (jc != null) client.done.then((_) => jc.close()).catchError((_) {});
      return client;
    } catch (e) {
      socket.destroy();
      jump?.close();
      rethrow;
    }
  }

  Future<bool> _verify(Host h, String type, Uint8List fp) async {
    final id = '${h.address}:${h.port}';
    final hex = fp.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
    KnownHost? known;
    for (final k in data.knownHosts) {
      if (k.id == id) known = k;
    }
    if (known != null && known.fingerprint == hex) return true;
    final ok = ask == null ? true : await ask!(id, type, hex, known != null);
    if (ok) {
      await data.saveKnownHost(KnownHost(
        id: id,
        type: type,
        fingerprint: hex,
        at: DateTime.now().millisecondsSinceEpoch,
      ));
    }
    return ok;
  }

  SshSession open(Host h) {
    final s = SshSession(h);
    sessions.insert(0, s);
    s.addListener(notifyListeners);
    s.connect();
    notifyListeners();
    return s;
  }

  void remove(SshSession s) {
    s.close();
    s.removeListener(notifyListeners);
    sessions.remove(s);
    notifyListeners();
  }

  int get liveCount => sessions.where((s) => s.isLive).length;

  bool isConnected(Host h) =>
      sessions.any((s) => s.host.id == h.id && s.status == SessionStatus.connected);

  // ---------------------------------------------------------- forwarding

  bool isForwarding(String ruleId) => forwards.containsKey(ruleId);

  Future<void> startForward(ForwardRule r) async {
    Host? host;
    for (final h in data.hosts) {
      if (h.id == r.hostId) host = h;
    }
    if (host == null) throw SshError('Hôte introuvable pour cette règle.');
    final client = await openClient(host);
    ServerSocket server;
    try {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, r.localPort);
    } catch (_) {
      client.close();
      throw SshError('Le port local ${r.localPort} est déjà utilisé.');
    }
    final active = ActiveForward(server, client);
    forwards[r.id] = active;
    server.listen((sock) async {
      try {
        final ch = await client.forwardLocal(r.remoteHost, r.remotePort);
        active.connections++;
        notifyListeners();
        ch.stream.cast<List<int>>().pipe(sock).catchError((_) {});
        sock.cast<List<int>>().pipe(ch.sink).catchError((_) {});
      } catch (_) {
        sock.destroy();
      }
    });
    client.done.then((_) => stopForward(r.id)).catchError((_) {});
    notifyListeners();
  }

  Future<void> stopForward(String ruleId) async {
    final a = forwards.remove(ruleId);
    if (a == null) return;
    try {
      await a.server.close();
      a.client.close();
    } catch (_) {}
    notifyListeners();
  }
}
