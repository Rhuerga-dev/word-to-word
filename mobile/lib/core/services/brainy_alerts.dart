import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/pet/presentation/pet_providers.dart';
import '../l10n/tr.dart';
import 'brainy_mode_setting.dart';
import 'reminder_service.dart';

/// Un aviso de la mascota ya decidido: cuándo sale (hora local) y qué dice.
typedef BrainyAlert = ({DateTime at, String title, String body});

/// Los avisos de Brainy (solo en Modo Brainy): la mascota avisa cuando va a tener hambre o va a querer jugar.
///
/// El servidor dice CUÁNDO pasará cada cosa (`care.alerts` de GET /pet); el teléfono programa el aviso él solo,
/// así que sale aunque no haya internet. Reglas fijas, para que acompañe y no agobie:
///   · como mucho [max] avisos programados, separados al menos [gap];
///   · nunca de noche: lo que caiga entre las [quietFrom] y las [quietTo] pasa a las [quietTo]:30 de la mañana;
///   · nunca culpa: solo dice qué le apetece.
class BrainyAlerts {
  static const max = 2;
  static const gap = Duration(hours: 3);
  static const quietFrom = 21, quietTo = 8;

  /// Los textos de cada aviso (título, texto), con el nombre de la mascota. Clave desconocida → no se avisa.
  static (String, String)? text(String kind, String pet) => switch (kind) {
    'hungry' => (tr('{0} tiene hambre', [pet]), tr('Una palabra nueva es su comida favorita.')),
    'bored' => (tr('{0} quiere jugar', [pet]), tr('¿Un rato de Oído o un minuto hablando?')),
    _ => null,
  };

  /// Qué avisos programar. [alerts]: (clave, instante) del servidor; [now]: la hora local del teléfono.
  static List<BrainyAlert> plan(DateTime now, List<(String, DateTime)> alerts, String petName) {
    final pet = petName.trim().isEmpty ? 'Brainy' : petName.trim();
    final found = <BrainyAlert>[];
    for (final (kind, instant) in alerts) {
      final words = text(kind, pet);
      if (words == null) continue;
      final at = _awake(instant.toLocal());
      if (!at.isAfter(now)) continue;
      found.add((at: at, title: words.$1, body: words.$2));
    }
    found.sort((a, b) => a.at.compareTo(b.at));
    final out = <BrainyAlert>[];
    for (final a in found) {
      if (out.length >= max) break;
      if (out.isNotEmpty && a.at.difference(out.last.at) < gap) continue;
      out.add(a);
    }
    return out;
  }

  /// Si la hora cae de noche, la pasa a la mañana siguiente.
  static DateTime _awake(DateTime at) {
    if (at.hour >= quietFrom) return DateTime(at.year, at.month, at.day + 1, quietTo, 30);
    if (at.hour < quietTo) return DateTime(at.year, at.month, at.day, quietTo, 30);
    return at;
  }
}

/// Ajuste «Avisos de Brainy» (se guarda en el teléfono). Encendido por defecto: solo actúa con el Modo Brainy.
class BrainyAlertsSetting extends AsyncNotifier<bool> {
  static const key = 'brainy_alerts';
  static const _storage = FlutterSecureStorage();

  /// (Los tests lo sustituyen.)
  Future<String?> readStored() => _storage.read(key: key);
  Future<void> writeStored(String value) => _storage.write(key: key, value: value);

  @override
  Future<bool> build() async {
    try {
      return await readStored() != '0';
    } catch (_) {
      return true;
    }
  }

  Future<void> set(bool on) async {
    state = AsyncData(on);
    try {
      await writeStored(on ? '1' : '0');
    } catch (_) {}
  }
}

final brainyAlertsProvider = AsyncNotifierProvider<BrainyAlertsSetting, bool>(BrainyAlertsSetting.new);

/// Mantiene los avisos al día: se reprograman cada vez que llega el estado de la mascota (al abrir la app y al
/// terminar una sesión) o cambia un ajuste. Sin Modo Brainy, sin el ajuste o sin mascota: se quitan.
final brainyAlertsSyncProvider = Provider<void>((ref) {
  final mode = ref.watch(brainyModeProvider).valueOrNull;
  final wanted = ref.watch(brainyAlertsProvider).valueOrNull;
  final pet = ref.watch(petProvider);
  if (mode == null || wanted == null || pet.isLoading) return; // aún no se sabe: no se toca lo programado
  final care = pet.valueOrNull?.care;
  final on = mode && wanted && care != null;
  ref.read(reminderServiceProvider).syncBrainy(on ? BrainyAlerts.plan(DateTime.now(), care.alerts, pet.valueOrNull!.name) : const []);
});
