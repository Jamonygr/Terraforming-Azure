"""Re-encode the original artwork for the web; do not alter its composition."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'assets/illustrations/terraforming-azure-cover.png'
target = source.with_suffix('.webp')
with Image.open(source) as image:
    image.convert('RGB').save(target, 'WEBP', quality=88, method=6)
print(f'{source.stat().st_size:,} bytes PNG -> {target.stat().st_size:,} bytes WebP')
