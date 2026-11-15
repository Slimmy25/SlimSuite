"""Validate the measured audio assets without requiring an audio decoder in CI."""
import hashlib,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
report=json.loads((root/'docs/audio-normalization.json').read_text())
assets={p.name:p for p in (root/'SlimSuite').glob('*.mp3')}
assert set(assets)=={row['file'] for row in report['assets']},'Audio inventory changed; normalize new assets'
for row in report['assets']:
    assert hashlib.sha256(assets[row['file']].read_bytes()).hexdigest()==row['sha256'],row['file']
    assert row['true_peak_dbtp']<=report['true_peak_ceiling_dbtp'],row['file']
    assert abs(row['integrated_lufs']-report['target_lufs'])<=.6,row['file']
print('Audio checks passed:',len(assets),'assets, measured peaks and loudness within bounds')
