import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/theme/app_theme.dart';
import '../data/pet.dart';
import '../data/pet_repository.dart';
import 'pet_figure.dart';
import 'pet_providers.dart';

/// Reglas del nombre (las mismas que valida el servidor): de 2 a 20 letras, números o espacios.
const petNameMin = 2, petNameMax = 20;

/// La bienvenida de la mascota, una sola vez: una chispa aparece, late y se convierte en ella; luego pregunta
/// «¿Cómo me quieres llamar?». Se puede saltar («Luego»: se queda como Brainy) y tocar la pantalla adelanta
/// la animación. Con «Reducir movimiento» sale ya formada. Dibujada con código: sin imágenes ni iconos nuevos.
class PetBirthPage extends ConsumerStatefulWidget {
  const PetBirthPage({super.key, required this.pet});
  final PetState pet;

  @override
  ConsumerState<PetBirthPage> createState() => _PetBirthPageState();
}

class _PetBirthPageState extends ConsumerState<PetBirthPage> with SingleTickerProviderStateMixin {
  late final AnimationController _birth = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  final _name = TextEditingController();
  bool _started = false, _busy = false;
  String _msg = '';
  String? _savedName; // con nombre puesto: pantalla final («tiene hambre de palabras»)

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // «Reducir movimiento»: sin animación, la mascota ya está ahí.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _birth.value = 1;
    } else {
      _birth.forward();
    }
  }

  @override
  void dispose() {
    _birth.dispose();
    _name.dispose();
    super.dispose();
  }

  /// Recién nacida de verdad (alumno nuevo) o ya crecida (alumno de antes que aún no le puso nombre).
  bool get _newborn => widget.pet.stage == 0 && widget.pet.points == 0;

  Future<void> _save(String? name) async {
    final repo = ref.read(petRepositoryProvider);
    if (name != null) {
      name = name.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (name.length < petNameMin) {
        setState(() => _msg = tr('Escribe un nombre de al menos 2 letras.'));
        return;
      }
    }
    setState(() {
      _busy = true;
      _msg = '';
    });
    try {
      final pet = await repo.rename(name);
      if (!mounted) return;
      if (name == null) {
        _close();
      } else {
        setState(() => _savedName = pet?.name ?? name);
      }
    } catch (e) {
      if (!mounted) return;
      if (name == null) {
        _close(); // «Luego» nunca se queda atascado: si no se pudo apuntar, se preguntará otro día
      } else {
        setState(() => _msg = '$e');
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  void _close() {
    ref.invalidate(petProvider);
    // pop() directo: la pantalla puede seguir marcada como «ocupada» en este instante y aun así debe cerrarse.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final side = math.min(MediaQuery.sizeOf(context).shortestSide * 0.62, 260.0);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: W.navy,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_birth.value < 1) _birth.value = 1; // tocar adelanta la animación
          },
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: AnimatedBuilder(
                  animation: _birth,
                  builder: (context, _) {
                    final t = _birth.value;
                    return Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox.square(dimension: side, child: _BirthScene(t: t, pet: widget.pet, size: side)),
                      const SizedBox(height: 18),
                      // La pregunta aparece cuando la mascota ya está formada.
                      IgnorePointer(
                        ignoring: t < 1,
                        child: AnimatedOpacity(
                          opacity: t >= 1 ? 1 : 0,
                          duration: const Duration(milliseconds: 350),
                          child: _savedName == null ? _question() : _hungry(_savedName!),
                        ),
                      ),
                    ]);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _question() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(
        _newborn ? tr('¡Hola! Acabo de nacer.') : tr('¡Hola! Soy tu mascota.'),
        textAlign: TextAlign.center,
        style: W.display(24, color: Colors.white),
      ),
      const SizedBox(height: 6),
      Text(tr('¿Cómo me quieres llamar?'), textAlign: TextAlign.center, style: const TextStyle(color: W.mist, fontSize: 17)),
      const SizedBox(height: 16),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: TextField(
          key: const ValueKey('pet-name-field'),
          controller: _name,
          enabled: !_busy,
          maxLength: petNameMax,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => _save(v),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          decoration: InputDecoration(hintText: 'Brainy', filled: true, fillColor: Colors.white, counterStyle: const TextStyle(color: W.mist)),
        ),
      ),
      if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_msg, textAlign: TextAlign.center, style: const TextStyle(color: W.yellow))),
      const SizedBox(height: 10),
      FilledButton(
        key: const ValueKey('pet-name-save'),
        style: FilledButton.styleFrom(backgroundColor: W.yellow, foregroundColor: W.yellowInk, shape: const StadiumBorder(), minimumSize: const Size(220, 52)),
        onPressed: _busy ? null : () => _save(_name.text),
        child: Text(_busy ? tr('Guardando…') : tr('Ponerle ese nombre')),
      ),
      TextButton(
        key: const ValueKey('pet-name-later'),
        onPressed: _busy ? null : () => _save(null),
        child: Text(tr('Luego'), style: const TextStyle(color: W.mist)),
      ),
    ]);
  }

  /// Ya tiene nombre: invita a empezar. La bienvenida termina en estudiar, no en mirar a la mascota.
  Widget _hungry(String name) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(tr('¡Me llamo {0}!', [name]), textAlign: TextAlign.center, style: W.display(24, color: Colors.white)),
      const SizedBox(height: 6),
      Text(tr('Tengo hambre de palabras. ¿Me enseñas la primera?'), textAlign: TextAlign.center, style: const TextStyle(color: W.mist, fontSize: 17)),
      const SizedBox(height: 18),
      FilledButton(
        key: const ValueKey('pet-birth-start'),
        style: FilledButton.styleFrom(backgroundColor: W.yellow, foregroundColor: W.yellowInk, shape: const StadiumBorder(), minimumSize: const Size(220, 52)),
        onPressed: _close,
        child: Text(tr('Empezar')),
      ),
    ]);
  }
}

/// La escena del nacimiento según el tiempo [t] (0–1):
/// 0 → 0,5 una chispa aparece y late · 0,5 → 0,7 un destello · 0,6 → 1 la mascota crece desde la chispa.
class _BirthScene extends StatelessWidget {
  const _BirthScene({required this.t, required this.pet, required this.size});
  final double t, size;
  final PetState pet;

  static double _range(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final appear = Curves.easeOut.transform(_range(t, 0, 0.18));
    final beat = 1 + 0.18 * math.sin(t * math.pi * 14); // late varias veces
    final sparkFade = 1 - _range(t, 0.55, 0.72);
    final flash = math.sin(_range(t, 0.48, 0.74) * math.pi); // sube y baja
    final grow = Curves.elasticOut.transform(_range(t, 0.60, 1.0));
    final petOpacity = _range(t, 0.60, 0.74);
    final spark = size * 0.13 * appear * beat;
    return Stack(alignment: Alignment.center, children: [
      if (flash > 0)
        Container(
          width: size * (0.3 + 0.9 * flash),
          height: size * (0.3 + 0.9 * flash),
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.30 * flash)),
        ),
      if (sparkFade > 0 && spark > 0)
        Opacity(
          opacity: sparkFade,
          child: Container(
            width: spark,
            height: spark,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: W.yellow,
              boxShadow: [BoxShadow(color: W.yellow.withValues(alpha: 0.75), blurRadius: spark * 1.6, spreadRadius: spark * 0.35)],
            ),
          ),
        ),
      // Un resplandor claro detrás: la mascota es azul oscuro y sin él no se distinguiría del fondo.
      if (petOpacity > 0)
        Opacity(
          opacity: petOpacity,
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Color(0xE6DFE7FF), Color(0x99B9CBFF), Color(0x00B9CBFF)], stops: [0.0, 0.62, 1.0]),
            ),
          ),
        ),
      if (petOpacity > 0)
        Opacity(
          opacity: petOpacity,
          child: Transform.scale(scale: 0.2 + 0.8 * grow, child: PetFigure(pet: pet, size: size * 0.86, fit: true)),
        ),
    ]);
  }
}

/// Cambiar el nombre de la mascota más adelante (Ajustes → Brainy).
class PetNameDialog extends ConsumerStatefulWidget {
  const PetNameDialog({super.key, required this.pet});
  final PetState pet;

  @override
  ConsumerState<PetNameDialog> createState() => _PetNameDialogState();
}

class _PetNameDialogState extends ConsumerState<PetNameDialog> {
  late final _name = TextEditingController(text: widget.pet.named ? widget.pet.name : '');
  bool _busy = false;
  String _msg = '';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length < petNameMin) {
      setState(() => _msg = tr('Escribe un nombre de al menos 2 letras.'));
      return;
    }
    final repo = ref.read(petRepositoryProvider), nav = Navigator.of(context);
    setState(() {
      _busy = true;
      _msg = '';
    });
    try {
      await repo.rename(name);
      ref.invalidate(petProvider);
      nav.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _msg = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('Nombre de tu mascota')),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          key: const ValueKey('pet-rename-field'),
          controller: _name,
          enabled: !_busy,
          maxLength: petNameMax,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Brainy'),
        ),
        if (_msg.isNotEmpty) Text(_msg, style: const TextStyle(color: W.bad)),
      ]),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(tr('Cancelar'))),
        FilledButton(key: const ValueKey('pet-rename-save'), onPressed: _busy ? null : _save, child: Text(_busy ? tr('Guardando…') : tr('Guardar'))),
      ],
    );
  }
}
