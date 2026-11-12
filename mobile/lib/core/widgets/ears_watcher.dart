import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/tr.dart';
import '../services/airpods_service.dart';
import '../services/hands_free.dart';

/// Durante la sesión: si te quitas los AirPods (los dos), el manos libres se pausa a los 2 s;
/// al volver a ponértelos, sigue solo. Solo si activaste la opción en Progreso (Android).
class EarsWatcher extends ConsumerStatefulWidget {
  const EarsWatcher({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<EarsWatcher> createState() => _EarsWatcherState();
}

class _EarsWatcherState extends ConsumerState<EarsWatcher> {
  Timer? _out;
  bool _pausedByUs = false;

  @override
  void dispose() {
    _out?.cancel();
    super.dispose();
  }

  void _say(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _onEars(EarState e) {
    final hf = ref.read(handsFreeProvider.notifier);
    if (!e.inEar) {
      if (!ref.read(handsFreeProvider).on || _out != null) return;
      _out = Timer(const Duration(seconds: 2), () {
        _out = null;
        if (!mounted || !ref.read(handsFreeProvider).on) return;
        hf.pause();
        _pausedByUs = true;
        _say(tr('Te quitaste los AirPods: manos libres en pausa. Póntelos para seguir.'));
      });
    } else {
      _out?.cancel();
      _out = null;
      if (_pausedByUs && !ref.read(handsFreeProvider).on) {
        _pausedByUs = false;
        hf.setOn(true);
        _say(tr('¡Seguimos!'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(airPodsEarsSettingProvider)) {
      ref.listen<AsyncValue<EarState>>(airPodsEarsProvider, (_, next) {
        final e = next.valueOrNull;
        if (e != null) _onEars(e);
      });
    }
    return widget.child;
  }
}
