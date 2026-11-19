import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// La bienvenida de la mascota, una sola vez: sus neuronas llegan volando y forman el cerebro, late, y de él
/// sale la mascota por partes (ver [BirthTimeline]); el teléfono vibra un poco en cada golpe. Luego pregunta
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
  late final AnimationController _birth = AnimationController(vsync: this, duration: const Duration(milliseconds: 7000))..addListener(_haptics);
  late final AnimationController _sky = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  final _name = TextEditingController();
  bool _started = false, _busy = false;
  String _msg = '';
  String? _savedName; // el nombre que le puso (null = dijo «luego»)
  bool _choosingColor = false; // segundo paso: elegir su color
  late String? _color = widget.pet.color; // el color elegido (null = el neutro con el que nace)

  /// Vibración suave en los golpes del nacimiento (latidos, estallido, chispa, aterrizaje). Solo mientras la
  /// animación corre: si se salta tocando, o con «Reducir movimiento», no vibra.
  double _felt = 0;
  void _haptics() {
    final now = _birth.value;
    if (_birth.isAnimating) {
      for (final (at, strength) in BirthTimeline.taps) {
        if (_felt < at && now >= at) {
          switch (strength) {
            case 0:
              HapticFeedback.lightImpact();
            case 1:
              HapticFeedback.mediumImpact();
            default:
              HapticFeedback.heavyImpact();
          }
        }
      }
    }
    _felt = now;
  }

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
                    // Mientras nace se ve de cerca y más al centro; al final se aparta para dejar sitio a la pregunta.
                    final close = 1 - Curves.easeInOutCubic.transform(((t - 0.88) / 0.12).clamp(0.0, 1.0));
                    return Column(mainAxisSize: MainAxisSize.min, children: [
                      Transform.translate(
                        offset: Offset(0, 70 * close),
                        child: Transform.scale(
                          scale: 1 + 0.5 * close,
                          child: SizedBox.square(dimension: side, child: _BirthScene(t: t, sky: _sky.value, pet: widget.pet.copyWith(color: _color, keepColor: false), size: side)),
                        ),
                      ),
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

/// Los momentos del nacimiento, sobre el tiempo [t] de 0 a 1. Todo dibujado con código:
///   0,00 → 0,40  las neuronas llegan volando en remolino, cada una a SU sitio en el cerebro
///   0,40 → 0,50  se conectan entre ellas
///   0,50 → 0,66  tres latidos: el cerebro late y suelta un anillo cada vez
///   0,66 → 0,80  estallido de luz; el cerebro queda dentro de su cúpula
///   0,71 → 0,85  el cuerpo sale de detrás de la cúpula y crece
///   0,83 → 0,91  crece la antena y se enciende su chispa
///   0,885 → 1,00 abre los ojos, parpadea y da un saltito
class BirthTimeline {
  static const gathered = 0.40, wired = 0.50, burst = 0.66, domed = 0.71, bodied = 0.85, sparked = 0.87, eyesOpen = 0.885, landed = 0.972;
  static const beats = [0.50, 0.5533, 0.6067];

  /// Los momentos en que el teléfono vibra un poco (y con qué fuerza: 0 suave, 1 media, 2 fuerte).
  static const taps = <(double at, int strength)>[(gathered, 0), (0.50, 0), (0.5533, 0), (0.6067, 1), (burst, 2), (sparked, 0), (landed, 1)];

  /// Cuánto de la mascota ha aparecido en el momento [t]. [newborn]: la recién nacida vuelve a cerrar los
  /// ojos al final (su cara de bebé); una ya crecida los deja abiertos.
  static PetBirthPose pose(double t, {required bool newborn}) {
    var eyes = Curves.easeOutBack.transform(_span(t, eyesOpen, 0.915));
    final blink = _span(t, 0.925, 0.94);
    if (blink > 0 && blink < 1) eyes *= 1 - math.sin(blink * math.pi);
    if (newborn) eyes *= 1 - _span(t, 0.985, 1.0);
    final crouch = _span(t, 0.93, 0.945), jump = _span(t, 0.945, landed), land = _span(t, landed, 0.99);
    var squash = 0.0;
    if (crouch > 0 && crouch < 1) squash = 0.05 * math.sin(crouch * math.pi);
    if (land > 0 && land < 1) squash = 0.07 * math.sin(land * math.pi);
    return PetBirthPose(
      dome: _span(t, burst, domed),
      body: Curves.easeOutBack.transform(_span(t, domed, bodied)),
      antenna: Curves.easeOutBack.transform(_span(t, 0.83, 0.88)),
      spark: Curves.elasticOut.transform(_span(t, sparked, 0.93)),
      eyes: eyes,
      lift: jump > 0 && jump < 1 ? 30 * math.sin(jump * math.pi) : 0,
      squash: squash,
    );
  }
}

/// La escena del nacimiento. Dos capas: detrás, las luces (neuronas volando, latidos, estallido, destellos);
/// delante, la mascota de verdad, que va apareciendo por partes. Al terminar ([t] = 1) queda la mascota normal.
/// [sky] (0–1, en bucle) mueve lo que sigue vivo al terminar: el resplandor y los destellos.
class _BirthScene extends StatelessWidget {
  const _BirthScene({required this.t, required this.sky, required this.pet, required this.size});
  final double t, sky, size;
  final PetState pet;

  /// La mascota ocupa este trozo del cuadro.
  static const petShare = 0.86;

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
      Positioned.fill(child: OverflowBox(maxWidth: size * 2.4, maxHeight: size * 2.4, child: CustomPaint(size: Size.square(size * 2.4), painter: _BirthPainter(t, sky, size * petShare)))),
      PetFigure(pet: pet, size: size * petShare, fit: true, birth: t < 1 ? BirthTimeline.pose(t, newborn: pet.stage == 0) : null),
    ]);
  }
}

double _span(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

/// Números «al azar» pero siempre los mismos (así la animación es igual en cada teléfono y en los tests).
double _rnd(int i, int salt) {
  final x = math.sin(i * 127.1 + salt * 311.7) * 43758.5453;
  return x - x.floorToDouble();
}

/// Los colores de las zonas del cerebro de Brainy: para las chispas del estallido y los destellos.
const _neuronColors = [Color(0xFF7C9CFF), Color(0xFF4AC487), Color(0xFFE6A64A), Color(0xFFF07A9A), Color(0xFFB58CFF), Color(0xFFFFE45C)];

/// Las luces del nacimiento. Dibuja en la misma «hoja» que la mascota ([PetPainter.sheet]), así cada neurona
/// vuela justo al punto donde luego está en su cerebro. [box] = el lado del cuadro de la mascota.
class _BirthPainter extends CustomPainter {
  _BirthPainter(this.t, this.sky, this.box);
  final double t, sky, box;

  static const _sparks = 28, _twinkles = 12;
  static const _pale = Color(0xFFB9CBFF);

  @override
  void paint(Canvas canvas, Size size) {
    final (s, origin) = PetPainter.sheet(Size.square(box));
    canvas.save();
    canvas.translate(size.width / 2 - box / 2 + origin.dx, size.height / 2 - box / 2 + origin.dy);
    canvas.scale(s);
    const bc = PetPainter.brainCenter, body = Offset(200, 240);
    final dome = _span(t, BirthTimeline.burst, BirthTimeline.domed);

    // --- Resplandor claro detrás de la mascota: la separa del cielo oscuro ---
    final halo = Curves.easeOut.transform(_span(t, BirthTimeline.domed, BirthTimeline.bodied));
    if (halo > 0) {
      final r = 285 * (1 + 0.04 * math.sin(sky * 2 * math.pi));
      canvas.drawCircle(body, r, Paint()..shader = ui.Gradient.radial(body, r, [const Color(0xFFDFE7FF).withValues(alpha: 0.55 * halo), _pale.withValues(alpha: 0.30 * halo), const Color(0x00B9CBFF)], const [0.0, 0.6, 1.0]));
    }

    // --- Latidos: tres golpes, cada uno suelta un anillo ---
    var thump = 0.0;
    for (final at in BirthTimeline.beats) {
      final p = _span(t, at, at + 0.07);
      if (p <= 0 || p >= 1) continue;
      thump = math.max(thump, math.sin(math.min(1.0, p * 2.4) * math.pi)); // golpe rápido al principio
      canvas.drawCircle(
        bc,
        80 + 210 * Curves.easeOutCubic.transform(p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8 * (1 - p)
          ..color = const Color(0xFFFFE45C).withValues(alpha: 0.7 * (1 - p)),
      );
    }

    // --- El cerebro formándose (hasta que queda dentro de la cúpula; ahí lo dibuja ya la mascota) ---
    if (dome < 1) _brain(canvas, bc, thump, 1 - dome);

    // --- Estallido: destello, onda y chispas disparadas ---
    final burst = _span(t, BirthTimeline.burst, 0.84);
    if (burst > 0 && burst < 1) {
      final flash = math.sin(_span(burst, 0, 0.5) * math.pi);
      if (flash > 0) {
        final r = 130 + 420 * flash;
        canvas.drawCircle(bc, r, Paint()..shader = ui.Gradient.radial(bc, r, [Colors.white.withValues(alpha: 0.95 * flash), Colors.white.withValues(alpha: 0.35 * flash), const Color(0x00FFFFFF)], const [0.0, 0.35, 1.0]));
      }
      final wave = Curves.easeOutCubic.transform(burst);
      canvas.drawCircle(
        bc,
        70 + 480 * wave,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14 * (1 - burst)
          ..color = Colors.white.withValues(alpha: 0.75 * (1 - burst)),
      );
      final line = Paint()..strokeCap = StrokeCap.round;
      for (var i = 0; i < _sparks; i++) {
        final a = i * 2 * math.pi / _sparks + _rnd(i, 7) * 0.5;
        final d = 90 + (230 + 260 * _rnd(i, 8)) * Curves.easeOutCubic.transform(burst);
        final dir = Offset(math.cos(a), math.sin(a));
        final fall = Offset(0, 110 * burst * burst); // caen un poco
        line
          ..color = _neuronColors[i % _neuronColors.length].withValues(alpha: 1 - burst)
          ..strokeWidth = 6 * (1 - burst * 0.6);
        canvas.drawLine(bc + dir * (d - 34 * (1 - burst)) + fall, bc + dir * d + fall, line);
      }
    }

    // --- La chispa de la antena se enciende: un destello de cuatro rayos ---
    final lit = _span(t, BirthTimeline.sparked, 0.95);
    if (lit > 0 && lit < 1) {
      const tip = Offset(200, 78);
      final grow = Curves.easeOutCubic.transform(lit), fade = 1 - lit;
      canvas.drawCircle(tip, 20 + 70 * grow, Paint()..shader = ui.Gradient.radial(tip, 20 + 70 * grow, [const Color(0xFFFFF3B0).withValues(alpha: 0.8 * fade), const Color(0x00FFE45C)]));
      final ray = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5 * fade
        ..color = const Color(0xFFFFF3B0).withValues(alpha: 0.9 * fade);
      for (var k = 0; k < 4; k++) {
        final dir = Offset(math.cos(k * math.pi / 2), math.sin(k * math.pi / 2));
        canvas.drawLine(tip + dir * (22 + 20 * grow), tip + dir * (30 + 75 * grow), ray);
      }
    }

    // --- Destellos que se quedan alrededor de la mascota ---
    final after = _span(t, 0.86, 1.0);
    if (after > 0) {
      for (var i = 0; i < _twinkles; i++) {
        final a = i * 2 * math.pi / _twinkles + _rnd(i, 11) * 0.6;
        final d = 273 + 105 * _rnd(i, 12);
        final blink = (0.5 + 0.5 * math.sin((sky + _rnd(i, 13)) * 2 * math.pi)).clamp(0.0, 1.0);
        _star(canvas, body + Offset(math.cos(a), math.sin(a) * 0.86) * d, (8 + 10 * _rnd(i, 14)) * (0.5 + 0.5 * blink),
            _neuronColors[i % _neuronColors.length].withValues(alpha: after * (0.35 + 0.65 * blink)));
      }
    }
    canvas.restore();
  }

  /// El cerebro mientras se forma: las neuronas vuelan en remolino hasta su sitio (con estela), luego se
  /// conectan y laten. Todas blancas: así nace. [alpha] lo va apagando cuando la mascota toma el relevo.
  void _brain(Canvas canvas, Offset center, double thump, double alpha) {
    final m = BrainCloud.instance;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(PetPainter.brainRadius * (1 + 0.07 * thump));
    const u = 1 / PetPainter.brainRadius; // una unidad de la hoja, en unidades del cerebro

    final g = t / BirthTimeline.gathered; // sin tope: sirve para saber cuánto hace que llegó cada una
    final home = List.generate(3, (_) => <double>[]);
    final heads = <double>[], young = <double>[], near = <double>[], far = <double>[], flash = <double>[];
    var arrived = 0;
    for (var i = 0; i < m.count; i++) {
      final q = (g - _rnd(i, 1) * 0.58) / 0.42; // cada una sale en su momento y tarda lo mismo
      if (q <= 0) continue;
      if (q >= 1) {
        arrived++;
        home[m.band[i]]
          ..add(m.sx[i])
          ..add(m.sy[i]);
        if (q < 1.22) {
          flash
            ..add(m.sx[i])
            ..add(m.sy[i]);
        }
        continue;
      }
      // Vuela en espiral: de lejos a su sitio, girando cada vez menos. Arranca y frena con suavidad.
      final rho = math.sqrt(m.sx[i] * m.sx[i] + m.sy[i] * m.sy[i]), th = math.atan2(m.sy[i], m.sx[i]);
      final far0 = 6.5 + 2.5 * _rnd(i, 4), swirl = 1.6 + 1.6 * _rnd(i, 3);
      void at(double p, List<double> out) {
        final e = Curves.easeInOutCubic.transform(p.clamp(0.0, 1.0));
        final r = far0 + (rho - far0) * e, a = th + (1 - e) * swirl;
        out
          ..add(r * math.cos(a))
          ..add(r * math.sin(a));
      }

      if (q < 0.18) {
        at(q, young);
        continue;
      }
      at(q, heads);
      at(q - 0.05, near);
      at(q, near);
      at(q - 0.11, far);
      at(q - 0.05, far);
    }
    final fed = arrived / m.count;

    // La luz que las atrae: un resplandor que crece con cada neurona que llega.
    final seed = (36 + 70 * fed) * (1 + 0.25 * thump) * u;
    canvas.drawCircle(Offset.zero, seed, Paint()..shader = ui.Gradient.radial(Offset.zero, seed, [_pale.withValues(alpha: (0.50 + 0.25 * thump) * alpha), const Color(0x00B9CBFF)]));
    if (fed < 1) canvas.drawCircle(Offset.zero, 5 * u * (1 - fed), Paint()..color = Colors.white.withValues(alpha: 0.9 * (1 - fed)));

    // Las conexiones se van tendiendo, con un destello mientras se hacen.
    final wiring = _span(t, BirthTimeline.gathered, BirthTimeline.wired);
    if (wiring > 0) {
      final n = (m.edgeA.length * wiring).floor();
      if (n > 0) {
        canvas.drawRawPoints(
          ui.PointMode.lines,
          Float32List.sublistView(m.lines, 0, n * 4),
          Paint()
            ..color = _pale.withValues(alpha: (0.13 + 0.50 * math.sin(wiring * math.pi) + 0.30 * thump).clamp(0.0, 1.0) * alpha)
            ..strokeWidth = 0.7 * u,
        );
      }
    }

    final dots = Paint()..strokeCap = StrokeCap.round;
    void points(List<double> xy, double width, Color color, [ui.PointMode mode = ui.PointMode.points]) {
      if (xy.isEmpty) return;
      dots
        ..color = color.withValues(alpha: color.a * alpha)
        ..strokeWidth = width * u;
      canvas.drawRawPoints(mode, Float32List.fromList(xy), dots);
    }

    // Estelas (dos tramos, el de atrás más tenue) y las neuronas que vienen volando, con su brillo.
    points(far, 1.2, _pale.withValues(alpha: 0.22), ui.PointMode.lines);
    points(near, 1.6, _pale.withValues(alpha: 0.50), ui.PointMode.lines);
    points(young, 2.0, Colors.white.withValues(alpha: 0.35));
    points(heads, 7.5, _pale.withValues(alpha: 0.16));
    points(heads, 2.8, Colors.white.withValues(alpha: 0.95));
    // Las que ya están en su sitio: iguales que en el cerebro de la mascota (blancas, por capas de profundidad).
    for (var b = 0; b < 3; b++) {
      points(home[b], 1.8 + 0.7 * b, Colors.white.withValues(alpha: (0.34 + 0.22 * b + 0.30 * thump).clamp(0.0, 1.0)));
    }
    points(flash, 4.6, Colors.white.withValues(alpha: 0.55)); // el destello al llegar
    canvas.restore();
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
  bool shouldRepaint(_BirthPainter old) => old.t != t || old.sky != sky || old.box != box;
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
