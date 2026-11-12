/// Técnicas de pronunciación para hispanohablantes (las mismas que la web, public/app/app.js → PRON_TIPS).
/// Clave = fonema IPA como lo devuelve Azure. [pair] = palabras de contraste para practicar.
class PronTip {
  const PronTip(this.phoneme, this.name, this.how, this.pair);
  final String phoneme, name, how, pair;
}

const pronTips = <String, PronTip>{
  'θ': PronTip('θ', 'TH suave (think)', 'Saca la punta de la lengua entre los dientes y sopla aire sin vibrar. No es “s” ni “t”.', 'think / sink · three / tree'),
  'ð': PronTip('ð', 'TH sonora (this)', 'Lengua entre los dientes igual que en “think”, pero haciendo vibrar la garganta. Suena parecido a la “d” suave de “cada”.', 'they / day · then / den'),
  'v': PronTip('v', 'V (very)', 'Apoya los dientes de arriba sobre el labio de abajo y haz vibrar. No juntes los labios: eso es “b”.', 'very / berry · vote / boat'),
  'b': PronTip('b', 'B (boat)', 'Junta los dos labios y suéltalos con fuerza. Diferénciala de la “v”, que usa dientes y labio.', 'ban / van · best / vest'),
  'ʃ': PronTip('ʃ', 'SH (she)', 'Redondea los labios hacia adelante y deja salir el aire como cuando pides silencio: “shhh”.', 'she / see · ship / sip'),
  'tʃ': PronTip('tʃ', 'CH (check)', 'Como la “ch” del español, pero con los labios un poco hacia adelante.', 'chip / ship · watch / wash'),
  'dʒ': PronTip('dʒ', 'J (job)', 'Como “ch” pero haciendo vibrar la garganta. No es la “j” española ni la “y”.', 'job / yob · jet / yet'),
  'ʒ': PronTip('ʒ', 'Sonido de “usual”', 'Como “sh” pero vibrando la garganta, parecido a la “ll” rioplatense.', 'usual · vision · measure'),
  'z': PronTip('z', 'Z inglesa (zoo, is)', 'Es una “s” que vibra: pon la mano en el cuello y siente el zumbido. La “s” final de “is”, “was” y “has” suena así.', 'zoo / sue · prize / price'),
  'h': PronTip('h', 'H aspirada (house)', 'Solo aire suave desde la garganta, como empañar un espejo. No la raspes como la “j” española.', 'hat / at · hold / old'),
  'ɹ': PronTip('ɹ', 'R inglesa (red)', 'Curva la lengua hacia atrás sin tocar el paladar y redondea un poco los labios. No vibra como la “r” española.', 'right / light · road / load'),
  'r': PronTip('r', 'R inglesa (red)', 'Curva la lengua hacia atrás sin tocar el paladar y redondea un poco los labios. No vibra como la “r” española.', 'right / light · road / load'),
  'ŋ': PronTip('ŋ', 'NG final (thing)', 'Termina con la parte de atrás de la lengua contra el paladar, sin soltar una “g” al final.', 'thing / thin · sing / sin'),
  'j': PronTip('j', 'Y (yes)', 'Una “i” muy corta antes de la vocal. No la conviertas en “ll” ni en “j” inglesa.', 'yes / Jess · yet / jet'),
  'w': PronTip('w', 'W (work)', 'Empieza con los labios redondos como para decir “u” y ábrelos rápido. No pongas “g” delante.', 'would / good · west / guest'),
  'ɪ': PronTip('ɪ', 'I corta (ship)', 'Más relajada y corta que la “i” española, casi entre “i” y “e”. La boca casi no sonríe.', 'ship / sheep · live / leave'),
  'i': PronTip('i', 'I larga (sheep)', 'Una “i” más larga y tensa, sonriendo un poco.', 'sheep / ship · seat / sit'),
  'æ': PronTip('æ', 'A abierta (cat)', 'Abre mucho la boca, como para “a”, pero estira los labios como para “e”. Queda entre las dos.', 'cat / cut · bad / bed'),
  'ʌ': PronTip('ʌ', 'A corta (cup)', 'Una “a” breve y relajada, con la boca medio abierta, sin tensión.', 'cup / cap · luck / lock'),
  'ə': PronTip('ə', 'Vocal neutra (about)', 'Una vocal muy débil y corta, casi un murmullo “uh”. Las sílabas sin acento casi siempre suenan así.', 'about · banana · problem'),
  'ɑ': PronTip('ɑ', 'A larga (car)', 'Abre la boca grande y baja la lengua, como cuando el médico te pide “aaa”.', 'hot · father · stop'),
  'ɔ': PronTip('ɔ', 'O abierta (law)', 'Labios redondos y boca abierta, una “o” más larga y profunda que la española.', 'law / low · caught / coat'),
  'ʊ': PronTip('ʊ', 'U corta (book)', 'Una “u” relajada y corta, sin redondear mucho los labios.', 'full / fool · look / Luke'),
  'u': PronTip('u', 'U larga (food)', 'Una “u” larga con los labios bien redondos hacia adelante.', 'fool / full · pool / pull'),
  'oʊ': PronTip('oʊ', 'O deslizada (go)', 'Empieza en “o” y termina cerrando los labios hacia “u”: “ou”.', 'go · phone · know'),
  'eɪ': PronTip('eɪ', 'E deslizada (day)', 'Empieza en “e” y termina en una “i” suave: “ei”.', 'day · late · rate'),
  'ɜ': PronTip('ɜ', 'ER (work)', 'Lengua en el centro de la boca y un poco hacia atrás, labios relajados; suena “er” sin vibrar.', 'work / walk · bird / bud'),
  'ɝ': PronTip('ɝ', 'ER (work)', 'Lengua en el centro de la boca y un poco hacia atrás, labios relajados; suena “er” sin vibrar.', 'work / walk · bird / bud'),
  't': PronTip('t', 'T final', 'Pronuncia la “t” al final aunque sea suave; si la quitas, cambia la palabra (“bet” y “bed”).', 'bet / bed · cart / car'),
  'd': PronTip('d', 'D final', 'Haz vibrar la garganta al final: la vocal antes de “d” se alarga un poco.', 'bed / bet · need / neat'),
  's': PronTip('s', 'S', 'Una “s” clara y sin vibración. Al inicio con consonante (speak, start) no pongas “e” delante.', 'speak · school · start'),
};

/// La técnica general: lento → normal.
const slowToNormal = PronTip('', 'Técnica: lento → normal',
    'Escúchala lenta, dila separando sílabas, y luego 3 veces seguidas a velocidad normal. Exagera la boca al principio.', '');

/// Pistas por la ortografía, cuando no hay detalle de sonidos (sin Azure o sin conexión).
List<String> spellingTips(String word) {
  final w = word.toLowerCase();
  final out = <String>[];
  if (w.contains('th')) {
    out.add(RegExp(r'^(the|this|that|these|those|they|them|then|there|than|though)$').hasMatch(w) ? 'ð' : 'θ');
  }
  if (w.contains('v')) out.add('v');
  if (RegExp(r'sh|tion|sion').hasMatch(w)) out.add('ʃ');
  if (RegExp(r'^s[ptkcmnlw]').hasMatch(w)) out.add('s');
  if (w.startsWith('h') && !RegExp(r'^(hour|honest)').hasMatch(w)) out.add('h');
  if (w.contains('r')) out.add('ɹ');
  if (w.endsWith('ng')) out.add('ŋ');
  if (RegExp(r'^(w|wh)').hasMatch(w)) out.add('w');
  if (RegExp(r'^(is|was|has|does|goes|his|hers)$').hasMatch(w)) out.add('z');
  if (RegExp(r'[td]$').hasMatch(w)) out.add(w.endsWith('t') ? 't' : 'd');
  return out;
}

/// La técnica para un sonido de Azure (acepta las largas, "iː" → "i").
PronTip? tipFor(String phoneme) => pronTips[phoneme] ?? pronTips[phoneme.replaceAll('ː', '')];

/// Una palabra que no salió bien y cómo decirla.
class WordTips {
  const WordTips(this.word, this.tips);
  final String word;
  final List<PronTip> tips;
}

/// De lo que devolvió el servidor (o, si no hay detalle, de la ortografía de las palabras que fallaron):
/// hasta 2 palabras con hasta 2 técnicas cada una, sin repetir técnicas.
List<WordTips> buildTips(List<(String word, List<String> phonemes)> weak) {
  final seen = <String>{};
  final out = <WordTips>[];
  for (final (word, phonemes) in weak) {
    final keys = phonemes.isNotEmpty ? phonemes : spellingTips(word);
    final tips = <PronTip>[];
    for (final k in keys) {
      final t = tipFor(k);
      if (t == null || seen.contains(t.name)) continue;
      seen.add(t.name);
      tips.add(t);
      if (tips.length == 2) break;
    }
    if (tips.isNotEmpty) out.add(WordTips(word, tips));
    if (out.length == 2) break;
  }
  return out;
}
