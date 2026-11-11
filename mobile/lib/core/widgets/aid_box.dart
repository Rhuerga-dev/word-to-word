import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/session/data/word_card.dart';
import '../../features/words/data/words_repository.dart';
import '../l10n/tr.dart';
import '../theme/app_theme.dart';

/// Escenas AID guardadas en esta sesión (para que la ficha siguiente de la misma palabra la vea).
final aidOverrides = <int, String>{};
String? aidOf(WordCard c) => aidOverrides[c.id] ?? c.aid;

/// Tu escena AID (Acción Irracional Detallada): una imagen absurda que une el sonido con el significado.
/// La escribes tú o eliges una que sugiere la IA; se guarda sola.
class AidBox extends ConsumerStatefulWidget {
  const AidBox({super.key, required this.card, this.nudge = false});
  final WordCard card;

  /// Se te olvidó varias veces: se abre directamente invitándote a crear una.
  final bool nudge;

  @override
  ConsumerState<AidBox> createState() => _AidBoxState();
}

class _AidBoxState extends ConsumerState<AidBox> {
  late final _text = TextEditingController(text: aidOf(widget.card) ?? '');
  late bool _open = widget.nudge || (aidOf(widget.card)?.isNotEmpty ?? false);
  bool _editing = false, _loading = false;
  List<String> _sugg = const [];
  String _state = '';
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _editing = _text.text.isEmpty;
  }

  @override
  void didUpdateWidget(AidBox old) {
    super.didUpdateWidget(old);
    if (widget.nudge && !_open) setState(() => _open = true);
  }

  @override
  void dispose() {
    _t?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _changed(String v) {
    aidOverrides[widget.card.id] = v;
    setState(() => _state = tr('Guardando…'));
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 700), () async {
      try {
        await ref.read(wordsRepositoryProvider).saveAid(widget.card.id, v);
        if (mounted) setState(() => _state = tr('Guardado'));
      } catch (e) {
        if (mounted) setState(() => _state = '$e');
      }
    });
  }

  Future<void> _suggest() async {
    setState(() => _loading = true);
    try {
      _sugg = await ref.read(wordsRepositoryProvider).suggestAid(widget.card.id);
      _state = '';
    } catch (e) {
      _state = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(onPressed: () => setState(() => _open = true), icon: const Icon(Icons.lightbulb_outline), label: Text(tr('Crear escena AID'))),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFFFBE0), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEFE08A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.lightbulb, color: Color(0xFFB7791F), size: 20),
          const SizedBox(width: 6),
          Expanded(child: Text(tr('Tu escena AID'), style: const TextStyle(fontWeight: FontWeight.w700))),
          if (!_editing) IconButton(tooltip: tr('Editar'), onPressed: () => setState(() => _editing = true), icon: const Icon(Icons.edit, size: 20)),
        ]),
        if (widget.nudge && _text.text.isEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(tr('Se te ha olvidado varias veces: una escena absurda la fija en tu memoria.'), style: const TextStyle(color: W.muted))),
        if (_editing)
          TextField(
            controller: _text,
            onChanged: _changed,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(hintText: tr('Ej.: suena a “…”. Imagina una acción absurda, exagerada y con detalles…'), filled: true, fillColor: Colors.white),
          )
        else
          Text(_text.text, style: W.hand(24)),
        const SizedBox(height: 6),
        Row(children: [
          TextButton.icon(onPressed: _loading ? null : _suggest, icon: const Icon(Icons.auto_awesome, size: 18), label: Text(_loading ? tr('Pensando…') : tr('Sugerir con IA'))),
          const Spacer(),
          if (_state.isNotEmpty) Flexible(child: Text(_state, style: const TextStyle(color: W.muted, fontSize: 12), overflow: TextOverflow.ellipsis)),
        ]),
        if (_sugg.isNotEmpty) ...[
          Text(tr('Toca una para usarla. Mejor aún: edítala a tu manera.'), style: const TextStyle(color: W.muted, fontSize: 13)),
          for (final s in _sugg)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, backgroundColor: Colors.white),
                onPressed: () {
                  _text.text = s;
                  _changed(s);
                  setState(() {
                    _sugg = const [];
                    _editing = false;
                  });
                },
                child: Text(s, style: const TextStyle(color: W.ink)),
              ),
            ),
        ],
      ]),
    );
  }
}
