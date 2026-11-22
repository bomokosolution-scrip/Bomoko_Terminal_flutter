import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'widgets.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'screens/lock.dart';
import 'screens/splash.dart';
import 'ssh_service.dart';
import 'theme.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await data.load();
    runApp(const BomokoApp());
  }, (e, s) => debugPrint('Erreur non gérée : $e'));
}

class BomokoApp extends StatefulWidget {
  const BomokoApp({super.key});
  @override
  State<BomokoApp> createState() => _BomokoAppState();
}

class _BomokoAppState extends State<BomokoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    hub.ask = _askHostKey;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) data.lockNow();
  }

  Future<bool> _askHostKey(String host, String type, String fp, bool changed) async {
    final ctx = navKey.currentState?.overlay?.context;
    if (ctx == null) return false;
    final r = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dctx) {
        final c = C.of(dctx);
        return AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(changed ? 'Empreinte modifiée' : 'Nouveau serveur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(changed
                  ? 'L\'empreinte de $host a changé depuis votre dernière connexion. Cela peut indiquer une interception. Ne continuez que si vous avez modifié le serveur.'
                  : 'Première connexion à $host. Vérifiez cette empreinte ($type) avant de continuer.'),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(fp,
                    style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11.5)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Refuser')),
            FilledButton(
              onPressed: () => Navigator.pop(dctx, true),
              style: changed ? FilledButton.styleFrom(backgroundColor: Pal.rose) : null,
              child: Text(changed ? 'Continuer quand même' : 'Faire confiance'),
            ),
          ],
        );
      },
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) => MaterialApp(
        navigatorKey: navKey,
        debugShowCheckedModeBanner: false,
        title: 'Bomoko Terminal',
        themeMode: data.themeMode,
        theme: lightTheme,
        darkTheme: darkThemes[data.darkVariant.clamp(0, 2).toInt()],
        builder: (context, child) {
          final dark = Theme.of(context).brightness == Brightness.dark;
          final c = C.of(context);
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
              systemNavigationBarColor: c.bg,
              systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            ),
            child: LangScope(
              lang: data.lang,
              child: Stack(children: [
                child ?? const SizedBox.shrink(),
                if (data.locked) const LockScreen(),
              ]),
            ),
          );
        },
        home: const SplashGate(),
      ),
    );
  }
}
