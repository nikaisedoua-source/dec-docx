"""Give each compiled web release its own asset URLs, including icon fonts."""
import json
from pathlib import Path
import shutil
import sys

output = Path(sys.argv[1] if len(sys.argv) > 1 else 'build/web')
version = json.loads((output / 'version.json').read_text())['version']
if not version or any(c not in '0123456789.' for c in version):
    raise ValueError('Invalid release version')
destination = output / 'releases' / version / 'assets'
shutil.copytree(output / 'assets', destination, dirs_exist_ok=True)
print(f'Web assets prepared for {version}: {destination}')
