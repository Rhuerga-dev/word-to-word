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

/// Nombre de cada barra de cuidados.
String petNeedName(PetNeed n) => switch (n) {
      PetNeed.food => tr('Comida'),
      PetNeed.joy => tr('Ánimo'),
      PetNeed.clean => tr('Limpieza'),
      PetNeed.health => tr('Salud'),
    };

const petNeedColors = <PetNeed, Color>{
  PetNeed.food: Color(0xFFE6A64A),
  PetNeed.joy: Color(0xFFF07A9A),
  PetNeed.clean: Color(0xFF7C9CFF),
  PetNeed.health: Color(0xFF4AC487),
};

/// Los botones de cuidado: un dibujo (emoji, es texto: no hace falta ningún icono nuevo) y su nombre.
String petActionEmoji(PetAction a) => switch (a) {
      PetAction.feed => '🍎',
      PetAction.play => '🎧',
      PetAction.clean => '🧽',
      PetAction.medicine => '💊',
    };

String petActionName(PetAction a) => switch (a) {
      PetAction.feed => tr('Comer'),
      PetAction.play => tr('Jugar'),
      PetAction.clean => tr('Limpiar'),
      PetAction.medicine => tr('Medicina'),
    };

/// Qué ejercicio hay detrás de cada botón.
String petActionHint(PetAction a) => switch (a) {
      PetAction.feed => tr('Palabras nuevas'),
      PetAction.play => tr('Oído'),
      PetAction.clean => tr('Repasos de hoy'),
      PetAction.medicine => tr('Un sonido'),
    };

/// Cuando un botón no tiene nada que hacer ahora.
String petNothingText(PetAction a) => switch (a) {
      PetAction.feed => tr('Hoy ya no quedan palabras para Brainy. Prueba a jugar.'),
      PetAction.clean => tr('Todo limpio: no hay repasos pendientes.'),
      _ => tr('Ahora no se puede. Inténtalo en un rato.'),
    };

/// Cómo está, en una frase tranquila (nunca culpa ni dramatiza).
String petMoodText(PetCare c) => switch (c.mood) {
      'hibernating' => tr('Brainy está hibernando. Haz cualquier ejercicio y despierta.'),
      'asleep' => tr('Brainy duerme. Si estudias ahora, mañana lo nota.'),
      'sick' => tr('Brainy no se siente bien. Su medicina es practicar un sonido.'),
      'hungry' => tr('Brainy tiene hambre de palabras.'),
      'messy' => tr('Hay repasos pendientes por ordenar.'),
      'bored' => tr('Brainy quiere jugar.'),
      'happy' => tr('Brainy está feliz.'),
      _ => tr('Brainy está bien.'),
    };

/// Lo que dice Brainy, siempre en inglés muy fácil (leerla también es practicar). null = no dice nada.
String? petBubble(PetCare c) => switch (c.mood) {
      'hibernating' || 'asleep' => 'Zzz…',
      'sick' => 'I feel sick.',
      'hungry' => "I'm hungry!",
      'messy' => 'What a mess!',
      'bored' => "Let's play!",
      'happy' => "I'm happy!",
      _ => null,
    };

/// Lo que dice al volver de un cuidado.
String petThanks(PetAction a) => switch (a) {
      PetAction.feed => 'Yum! Thank you!',
      PetAction.play => 'That was fun!',
      PetAction.clean => 'So clean!',
      PetAction.medicine => 'I feel better!',
    };

/// Su forma adulta (o hacia cuál va). Una que la app no conoce no se nombra.
String? petFormName(String? form) => switch (form) {
      'talker' => tr('Parlanchina'),
      'listener' => tr('Orejona'),
      'scholar' => tr('Sabia'),
      'balanced' => tr('Equilibrada'),
      _ => null,
    };

/// Nombre de una etapa por su clave (para su historial).
String petStageKeyName(String key) => petStageName(PetState(stageKey: key));
