#!/usr/bin/env python3
"""Synthetic host-only AAC candidate check. Never imports microphone/user audio."""
import hashlib, json, math, pathlib, struct, subprocess, tempfile, wave
root = pathlib.Path(tempfile.mkdtemp(prefix="voiceprobe-codec-"))
report = {"environment": "macOS afconvert; synthetic PCM16 only", "speech_quality": "NOT RUN", "cases": []}
for rate, frames, channels in [(48000, 480, 1), (48000, 48000, 1), (44100, 44100, 2)]:
    stem = f"{rate}-{frames}-{channels}"
    src, aac, dst = [root / (stem + suffix) for suffix in (".wav", ".m4a", "-decoded.wav")]
    # Distinct quarter tones detect order swaps; includes first/last short boundaries.
    samples = [int(12000 * math.sin(2 * math.pi * (300 + 200 * (4*i//frames) + c*50) * i / rate))
               for i in range(frames) for c in range(channels)]
    with wave.open(str(src), "wb") as f:
        f.setnchannels(channels); f.setsampwidth(2); f.setframerate(rate)
        f.writeframes(struct.pack("<" + "h" * len(samples), *samples))
    before = hashlib.sha256(src.read_bytes()).hexdigest()
    subprocess.run(["/usr/bin/afconvert", "-f", "m4af", "-d", f"aac@{rate}", "-b", "64000", str(src), str(aac)], check=True)
    subprocess.run(["/usr/bin/afconvert", "-f", "WAVE", "-d", "LEI16", str(aac), str(dst)], check=True)
    # afconvert emits WAVE_FORMAT_EXTENSIBLE; Python 3.11 wave cannot read it.
    blob = dst.read_bytes()
    assert blob[:4] == b"RIFF" and blob[8:12] == b"WAVE"
    chunks, offset = {}, 12
    while offset + 8 <= len(blob):
        name, size = struct.unpack_from("<4sI", blob, offset)
        chunks[name] = blob[offset+8:offset+8+size]
        offset += 8 + size + (size % 2)
    tag, decoded_channels, decoded_rate, _, align, bits = struct.unpack_from("<HHIIHH", chunks[b"fmt "])
    assert bits == 16 and (tag == 1 or (tag == 65534 and struct.unpack_from("<I", chunks[b"fmt "], 24)[0] == 1))
    raw = chunks[b"data"]
    decoded_frames = len(raw) // align
    assert hashlib.sha256(src.read_bytes()).hexdigest() == before, "original changed"
    assert (decoded_rate, decoded_channels) == (rate, channels), "format changed"
    assert decoded_frames == frames, "playable duration mismatch; inspect priming/padding"
    decoded = struct.unpack("<" + "h" * (len(raw)//2), raw)
    correlation = sum(a*b for a,b in zip(samples, decoded)) / math.sqrt(sum(a*a for a in samples)*sum(b*b for b in decoded))
    assert correlation > 0.9, "synthetic chronology/phase mismatch"
    report["cases"].append(dict(rate=rate, channels=channels, source_frames=frames, decoded_frames=decoded_frames,
        pcm_sha256=before, encoded_bytes=aac.stat().st_size, correlation=round(correlation, 5),
        original_preserved=True))
report["artifacts"] = str(root)
report["limitations"] = "No RU/EN/name/number/negation ASR, watch encoder, energy, or arbitrary decoder proof. No receipt authorization."
print(json.dumps(report, indent=2))
