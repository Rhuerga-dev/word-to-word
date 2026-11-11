import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../core/l10n/tr.dart';

/// Botón grande de micrófono.
class MicButton extends StatelessWidget {
  const MicButton({super.key, required this.recording, required this.onPressed});
  final bool recording;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          button: true,
          label: recording ? 'Grabando' : tr('Hablar'),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: recording ? W.bad : W.accent,
                boxShadow: [BoxShadow(color: (recording ? W.bad : W.accent).withValues(alpha: .18), spreadRadius: 10)],
              ),
              child: Icon(recording ? Icons.graphic_eq : Icons.mic, color: Colors.white, size: 40),
            ),
          ),
        ),
      );
}
