import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../theme.dart';
import 'session_screen.dart';

/// Practicar: elige tú qué hacer. Todo suma puntos.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});
  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  List<Map>? _mistakes;
  List<Map>? _cards;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<Api>();
    try {
      final r = await Future.wait([api.get('/speaking/mistakes'), api.get('/today')]);
      if (!mounted) return;
      setState(() {
        _mistakes = ((r[0] as Map)['mistakes'] as List).cast<Map>();
        _cards = ((r[1] as Map)['cards'] as List).cast<Map>();
      });
    } catch (_) {
      if (mounted) setState(() => _mistakes ??= const []);
    }
  }

  Future<void> _run(List<SessionStep> steps, String title) async {
    if (steps.isEmpty) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionScreen(plan: SessionPlan(steps, title: title, daily: false)), fullscreenDialog: true));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final m = _mistakes ?? const [], cards = _cards ?? const [];
    final ph = const ['θ', 'v', 'ɪ', 'æ', 'z'][DateTime.now().day % 5];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
        Text('Practicar', style: W.display(26)),
        const Text('Elige tú qué hacer. Todo suma puntos a tu meta.', style: TextStyle(color: W.muted)),
        const SizedBox(height: 14),
        if (m.isNotEmpty)
          Card(
            color: const Color(0xFFFFF7EC),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFF3D7B2))),
            child: ListTile(
              leading: const Icon(Icons.replay, color: Color(0xFFA85A00)),
              title: Text('${m.length} ${m.length == 1 ? 'error' : 'errores'} para repasar', style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Text('Repasar', style: TextStyle(color: W.accent, fontWeight: FontWeight.w700)),
              onTap: () => _run([for (final x in m) MistakeStep(x)], 'Errores'),
            ),
          ),
        const SizedBox(height: 8),
        _label('Hablar'),
        _tile(Icons.timer_outlined, 'Narración', '1 minuto sin parar', () => _run([NarrateStep()], 'Narración')),
        _label('Palabras y sonidos'),
        _tile(Icons.style_outlined, 'Fichas', cards.isEmpty ? 'nada pendiente hoy' : '${cards.length} para hoy',
            cards.isEmpty ? null : () => _run([for (final c in cards) c['mode'] == 'new' ? NewStep(c) : ReviewStep(c)], 'Fichas')),
        _tile(Icons.track_changes, 'Pronunciación', '/$ph/ · ${soundWords[ph]!.join(', ')}', () => _run([for (final w in soundWords[ph]!) SoundStep(ph, w)], 'Sonido')),
        const SizedBox(height: 14),
        const Text('Conversación, Describe la imagen, Shadowing y el chat escrito siguen en la web por ahora.', style: TextStyle(color: W.muted, fontSize: 14)),
      ]),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(t.toUpperCase(), style: const TextStyle(letterSpacing: 1, fontWeight: FontWeight.w700, color: W.muted, fontSize: 13)),
      );

  Widget _tile(IconData icon, String title, String sub, VoidCallback? onTap) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          minVerticalPadding: 12,
          leading: Icon(icon, color: onTap == null ? W.muted : W.accent),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(sub),
          trailing: const Icon(Icons.chevron_right),
          enabled: onTap != null,
          onTap: onTap,
        ),
      );
}
