import argparse
import json
import os
import subprocess
import tempfile
from pathlib import Path

import librosa
import numpy as np


def clamp(x, lo=0.0, hi=1.0):
    return max(lo, min(hi, float(x)))


def norm(x, min_v, max_v):
    return clamp((float(x) - min_v) / (max_v - min_v))


def download_audio(video_id, ytdlp_bin="yt-dlp", cookies_browser=None):
    url = f"https://www.youtube.com/watch?v={video_id}"

    tmpdir = tempfile.mkdtemp(prefix="mood_audio_")
    out_tpl = os.path.join(tmpdir, "audio.%(ext)s")

    # Ambil sampel 60 detik agar tidak berat.
    cmd = [
        ytdlp_bin,
        "--no-playlist",
        "-x",
        "--audio-format", "wav",
        "--download-sections", "*00:30-01:30",
        "-o", out_tpl
    ]
    if cookies_browser:
        cmd.extend(["--cookies-from-browser", cookies_browser])
    cmd.append(url)

    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    # Fallback kalau --download-sections gagal di versi yt-dlp tertentu.
    if result.returncode != 0:
        cmd = [
            ytdlp_bin,
            "--no-playlist",
            "-x",
            "--audio-format", "wav",
            "-o", out_tpl
        ]
        if cookies_browser:
            cmd.extend(["--cookies-from-browser", cookies_browser])
        cmd.append(url)
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    if result.returncode != 0:
        raise RuntimeError(result.stderr[-1000:])

    wav_files = list(Path(tmpdir).glob("*.wav"))
    if not wav_files:
        raise RuntimeError("File audio .wav tidak ditemukan setelah download.")

    return str(wav_files[0])


def analyze_audio(audio_path):
    y, sr = librosa.load(audio_path, sr=22050, mono=True, duration=60)

    if len(y) == 0:
        raise RuntimeError("Audio kosong atau gagal dibaca.")

    tempo_arr = librosa.beat.tempo(y=y, sr=sr)
    tempo = float(tempo_arr[0]) if len(tempo_arr) else 0.0

    rms = librosa.feature.rms(y=y)[0]
    rms_mean = float(np.mean(rms))

    loudness_db = float(20 * np.log10(rms_mean + 1e-9))

    centroid = librosa.feature.spectral_centroid(y=y, sr=sr)[0]
    spectral_centroid = float(np.mean(centroid))

    zcr = librosa.feature.zero_crossing_rate(y)[0]
    zcr_mean = float(np.mean(zcr))

    rolloff = librosa.feature.spectral_rolloff(y=y, sr=sr)[0]
    spectral_rolloff = float(np.mean(rolloff))

    # Normalisasi sederhana
    tempo_norm = norm(tempo, 60, 180)
    energy_norm = norm(rms_mean, 0.015, 0.12)
    loudness_norm = norm(loudness_db, -45, -10)
    centroid_norm = norm(spectral_centroid, 1000, 4500)
    zcr_norm = norm(zcr_mean, 0.03, 0.18)
    rolloff_norm = norm(spectral_rolloff, 1500, 8000)

    # Arousal = energi/intensitas lagu
    arousal = clamp(
        0.30 * tempo_norm +
        0.30 * energy_norm +
        0.20 * loudness_norm +
        0.10 * centroid_norm +
        0.10 * rolloff_norm
    )

    # Aggressive score untuk membedakan happy vs angry
    aggression = clamp(
        0.35 * energy_norm +
        0.25 * loudness_norm +
        0.20 * centroid_norm +
        0.20 * zcr_norm
    )

    # Valence di sini masih pendekatan heuristik.
    # Untuk TA tahap awal cukup sebagai rule-based audio mood detector.
    valence = clamp(
        0.55 +
        0.25 * tempo_norm +
        0.10 * rolloff_norm -
        0.30 * aggression -
        0.15 * (1 - energy_norm)
    )

    if arousal >= 0.58 and valence >= 0.50:
        mood = "happy"
    elif arousal >= 0.58 and valence < 0.50:
        mood = "angry"
    elif arousal < 0.48 and valence < 0.55:
        mood = "sad"
    else:
        mood = "neutral"

    return {
        "tempo": round(tempo, 2),
        "rms_energy": round(rms_mean, 5),
        "loudness_db": round(loudness_db, 2),
        "spectral_centroid": round(spectral_centroid, 2),
        "zero_crossing_rate": round(zcr_mean, 5),
        "spectral_rolloff": round(spectral_rolloff, 2),
        "valence": round(valence, 4),
        "arousal": round(arousal, 4),
        "aggression": round(aggression, 4),
        "detected_mood": mood
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--videoId", required=True)
    parser.add_argument("--ytdlp", default=os.environ.get("YTDLP_BIN", "yt-dlp"))
    parser.add_argument("--cookies-browser", help="Browser to extract cookies from (e.g. chrome, edge, firefox) to bypass YouTube 403/429 errors.", default=None)
    args = parser.parse_args()

    try:
        audio_path = download_audio(args.videoId, args.ytdlp, args.cookies_browser)
        result = analyze_audio(audio_path)
        result["ok"] = True
        result["videoId"] = args.videoId
        print(json.dumps(result, ensure_ascii=False))
    except Exception as e:
        print(json.dumps({
            "ok": False,
            "videoId": args.videoId,
            "error": str(e)
        }, ensure_ascii=False))


if __name__ == "__main__":
    main()