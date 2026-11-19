import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/theme/app_theme.dart';
import '../data/pet.dart';
import '../data/pet_repository.dart';
import 'pet_cloud.dart';
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

class _PetBirthPageState extends ConsumerState<PetBirthPage> with TickerProviderStateMixin {
  /// El nacimiento, de 0 a 1 (una vez). [_sky] da vueltas sin parar: el parpadeo de las estrellas y los destellos.
  late final AnimationController _birth = AnimationController(vsync: this, duration: const Duration(milliseconds: 6200));
  late final AnimationController _sky = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  final _name = TextEditingController();
  bool _started = false, _busy = false;
  String _msg = '';
  String? _savedName; // el nombre que le puso (null = dijo «luego»)
  bool _choosingColor = false; // segundo paso: elegir su color
  late String? _color = widget.pet.color; // el color elegido (null = el neutro con el que nace)

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
      _sky.repeat();
    }
  }

  @override
  void dispose() {
    _birth.dispose();
    _sky.dispose();
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
      setState(() {
        _savedName = name == null ? null : (pet?.name ?? name);
        _choosingColor = true;
      });
    } catch (e) {
      if (!mounted) return;
      if (name == null) {
        // «Luego» nunca se queda atascado: si no se pudo apuntar, se preguntará otro día. Sigue al color.
        setState(() => _choosingColor = true);
      } else {
        setState(() => _msg = '$e');
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Elige un color: la mascota cambia al momento y se guarda en el servidor. Si falla, se dice y se puede reintentar.
  Future<void> _pick(String? color) async {
    final repo = ref.read(petRepositoryProvider);
    setState(() {
      _color = color;
      _msg = '';
    });
    try {
      await repo.recolor(color);
    } catch (e) {
      if (mounted) setState(() => _msg = '$e');
    }
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
          child: Stack(children: [
            // El cielo: estrellas que parpadean detrás de todo, a pantalla completa.
            Positioned.fill(child: RepaintBoundary(child: AnimatedBuilder(animation: _sky, builder: (_, __) => CustomPaint(painter: _SkyPainter(_sky.value))))),
            SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_birth, _sky]),
                  builder: (context, _) {
                    final t = _birth.value;
                    return Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox.square(dimension: side, child: _BirthScene(t: t, sky: _sky.value, pet: widget.pet.copyWith(color: _color, keepColor: false), size: side)),
                      const SizedBox(height: 18),
                      // La pregunta aparece cuando la mascota ya está formada.
                      IgnorePointer(
                        ignoring: t < 1,
                        child: AnimatedOpacity(
                          opacity: t >= 1 ? 1 : 0,
                          duration: const Duration(milliseconds: 350),
                          child: _choosingColor ? _colorStep() : _question(),
                        ),
                      ),
                    ]);
                  },
                ),
              ),
            ),
          ),
          ]),
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

  /// Segundo paso: elegir su color. Nace de color neutro; al tocar un color cambia al momento. Termina
  /// invitando a empezar: la bienvenida acaba en estudiar, no en mirar a la mascota.
  Widget _colorStep() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(_savedName != null ? tr('¡Me llamo {0}!', [_savedName]) : tr('¡Hola! Soy Brainy.'), textAlign: TextAlign.center, style: W.display(24, color: Colors.white)),
      const SizedBox(height: 6),
      Text(tr('¿De qué color quieres que sea?'), textAlign: TextAlign.center, style: const TextStyle(color: W.mist, fontSize: 17)),
      const SizedBox(height: 14),
      PetColorPicker(selected: _color, onPick: _pick, ring: Colors.white),
      if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg, textAlign: TextAlign.center, style: const TextStyle(color: W.yellow))),
      const SizedBox(height: 14),
      Text(tr('Tengo hambre de palabras. ¿Me enseñas la primera?'), textAlign: TextAlign.center, style: const TextStyle(color: W.mist, fontSize: 16)),
      const SizedBox(height: 12),
      FilledButton(
        key: const ValueKey('pet-birth-start'),
        style: FilledButton.styleFrom(backgroundColor: W.yellow, foregroundColor: W.yellowInk, shape: const StadiumBorder(), minimumSize: const Size(220, 52)),
        onPressed: _close,
        child: Text(tr('Empezar')),
      ),
    ]);
  }
}

/// Los colores para elegir: una fila de círculos. El elegido lleva un aro ([ring]).
class PetColorPicker extends StatelessWidget {
  const PetColorPicker({super.key, required this.selected, required this.onPick, this.ring = W.ink});
  final String? selected;
  final void Function(String? color) onPick;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 6, runSpacing: 8, alignment: WrapAlignment.center, children: [
      for (final (key, name, color) in BrainyColors.choices)
        Semantics(
          button: true,
          selected: selected == key,
          label: tr(name),
          child: GestureDetector(
            key: ValueKey('pet-color-$key'),
            onTap: () => onPick(key),
            child: Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected == key ? ring : Colors.transparent, width: 3)),
              child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
            ),
          ),
        ),
    ]);
  }
}

/// La escena del nacimiento según el tiempo [t] (0–1). Todo dibujado con código:
///   0,00 → 0,46  neuronas llegan volando en espiral y se juntan: con cada una, la chispa crece
///   0,46 → 0,66  tres latidos fuertes, cada uno con un anillo que se expande
///   0,66 → 0,76  estallido: destello, onda y chispas que salen disparadas
///   0,70 → 1,00  la mascota aparece con un rebote; quedan destellos a su alrededor
/// [sky] (0–1, en bucle) mueve lo que sigue vivo al terminar: el resplandor y los destellos.
class _BirthScene extends StatelessWidget {
  const _BirthScene({required this.t, required this.sky, required this.pet, required this.size});
  final double t, sky, size;
  final PetState pet;

  @override
  Widget build(BuildContext context) {
    final grow = Curves.elasticOut.transform(_span(t, 0.70, 1.0));
    final petOpacity = _span(t, 0.70, 0.80);
    return Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
      // Chispa, neuronas, latidos, estallido y destellos: se dibujan más allá del cuadro de la mascota.
      Positioned.fill(child: OverflowBox(maxWidth: size * 2.4, maxHeight: size * 2.4, child: CustomPaint(size: Size.square(size * 2.4), painter: _BirthPainter(t, sky, size)))),
      if (petOpacity > 0)
        Opacity(
          opacity: petOpacity,
          child: Transform.scale(scale: 0.15 + 0.85 * grow, child: PetFigure(pet: pet, size: size * 0.86, fit: true)),
        ),
    ]);
  }
}

double _span(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

/// Números «al azar» pero siempre los mismos (así la animación es igual en cada teléfono y en los tests).
double _rnd(int i, int salt) {
  final x = math.sin(i * 127.1 + salt * 311.7) * 43758.5453;
  return x - x.floorToDouble();
}

/// Los colores de las neuronas: los de las zonas del cerebro de Brainy.
const _neuronColors = [Color(0xFF7C9CFF), Color(0xFF4AC487), Color(0xFFE6A64A), Color(0xFFF07A9A), Color(0xFFB58CFF), Color(0xFFFFE45C)];

class _BirthPainter extends CustomPainter {
  _BirthPainter(this.t, this.sky, this.side);
  final double t, sky, side;

  static const _neurons = 34, _sparks = 26, _twinkles = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final u = side; // unidad: el lado del cuadro de la mascota

    // --- Resplandor claro detrás de la mascota (sin él, azul oscuro sobre azul oscuro no se vería) ---
    final halo = _span(t, 0.70, 0.84);
    if (halo > 0) {
      final pulse = 1 + 0.04 * math.sin(sky * 2 * math.pi);
      final r = u * 0.56 * pulse;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFDFE7FF).withValues(alpha: 0.92 * halo),
            const Color(0xFFB9CBFF).withValues(alpha: 0.60 * halo),
            const Color(0x00B9CBFF),
          ], stops: const [0.0, 0.62, 1.0]).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    // --- Neuronas que llegan en espiral y se funden con la chispa ---
    final gather = _span(t, 0.0, 0.46);
    var arrived = 0.0;
    if (t < 0.50) {
      for (var i = 0; i < _neurons; i++) {
        final start = _rnd(i, 1) * 0.55; // cada una sale en su momento
        final p = _span(gather, start, start + 0.45);
        if (p <= 0) continue;
        final e = Curves.easeInCubic.transform(p);
        arrived += e;
        if (p >= 1) continue;
        final a0 = _rnd(i, 2) * 2 * math.pi;
        final angle = a0 + (1 - e) * (2.2 + _rnd(i, 3) * 1.6) * (i.isEven ? 1 : -1);
        final dist = u * (0.95 + _rnd(i, 4) * 0.25) * (1 - e);
        final pos = c + Offset(math.cos(angle), math.sin(angle)) * dist;
        final color = _neuronColors[i % _neuronColors.length];
        final r = u * (0.012 + 0.012 * _rnd(i, 5));
        // Estela: unas copias más tenues por donde acaba de pasar.
        for (var k = 1; k <= 4; k++) {
          final pe = Curves.easeInCubic.transform((p - k * 0.035).clamp(0.0, 1.0));
          final ang = a0 + (1 - pe) * (2.2 + _rnd(i, 3) * 1.6) * (i.isEven ? 1 : -1);
          final d = u * (0.95 + _rnd(i, 4) * 0.25) * (1 - pe);
          canvas.drawCircle(c + Offset(math.cos(ang), math.sin(ang)) * d, r * (1 - k * 0.16), Paint()..color = color.withValues(alpha: 0.30 * (1 - k / 5) * math.min(1, p * 6)));
        }
        canvas.drawCircle(pos, r * 2.6, Paint()..color = color.withValues(alpha: 0.18 * math.min(1, p * 6)));
        canvas.drawCircle(pos, r, Paint()..color = color.withValues(alpha: math.min(1, p * 6)));
      }
    } else {
      arrived = _neurons.toDouble();
    }
    final fed = arrived / _neurons; // cuánto ha crecido la chispa (0–1)

    // --- Latidos: tres golpes, cada uno suelta un anillo ---
    final beats = _span(t, 0.46, 0.66);
    var thump = 0.0;
    if (beats > 0 && beats < 1) {
      for (var b = 0; b < 3; b++) {
        final p = _span(beats, b / 3, (b + 1) / 3);
        if (p <= 0 || p >= 1) continue;
        thump = math.max(thump, math.sin(math.min(1.0, p * 2.2) * math.pi)); // golpe rápido al principio
        canvas.drawCircle(
          c,
          u * (0.10 + 0.50 * Curves.easeOut.transform(p)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = u * 0.016 * (1 - p)
            ..color = const Color(0xFFFFE45C).withValues(alpha: 0.75 * (1 - p)),
        );
      }
    }

    // --- La chispa: núcleo con resplandor y rayos que giran ---
    final sparkOut = 1 - _span(t, 0.66, 0.74);
    if (sparkOut > 0 && (fed > 0 || t < 0.5)) {
      final appear = Curves.easeOut.transform(_span(t, 0.0, 0.08));
      final r = u * (0.025 + 0.075 * fed) * appear * (1 + 0.45 * thump) * (1 + 0.06 * math.sin(t * math.pi * 40));
      if (r > 0) {
        canvas.drawCircle(
          c,
          r * 4.2,
          Paint()
            ..shader = RadialGradient(colors: [
              const Color(0xFFFFE45C).withValues(alpha: 0.65 * sparkOut),
              const Color(0xFFFFB84A).withValues(alpha: 0.22 * sparkOut),
              const Color(0x00FFB84A),
            ], stops: const [0.0, 0.45, 1.0]).createShader(Rect.fromCircle(center: c, radius: r * 4.2)),
        );
        final ray = Paint()
          ..color = const Color(0xFFFFF3B0).withValues(alpha: 0.85 * sparkOut)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(1.0, r * 0.16);
        for (var k = 0; k < 8; k++) {
          final a = t * 9 + k * math.pi / 4;
          final len = r * (1.7 + (k.isEven ? 0.9 : 0.3) + 0.5 * thump);
          canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * r * 1.15, c + Offset(math.cos(a), math.sin(a)) * len, ray);
        }
        canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFFE45C).withValues(alpha: sparkOut));
        canvas.drawCircle(c, r * 0.55, Paint()..color = Colors.white.withValues(alpha: 0.95 * sparkOut));
      }
    }

    // --- Estallido: destello, onda y chispas disparadas ---
    final burst = _span(t, 0.66, 0.86);
    if (burst > 0 && burst < 1) {
      final flash = math.sin(_span(burst, 0, 0.45) * math.pi);
      if (flash > 0) {
        final r = u * (0.25 + 0.85 * flash);
        canvas.drawCircle(
          c,
          r,
          Paint()..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.95 * flash), const Color(0x00FFFFFF)]).createShader(Rect.fromCircle(center: c, radius: r)),
        );
      }
      final wave = Curves.easeOut.transform(burst);
      canvas.drawCircle(
        c,
        u * (0.12 + 0.95 * wave),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.03 * (1 - burst)
          ..color = Colors.white.withValues(alpha: 0.8 * (1 - burst)),
      );
      for (var i = 0; i < _sparks; i++) {
        final a = i * 2 * math.pi / _sparks + _rnd(i, 7) * 0.5;
        final speed = 0.55 + _rnd(i, 8) * 0.6;
        final d = u * speed * Curves.easeOutCubic.transform(burst);
        final dir = Offset(math.cos(a), math.sin(a));
        final gravity = Offset(0, u * 0.22 * burst * burst); // caen un poco
        final color = _neuronColors[i % _neuronColors.length];
        final line = Paint()
          ..color = color.withValues(alpha: 1 - burst)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = u * 0.012 * (1 - burst * 0.6);
        canvas.drawLine(c + dir * (d - u * 0.06 * (1 - burst)) + gravity, c + dir * d + gravity, line);
      }
    }

    // --- Destellos que se quedan alrededor de la mascota ---
    final after = _span(t, 0.82, 1.0);
    if (after > 0) {
      for (var i = 0; i < _twinkles; i++) {
        final a = i * 2 * math.pi / _twinkles + _rnd(i, 11) * 0.6;
        final d = u * (0.52 + 0.20 * _rnd(i, 12));
        final blink = (0.5 + 0.5 * math.sin((sky + _rnd(i, 13)) * 2 * math.pi)).clamp(0.0, 1.0);
        _star(canvas, c + Offset(math.cos(a), math.sin(a) * 0.86) * d, u * (0.016 + 0.018 * _rnd(i, 14)) * (0.5 + 0.5 * blink),
            _neuronColors[i % _neuronColors.length].withValues(alpha: after * (0.35 + 0.65 * blink)));
      }
    }
  }

  /// Una estrellita de cuatro puntas.
  static void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = -math.pi / 2 + i * math.pi / 4;
      final d = i.isEven ? r : r * 0.34;
      final p = c + Offset(math.cos(a) * d, math.sin(a) * d);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BirthPainter old) => old.t != t || old.sky != sky || old.side != side;
}

/// El cielo de fondo: estrellas pequeñas que parpadean despacio.
class _SkyPainter extends CustomPainter {
  _SkyPainter(this.phase);
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(center: Alignment(0, -0.35), radius: 1.1, colors: [Color(0xFF1B3FAF), Color(0xFF0F2A86), Color(0xFF09195A)], stops: [0.0, 0.55, 1.0])
            .createShader(Offset.zero & size),
    );
    for (var i = 0; i < 70; i++) {
      final pos = Offset(_rnd(i, 21) * size.width, _rnd(i, 22) * size.height);
      final blink = 0.5 + 0.5 * math.sin((phase + _rnd(i, 23)) * 2 * math.pi);
      canvas.drawCircle(pos, 0.6 + 1.5 * _rnd(i, 24), Paint()..color = Colors.white.withValues(alpha: 0.12 + 0.55 * blink * _rnd(i, 25)));
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.phase != phase;
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

/// Cambiar el color de la mascota más adelante (Ajustes → Brainy).
class PetColorDialog extends ConsumerStatefulWidget {
  const PetColorDialog({super.key, required this.pet});
  final PetState pet;

  @override
  ConsumerState<PetColorDialog> createState() => _PetColorDialogState();
}

class _PetColorDialogState extends ConsumerState<PetColorDialog> {
  late String? _color = widget.pet.color;
  String _msg = '';

  Future<void> _pick(String? color) async {
    final repo = ref.read(petRepositoryProvider);
    setState(() {
      _color = color;
      _msg = '';
    });
    try {
      await repo.recolor(color);
      ref.invalidate(petProvider);
    } catch (e) {
      if (mounted) setState(() => _msg = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('Color de tu mascota')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        PetFigure(pet: widget.pet.copyWith(color: _color, keepColor: false), size: 150, fit: true),
        const SizedBox(height: 10),
        PetColorPicker(selected: _color, onPick: _pick),
        if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg, style: const TextStyle(color: W.bad))),
      ]),
      actions: [FilledButton(key: const ValueKey('pet-color-done'), onPressed: () => Navigator.pop(context), child: Text(tr('Listo')))],
    );
  }
}
