import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'package:flutter/services.dart';
import 'data.dart';
import 'l10n.dart';
import 'theme.dart';

/// Rebuilds every [Text] below it when the language changes.
class LangScope extends InheritedWidget {
  final String lang;
  const LangScope({super.key, required this.lang, required super.child});
  static String of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<LangScope>()?.lang ?? 'fr';
  @override
  bool updateShouldNotify(LangScope old) => old.lang != lang;
}

/// Drop-in replacement for Flutter's Text: translates its content (see l10n.dart).
class Text extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  const Text(this.data, {super.key, this.style, this.textAlign, this.maxLines, this.overflow});

  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    return m.Text(tr(data), style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow);
  }
}

void tap() {
  if (data.haptics) HapticFeedback.selectionClick();
}

/// Scales down slightly while pressed.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              tap();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Rounded gradient tile holding an icon: the "image" of each menu entry.
class GradTile extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final double size;
  const GradTile({super.key, required this.icon, required this.colors, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(0.35),
            blurRadius: size * 0.32,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size * 0.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(size * 0.32)),
                gradient: LinearGradient(
                  colors: [Colors.white.withOpacity(0.28), Colors.white.withOpacity(0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Icon(icon, color: Colors.white, size: size * 0.5),
        ],
      ),
    );
  }
}

/// Surface card used for lists.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(14)});
  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.line),
      ),
      child: child,
    );
  }
}

/// Large screen title with a soft aurora glow behind it.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const ScreenHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    final t = Theme.of(context).textTheme;
    return Stack(
      children: [
        Positioned(
          left: -60,
          top: -90,
          child: IgnorePointer(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Pal.violet.withOpacity(0.28),
                  Pal.violet.withOpacity(0),
                ]),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle!, style: t.bodyMedium?.copyWith(color: c.muted)),
                      ),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ],
    );
  }
}

/// Fades and lifts a child in, used once for the first rows of a list.
class Enter extends StatelessWidget {
  final int index;
  final Widget child;
  const Enter({super.key, required this.index, required this.child});
  @override
  Widget build(BuildContext context) {
    if (index > 7) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (_, v, w) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: w),
      ),
      child: child,
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title, text;
  final String? action;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.title, required this.text, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 150, height: 130, child: CustomPaint(painter: ServerPainter(c))),
            const SizedBox(height: 18),
            Text(title, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(text, style: t.bodyMedium?.copyWith(color: c.muted), textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Little illustration of a server rack.
class ServerPainter extends CustomPainter {
  final C c;
  ServerPainter(this.c);
  @override
  void paint(Canvas canvas, Size s) {
    final glow = Paint()
      ..shader = RadialGradient(colors: [Pal.violet.withOpacity(0.35), Pal.violet.withOpacity(0)])
          .createShader(Rect.fromCircle(center: s.center(Offset.zero), radius: s.width * 0.6));
    canvas.drawCircle(s.center(Offset.zero), s.width * 0.6, glow);
    for (var i = 0; i < 3; i++) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.14 + i * 4, s.height * (0.12 + i * 0.28), s.width * 0.72, s.height * 0.22),
        const Radius.circular(12),
      );
      canvas.drawRRect(r, Paint()..color = c.surface2);
      canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..shader = Pal.aurora.createShader(r.outerRect),
      );
      final y = r.center.dy;
      canvas.drawCircle(Offset(r.left + 16, y), 3.5, Paint()..color = i == 0 ? Pal.mint : Pal.amber);
      canvas.drawCircle(Offset(r.left + 30, y), 3.5, Paint()..color = c.muted.withOpacity(0.6));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(r.right - 56, y - 2.5, 40, 5),
          const Radius.circular(3),
        ),
        Paint()..color = c.muted.withOpacity(0.35),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ServerPainter old) => old.c != c;
}

/// Pulsing prompt mark shown while connecting.
class Pulse extends StatefulWidget {
  final Widget child;
  const Pulse({super.key, required this.child});
  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, w) => Transform.scale(
        scale: 0.92 + 0.12 * math.sin(_c.value * math.pi),
        child: Opacity(opacity: 0.65 + 0.35 * _c.value, child: w),
      ),
      child: widget.child,
    );
  }
}

void toast(BuildContext context, String msg, {bool error = false}) {
  final c = C.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFF3A1521) : c.surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Text(msg, style: TextStyle(color: error ? Pal.rose : c.text)),
    ));
}

String fmtDate(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
}

InputDecoration fieldDeco(BuildContext context, String label, {String? hint, Widget? suffix}) {
  final c = C.of(context);
  OutlineInputBorder b(Color col, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: col, width: w),
      );
  return InputDecoration(
    labelText: tr(label),
    hintText: hint == null ? null : tr(hint),
    suffixIcon: suffix,
    filled: true,
    fillColor: c.surface,
    labelStyle: TextStyle(color: c.muted),
    enabledBorder: b(c.line),
    focusedBorder: b(Pal.violet, 1.6),
    border: b(c.line),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );
}

/// Standard sub page with a large title.
class SubPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final Widget? fab;
  const SubPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.fab,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: fab,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.maybePop(context),
                ),
                const Spacer(),
                ...actions,
              ]),
            ),
            ScreenHeader(title: title, subtitle: subtitle),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirm(BuildContext context, String title, String text, {String ok = 'Supprimer'}) async {
  final c = C.of(context);
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: Pal.rose),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}
