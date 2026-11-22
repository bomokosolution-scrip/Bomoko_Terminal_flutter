import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import '../widgets.dart';
import 'package:flutter/services.dart';
import '../data.dart';
import '../theme.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  String _pin = '';
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _press(String d) async {
    if (_pin.length >= 6) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += d);
    if (_pin.length >= 4) {
      final ok = await data.tryUnlock(_pin);
      if (!ok && _pin.length >= 6 && mounted) {
        HapticFeedback.heavyImpact();
        _shake.forward(from: 0);
        setState(() => _pin = '');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return Material(
      color: c.bg,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset('assets/icon/icon.png', width: 76, height: 76),
            ),
            const SizedBox(height: 18),
            Text('Bomoko Terminal',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Saisissez votre code PIN', style: TextStyle(color: c.muted)),
            const SizedBox(height: 26),
            AnimatedBuilder(
              animation: _shake,
              builder: (_, child) => Transform.translate(
                offset: Offset(math.sin(_shake.value * math.pi * 6) * 12 * (1 - _shake.value), 0),
                child: child,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) {
                  final on = i < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    width: on ? 14 : 12,
                    height: on ? 14 : 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: on ? Pal.aurora : null,
                      color: on ? null : c.surface2,
                    ),
                  );
                }),
              ),
            ),
            const Spacer(),
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['', '0', '<'],
            ])
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final k in row)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: k.isEmpty
                          ? const SizedBox(width: 76, height: 76)
                          : InkResponse(
                              onTap: () {
                                if (k == '<') {
                                  if (_pin.isNotEmpty) {
                                    setState(() => _pin = _pin.substring(0, _pin.length - 1));
                                  }
                                } else {
                                  _press(k);
                                }
                              },
                              radius: 44,
                              child: Container(
                                width: 76,
                                height: 76,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: k == '<' ? Colors.transparent : c.surface,
                                  border: k == '<' ? null : Border.all(color: c.line),
                                ),
                                child: k == '<'
                                    ? Icon(Icons.backspace_outlined, color: c.muted)
                                    : Text(k, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500)),
                              ),
                            ),
                    ),
                ],
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
