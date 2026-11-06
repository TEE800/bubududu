"""Erzeugt die Comicfiguren Bubu & Dudu für die App.

Aufruf im Projektordner:  python3 tool/figuren/export.py
Braucht Python 3 und Node mit Playwright (Chromium) zum Umwandeln in PNG.
Schreibt assets/mascots/<stimmung>.png, dudu.png, bubu.png und
assets/logo/logo.png + logo_foreground.png. Danach für das App-Symbol:
  dart run flutter_launcher_icons
"""
import glob, os, subprocess, sys, tempfile, shutil

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.abspath(os.path.join(here, '..', '..'))
sys.path.insert(0, here)
import figs  # noqa: E402

tmp = tempfile.mkdtemp()
figs.export(tmp)
subprocess.run(['node', os.path.join(here, 'svg2png.js'), *glob.glob(f'{tmp}/*/*.svg')], check=True)
for sub in ('mascots', 'logo'):
    os.makedirs(os.path.join(root, 'assets', sub), exist_ok=True)
    for f in glob.glob(f'{tmp}/{sub}/*.png'):
        shutil.copy(f, os.path.join(root, 'assets', sub, os.path.basename(f)))
print('fertig')
