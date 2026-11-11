"""Icono de Word to Word (opción A: micrófono). Genera full.png (con fondo) y fg.png (primer plano adaptativo de Android)."""
import asyncio
from playwright.async_api import async_playwright

ART = '''
<rect x="402" y="200" width="220" height="380" rx="110" fill="#FFE45C"/>
<path d="M300 500 a212 212 0 0 0 424 0" fill="none" stroke="#ffffff" stroke-width="48" stroke-linecap="round"/>
<path d="M512 712 v110 M412 822 h200" stroke="#ffffff" stroke-width="48" stroke-linecap="round"/>
<path d="M210 400 a330 330 0 0 0 0 200 M814 400 a330 330 0 0 1 0 200" fill="none" stroke="#8fa8e8" stroke-width="36" stroke-linecap="round"/>'''

def svg(bg, scale):
    b = '<rect width="1024" height="1024" fill="#1F4FD1"/>' if bg else ''
    # el dibujo ocupa y 200..822: se centra en vertical
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024">{b}'
            f'<g transform="translate(512 512) scale({scale}) translate(-512 -511)">{ART}</g></svg>')

async def main():
    async with async_playwright() as p:
        br = await p.chromium.launch()
        pg = await br.new_page(viewport={'width': 1024, 'height': 1024})
        for name, s in [('full', svg(True, 1.0)), ('fg', svg(False, 0.8))]:
            await pg.set_content(f'<body style="margin:0;background:transparent">{s}</body>')
            await pg.screenshot(path=f'{name}.png', omit_background=True)
        await br.close()

asyncio.run(main())
