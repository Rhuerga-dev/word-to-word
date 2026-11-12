"""Baja (una vez) las fuentes de Google Fonts que usa W2W, para las capturas de prueba.

Lee las direcciones exactas del paquete google_fonts instalado y guarda cada variante como
test/fonts/<Familia>_<variante>.ttf, el mismo nombre de familia que usa google_fonts al dibujar.
"""
import glob, os, re, sys, urllib.request

WANT = {  # método de google_fonts -> variantes (peso o peso+italic)
    'atkinsonHyperlegible': ['400', '700', '400i', '700i'],
    'bricolageGrotesque': ['500', '600', '700', '800'],
    'caveat': ['400', '600', '700'],
    'notoSans': ['400', '700'],      # respaldo: símbolos fonéticos (/ɪ/, /ʌ/…)
    'notoEmoji': ['400'],            # respaldo: emojis
}
here = os.path.dirname(os.path.abspath(__file__))
lock = open(os.path.join(here, '..', '..', 'pubspec.lock')).read()
ver = re.search(r'google_fonts:\n(?:.*\n){0,6}?\s+version: "([^"]+)"', lock).group(1)
src = os.path.expanduser(f'~/.pub-cache/hosted/pub.dev/google_fonts-{ver}/lib/src/google_fonts_parts')
code = ''.join(open(f).read() for f in sorted(glob.glob(src + '/*.dart')))
for method, variants in WANT.items():
    m = re.search(r'static TextStyle ' + method + r'\((.*?)\n  static TextStyle ', code, re.S)
    if not m:
        print('no encuentro', method); continue
    body = m.group(1)
    family = re.search(r"fontFamily: '([^']+)'", body).group(1)
    for v in variants:
        italic = v.endswith('i'); w = v.rstrip('i')
        pat = r'fontWeight: FontWeight\.w' + w + r',\s*fontStyle: FontStyle\.' + ('italic' if italic else 'normal') + r",?\s*\)\s*:\s*GoogleFontsFile\(\s*'([0-9a-f]+)'"
        h = re.search(pat, body)
        if not h:
            print('sin variante', family, v); continue
        name = {('400', False): 'regular', ('400', True): 'italic'}.get((w, italic), w + ('italic' if italic else ''))
        out = os.path.join(here, f'{family}_{name}.ttf')
        if not os.path.exists(out):
            urllib.request.urlretrieve(f'https://fonts.gstatic.com/s/a/{h.group(1)}.ttf', out)
        print('ok', os.path.basename(out), os.path.getsize(out))
