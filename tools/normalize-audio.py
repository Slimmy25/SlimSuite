"""Build-time MP3 leveling. Run with uv --with imageio-ffmpeg --with soundfile.
The launcher/addon never needs ffmpeg or a second executable at runtime.
"""
import hashlib, json, math, re, subprocess, tempfile
from pathlib import Path
import imageio_ffmpeg
import soundfile as sf
ROOT=Path(__file__).resolve().parents[1]
REPORT=ROOT/'docs/audio-normalization.json'
FFMPEG=imageio_ffmpeg.get_ffmpeg_exe()
def prefix(path):
    info=sf.info(path)
    if info.duration<.4:
        return 'aloop=loop=15:size=%d,atrim=duration=1.2,'%info.frames
    return ''
def measure(path):
    result=subprocess.run([FFMPEG,'-hide_banner','-nostats','-i',str(path),'-af',
        prefix(path)+'loudnorm=I=-16:TP=-2:LRA=11:print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
    return json.loads(re.findall(r'\{[^{}]+\}',result.stderr)[-1])
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
reference=measure(ROOT/'SlimSuite/Whip-Crack.mp3')
prior=json.loads(REPORT.read_text()) if REPORT.exists() else None
target=prior['target_lufs'] if prior else round(float(reference['input_i'])+1.5,1)
assert -70<=target<=-5
report={'target_lufs':target,'reference':'Original Whip-Crack.mp3 integrated loudness + 1.5 dB',
    'true_peak_ceiling_dbtp':-1.0,'analysis':'Integrated loudness; effects under 400 ms repeated only during analysis/normalization, then trimmed to their original duration', 'assets':[]}
prior_assets={row['file']:row for row in prior['assets']} if prior else {}
pending=[]
base_target=target
report['loudness_exceptions']=(prior or {}).get('loudness_exceptions',{})
report['gain_exceptions']=(prior or {}).get('gain_exceptions',{})
report['equalization']={'cena.mp3':'bass gain -3 dB at 120 Hz'}
with tempfile.TemporaryDirectory(prefix='slimsuite-audio-') as folder:
    for path in sorted((ROOT/'SlimSuite').glob('*.mp3')):
        target=base_target+report['loudness_exceptions'].get(path.name,0)
        source_hash=digest(path)
        if path.name in prior_assets and prior_assets[path.name]['sha256']==source_hash and abs(prior_assets[path.name]['integrated_lufs']-target)<=.6:
            report['assets'].append(prior_assets[path.name]); print(path.name,'already normalized',flush=True); continue
        info=sf.info(path); duration=info.frames/info.samplerate
        first=measure(path); output=Path(folder)/path.name
        # Dynamic loudness normalization includes true-peak limiting. Tiny fades avoid abrupt boundaries.
        chain=(prefix(path)+'loudnorm=I=%s:TP=-2:LRA=11:linear=false:print_format=none,'
            'atrim=duration=%.9f,afade=t=in:st=0:d=0.003,afade=t=out:st=%.9f:d=0.012')%(target,duration,max(0,duration-.012))
        subprocess.run([FFMPEG,'-hide_banner','-loglevel','error','-y','-i',str(path),'-af',chain,
            '-ar','48000','-c:a','libmp3lame','-q:a','2',str(output)],check=True)
        final=measure(output)
        # Sparse effects can hit their peak ceiling before reaching the target average.
        # Apply look-ahead peak limiting while raising their average, then remeasure.
        for attempt in range(6):
            difference=target-float(final['input_i'])
            if abs(difference)<=.5: break
            leveled=Path(folder)/('level-%d-'%attempt+path.name)
            chain='volume=%.3fdB,alimiter=limit=0.68:level=false:attack=1:release=40:latency=true'%difference
            subprocess.run([FFMPEG,'-hide_banner','-loglevel','error','-y','-i',str(output),'-af',chain,
                '-c:a','libmp3lame','-q:a','2',str(leveled)],check=True)
            output=leveled; final=measure(output)
        # Use remaining measured peak headroom for very short transient effects.
        difference=target-float(final['input_i'])
        gain=min(difference,-1.25-float(final['input_tp']))
        if difference>.5 and gain>.1:
            lifted=Path(folder)/('lifted-'+path.name)
            subprocess.run([FFMPEG,'-hide_banner','-loglevel','error','-y','-i',str(output),'-af',
                'volume=%.3fdB'%gain,'-c:a','libmp3lame','-q:a','2',str(lifted)],check=True)
            output=lifted; final=measure(output)
        # MP3 reconstruction can overshoot; limit/re-encode if the decoded true peak exceeds -1 dBTP.
        peak=float(final['input_tp'])
        if peak>-1:
            limited=Path(folder)/('limited-'+path.name)
            subprocess.run([FFMPEG,'-hide_banner','-loglevel','error','-y','-i',str(output),'-af',
                'alimiter=limit=0.65:level=false:attack=1:release=40:latency=true','-c:a','libmp3lame','-q:a','2',str(limited)],check=True)
            output=limited; final=measure(output)
        assert float(final['input_tp'])<=-1,path.name
        assert abs(float(final['input_i'])-target)<=.6,(path.name,final['input_i'],target)
        pending.append((path,output.read_bytes()))
        report['assets'].append({'file':path.name,'duration_seconds':round(duration,3),'source_sha256':source_hash,
            'sha256':digest(output),'integrated_lufs':float(final['input_i']),'true_peak_dbtp':float(final['input_tp'])})
        print(path.name,final['input_i'],'LUFS',final['input_tp'],'dBTP',flush=True)
for path,data in pending: path.write_bytes(data)
REPORT.write_text(json.dumps(report,indent=2)+'\n')
print('Normalized',len(report['assets']),'assets; target',target,'LUFS')
