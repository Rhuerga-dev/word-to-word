import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../path/presentation/path_providers.dart';
import '../../practice/presentation/practice_providers.dart';
import '../../progress/presentation/progress_providers.dart';
import '../../today/presentation/today_providers.dart';
import '../../words/data/words_repository.dart';

/// Un curso de W2W: qué idioma se aprende ([learn]) y si ya está abierto a todos ([active]).
class CourseOption {
  const CourseOption({required this.code, required this.name, required this.learn, this.active = true, this.current = false});
  final String code, name, learn;
  final bool active, current;

  /// Bandera del idioma que se aprende (es texto, no una imagen: cabe en un parche).
  String get flag => switch (learn) { 'en' => '🇺🇸', 'es' => '🇪🇸', _ => '🌐' };

  static CourseOption? tryParse(Object? json) {
    if (json is! Map) return null;
    final code = json['code'], name = json['name'];
    if (code is! String || code.isEmpty || name is! String || name.isEmpty) return null;
    return CourseOption(
      code: code,
      name: name,
      learn: json['learn'] is String ? json['learn'] as String : '',
      active: json['active'] != false,
      current: json['current'] == true,
    );
  }
}

/// Los cursos que el servidor ofrece a este alumno (GET /courses). Vacío si el servidor es viejo o falla.
final coursesProvider = FutureProvider<List<CourseOption>>((ref) async {
  try {
    final data = await ref.watch(apiProvider).get('/courses');
    final list = data is Map ? data['courses'] : null;
    return [if (list is List) for (final c in list) if (CourseOption.tryParse(c) case final o?) o];
  } catch (_) {
    return const [];
  }
});

/// Ajustes → «Qué aprendes»: elegir curso. Solo sale si hay más de un curso para elegir; con uno solo,
/// la app queda como siempre. Cambiar no borra nada: cada curso guarda su progreso aparte.
class CourseCard extends ConsumerStatefulWidget {
  const CourseCard({super.key});

  @override
  ConsumerState<CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends ConsumerState<CourseCard> {
  String? _saving; // el código que se está guardando
  String? _error;

  Future<void> _choose(CourseOption course) async {
    if (_saving != null || course.current) return;
    setState(() {
      _saving = course.code;
      _error = null;
    });
    try {
      await ref.read(apiProvider).put('/course', {'code': course.code});
      // Todo lo que se ve depende del curso: se vuelve a pedir.
      ref.invalidate(coursesProvider);
      ref.invalidate(todayProvider);
      ref.invalidate(progressProvider);
      ref.invalidate(pathProvider);
      ref.invalidate(wordsProvider);
      ref.invalidate(practiceProvider);
    } catch (_) {
      if (mounted) setState(() => _error = tr('No se pudo cambiar de curso. Inténtalo otra vez.'));
    }
    if (mounted) setState(() => _saving = null);
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(coursesProvider).valueOrNull ?? const <CourseOption>[];
    if (courses.length < 2) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 22, bottom: 8), child: Text(tr('Qué aprendes'), style: W.display(19))),
      Card(
        child: Column(children: [
          for (final c in courses)
            ListTile(
              key: ValueKey('course-${c.code}'),
              leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
              title: Text(c.name),
              subtitle: c.active ? null : Text(tr('En construcción (solo para probar)')),
              trailing: _saving == c.code
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(c.current ? '✓' : '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              selected: c.current,
              onTap: () => _choose(c),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(_error ?? tr('Cada curso guarda su progreso aparte: al cambiar no pierdes nada.'),
                style: TextStyle(fontSize: 13, color: _error != null ? Theme.of(context).colorScheme.error : null)),
          ),
        ]),
      ),
    ]);
  }
}
