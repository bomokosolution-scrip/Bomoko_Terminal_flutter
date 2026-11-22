import 'package:flutter/material.dart' hide Text;
import '../ssh_service.dart';
import '../theme.dart';
import '../widgets.dart';
import 'hosts.dart';
import 'more.dart';
import 'sessions.dart';
import 'sftp.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 280), value: 1);

  void _go(int i) {
    if (i == _index) return;
    tap();
    setState(() => _index = i);
    _anim.forward(from: 0);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.015), end: Offset.zero).animate(curved),
            child: IndexedStack(
              index: _index,
              children: [
                const HostsScreen(),
                SessionsScreen(onGoHosts: () => _go(0)),
                const SftpScreen(),
                const MoreScreen(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: ListenableBuilder(
          listenable: hub,
          builder: (_, __) => _NavBar(index: _index, onChange: _go, badge: hub.liveCount),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int index, badge;
  final ValueChanged<int> onChange;
  const _NavBar({required this.index, required this.onChange, required this.badge});

  static const _items = [
    (Icons.dns_rounded, 'Hôtes'),
    (Icons.terminal_rounded, 'Terminaux'),
    (Icons.folder_rounded, 'SFTP'),
    (Icons.apps_rounded, 'Plus'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final active = dark ? const Color(0xFFBFB0FF) : Pal.violet;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      height: 68,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: c.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.35 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth / _items.length;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 340),
              curve: Curves.easeOutBack,
              left: index * w,
              top: 0,
              bottom: 0,
              width: w,
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Pal.violet.withOpacity(dark ? 0.20 : 0.12),
                    border: Border.all(color: Pal.violet.withOpacity(0.35)),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: InkResponse(
                      onTap: () => onChange(i),
                      radius: 40,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedScale(
                                scale: i == index ? 1.12 : 1,
                                duration: const Duration(milliseconds: 250),
                                child: Icon(_items[i].$1,
                                    size: 24, color: i == index ? active : c.muted),
                              ),
                              if (i == 1 && badge > 0)
                                Positioned(
                                  right: -9,
                                  top: -6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Pal.rose,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text('$badge',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(_items[i].$2,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: i == index ? active : c.muted)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}
