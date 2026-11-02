// قفل اپ با رمز عددی (در شروع و پس از مدتی در پس‌زمینه).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/fa.dart';
import '../../data/app_state.dart';

class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _locked = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<AppState>();
      if (widget.enabled && s.hasPin) setState(() => _locked = true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final p = _pausedAt;
      _pausedAt = null;
      if (p != null && DateTime.now().difference(p) > const Duration(seconds: 45) && context.read<AppState>().hasPin) {
        setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: _PinScreen(onUnlocked: () => setState(() => _locked = false)),
          ),
      ],
    );
  }
}

class _PinScreen extends StatefulWidget {
  const _PinScreen({required this.onUnlocked});
  final VoidCallback onUnlocked;
  @override
  State<_PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<_PinScreen> {
  String _pin = '';
  bool _error = false;

  void _press(String d) {
    HapticFeedback.selectionClick();
    setState(() {
      _error = false;
      if (_pin.length < 8) _pin += d;
    });
    if (_pin.length >= 4 && context.read<AppState>().store.checkPin(_pin)) {
      widget.onUnlocked();
    }
  }

  void _submit() {
    if (context.read<AppState>().store.checkPin(_pin)) {
      widget.onUnlocked();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = true;
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(Icons.lock_outline, size: 40, color: scheme.primary),
            const SizedBox(height: 12),
            Text('رمز اپ را وارد کنید', style: text.titleMedium),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 8; i++)
                  if (i < 4 || i < _pin.length)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _pin.length ? (_error ? scheme.error : scheme.primary) : Colors.transparent,
                        border: Border.all(color: _error ? scheme.error : scheme.primary, width: 1.5),
                      ),
                    ),
              ],
            ),
            SizedBox(
              height: 24,
              child: _error ? Center(child: Text('رمز اشتباه است', style: text.labelMedium?.copyWith(color: scheme.error))) : null,
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              child: Column(
                children: [
                  for (final row in [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['⌫', '0', '✓']])
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final k in row)
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Material(
                              color: k == '✓' ? scheme.primary : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  if (k == '⌫') {
                                    setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1));
                                  } else if (k == '✓') {
                                    _submit();
                                  } else {
                                    _press(k);
                                  }
                                },
                                child: SizedBox(
                                  width: 70,
                                  height: 70,
                                  child: Center(
                                    child: k == '⌫'
                                        ? const Icon(Icons.backspace_outlined)
                                        : k == '✓'
                                            ? Icon(Icons.check, color: scheme.onPrimary)
                                            : Text(faDigits(k), style: text.headlineSmall),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
