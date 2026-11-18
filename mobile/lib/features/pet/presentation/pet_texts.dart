import 'package:flutter/material.dart';

import '../../../core/l10n/tr.dart';
import '../data/pet.dart';

/// Los colores de cada zona del cerebro (los mismos 5 del cerebro de Brainy).
const petColors = <PetRegion, Color>{
  PetRegion.words: Color(0xFFE6A64A),
  PetRegion.memory: Color(0xFF7C9CFF),
  PetRegion.path: Color(0xFF4AC487),
  PetRegion.habit: Color(0xFFF07A9A),
  PetRegion.links: Color(0xFFB58CFF),
};

/// Nombre de la etapa. Una clave que la app no conoce (servidor más nuevo) sale como «Etapa N».
String petStageName(PetState p) => switch (p.stageKey) {
      'spark' => tr('Chispa'),
      'sprout' => tr('Brote'),
      'curious' => tr('Aprendiz'),
      'chatty' => tr('Voz'),
      'wise' => tr('Mente brillante'),
      _ => tr('Etapa {0}', [p.stage + 1]),
    };

/// Qué enciende cada zona.
String petSkillName(PetRegion r) => switch (r) {
      PetRegion.words => tr('Palabras que conoce'),
      PetRegion.memory => tr('Palabras que recuerda bien'),
      PetRegion.path => tr('Unidades del Camino'),
      PetRegion.habit => tr('Días seguidos'),
      PetRegion.links => tr('Conexiones'),
    };
