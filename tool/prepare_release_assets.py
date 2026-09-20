"""Fetch public, pinned build dependencies; never package user documents."""
import hashlib
import json
import pathlib
import shutil
import subprocess
import tempfile
import urllib.request

root = pathlib.Path(__file__).resolve().parents[1]
fonts = root / 'assets/fonts'
fonts.mkdir(parents=True, exist_ok=True)
font = fonts / 'Inter-Variable.ttf'
expected = '29160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031'
if not font.exists():
    urllib.request.urlretrieve('https://raw.githubusercontent.com/google/fonts/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf', font)
if hashlib.sha256(font.read_bytes()).hexdigest() != expected:
    raise RuntimeError('Inter font checksum mismatch; review upstream before publishing')
with tempfile.TemporaryDirectory() as temp:
    subprocess.run([shutil.which('npm') or 'npm.cmd', 'install', '--prefix', temp,
                    '--ignore-scripts', '--no-audit', '--no-fund', 'pdfjs-dist@6.3.289'], check=True)
    source = pathlib.Path(temp) / 'node_modules/pdfjs-dist'
    dest = root / 'web/vendor/pdfjs'
    dest.mkdir(parents=True, exist_ok=True)
    for name in ['pdf.mjs', 'pdf.worker.mjs']:
        shutil.copy2(source / 'legacy/build' / name, dest / name)
    for name in ['cmaps', 'standard_fonts', 'wasm']:
        shutil.copytree(source / name, dest / name, dirs_exist_ok=True)
    shutil.copy2(source / 'LICENSE', dest / 'LICENSE')
    (dest / 'VERSION').write_text('6.3.289\n')
print('Public assets ready; Inter checksum verified, PDF.js 6.3.289.')
