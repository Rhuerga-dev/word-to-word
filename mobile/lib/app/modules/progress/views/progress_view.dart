import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/services/auth_service.dart';
import '../controllers/progress_controller.dart';

/// Progreso: números claros, liga de la semana y logros.
class ProgressView extends GetView<ProgressController> {
  const ProgressView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
    final p = controller.progress.value;
    if (p == null) return Center(child: controller.error.value.isEmpty ? const CircularProgressIndicator() : Text(controller.error.value, style: const TextStyle(color: W.bad)));
    final v = p['vocab'] as Map, s = p['speaking'] as Map, mi = p['mistakes'] as Map;
    final sounds = ((p['pronunciation'] as Map)['sounds'] as List).cast<Map>();
    final l = controller.league.value!, a = controller.achievements.value!;
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
        Row(children: [
          Expanded(child: Text('Progreso', style: W.display(26))),
          TextButton(onPressed: () => Get.find<AuthService>().logout(), child: const Text('Salir')),
        ]),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.7,
          children: [
            _stat('${v['learned']}', 'palabras aprendidas'),
            _stat('${s['total_minutes']}', 'minutos hablando'),
            _stat('${v['streak']}', 'días seguidos'),
            _stat('${mi['mastered']}', 'errores superados'),
          ],
        ),
        for (final t in (p['todo'] as List? ?? const []))
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('${t['icon']} ${t['text']}')),
        _h('Recordatorio diario'),
        Card(
          child: Column(children: [
            SwitchListTile(
              title: const Text('Avisarme si no he estudiado'),
              subtitle: Text(Get.find<AuthService>().reminder['enabled'] == true ? 'A las ${Get.find<AuthService>().reminder['time'] ?? '19:00'}' : 'Desactivado'),
              value: Get.find<AuthService>().reminder['enabled'] == true,
              onChanged: controller.setReminder,
            ),
            if (Get.find<AuthService>().reminder['enabled'] == true)
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Cambiar la hora'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => controller.pickReminderTime(context),
              ),
            if (controller.reminderMsg.value.isNotEmpty)
              Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Text(controller.reminderMsg.value, style: const TextStyle(color: W.muted))),
          ]),
        ),
        _h('Liga de la semana'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(l['me']['rank'] == null ? 'Aún sin puntos esta semana' : 'Vas en el puesto ${l['me']['rank']} de ${l['players']} · quedan ${l['days_left']} días',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final r in (l['top'] as List))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    SizedBox(width: 28, child: Text('${r['rank']}', style: const TextStyle(color: W.muted))),
                    Expanded(child: Text('${r['name']}${r['me'] == true ? ' (tú)' : ''}', style: TextStyle(fontWeight: r['me'] == true ? FontWeight.w700 : FontWeight.w400))),
                    Text('${r['xp']} XP'),
                  ]),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aparecer en la liga'),
                value: l['visible'] == true,
                onChanged: controller.setVisible,
              ),
            ]),
          ),
        ),
        _h('Logros · ${a['unlocked']} de ${a['total']}'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final x in (a['achievements'] as List))
            Tooltip(
              message: '${x['desc']}',
              child: Chip(
                avatar: Icon(x['unlocked_at'] != null ? Icons.emoji_events : Icons.lock_outline, size: 18, color: x['unlocked_at'] != null ? const Color(0xFFC0640C) : W.muted),
                label: Text('${x['title']}'),
                backgroundColor: x['unlocked_at'] != null ? const Color(0xFFFFF6C7) : W.card,
              ),
            ),
        ]),
        if (sounds.isNotEmpty) ...[
          _h('Sonidos'),
          for (final x in sounds)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('/${x['phoneme']}/'),
              subtitle: Text(x['mastered'] == true ? 'Dominado' : const {'g': 'Guiado', 'p': 'Práctica', 'd': 'Dominio'}[x['tier']] ?? ''),
              trailing: Text('${x['errors']} fallos', style: const TextStyle(color: W.muted)),
            ),
        ],
        if ((mi['by_category'] as List).isNotEmpty) ...[
          _h('Tus errores por tipo'),
          for (final c in (mi['by_category'] as List)) Text('${c['label']}: ${c['count']}'),
        ],
      ]),
    );
    });
  }

  Widget _h(String t) => Padding(padding: const EdgeInsets.only(top: 22, bottom: 8), child: Text(t, style: W.display(19)));

  Widget _stat(String n, String label) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: W.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: W.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(n, style: W.display(26, color: W.accent)),
          Text(label, style: const TextStyle(color: W.muted, fontSize: 13)),
        ]),
      );
}
