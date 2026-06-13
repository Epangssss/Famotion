import os
import json
import shutil
import subprocess
from pathlib import Path

import librosa
import numpy as np
import pandas as pd
from tqdm import tqdm


# =========================
# PATH DATASET 
# =========================
BASE_DIR = r"C:\famotion\famotion\python\label-final"
DATASET_DIRS = {
    "random": BASE_DIR + r"\random",
}
# DATASET_DIRS = {
#     "sad": BASE_DIR + r"\sad",
#     "angry": BASE_DIR + r"\anger",
#     "happy": BASE_DIR + r"\happy",
#     "neutral": BASE_DIR + r"\neutral",
# }

OUTPUT_DIR = r"C:\famotion\famotion\python\hasil_analisis-test2"
CLEAN_DIR = r"C:\famotion\famotion\python\clean_by_predicted_mood-test2"

AUDIO_EXTS = {".mp3", ".wav", ".m4a", ".flac", ".ogg", ".aac", ".webm"}


def clamp(x, lo=0.0, hi=1.0):
    return max(lo, min(hi, float(x)))


def norm(x, min_v, max_v):
    if max_v == min_v:
        return 0.0
    return clamp((float(x) - min_v) / (max_v - min_v))


def get_bitrate_kbps(path):
    """
    Bitrate hanya dipakai sebagai kualitas file, bukan penentu mood.
    Butuh ffprobe dari ffmpeg.
    """
    try:
        cmd = [
            "ffprobe",
            "-v", "error",
            "-select_streams", "a:0",
            "-show_entries", "stream=bit_rate",
            "-of", "default=noprint_wrappers=1:nokey=1",
            str(path)
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        value = result.stdout.strip()
        if value and value.isdigit():
            return round(int(value) / 1000, 2)
    except Exception:
        pass
    return None


def estimate_mode_from_chroma(chroma_mean):
    """
    Estimasi major/minor sederhana dari chroma.
    Ini bukan deteksi kunci sempurna, hanya indikator tambahan.
    """
    major_profile = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09,
                              2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
    minor_profile = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53,
                              2.54, 4.75, 3.98, 2.69, 3.34, 3.17])

    chroma = np.array(chroma_mean)
    if chroma.sum() == 0:
        return "unknown", 0.0

    chroma = (chroma - chroma.mean()) / (chroma.std() + 1e-9)
    major_profile = (major_profile - major_profile.mean()) / major_profile.std()
    minor_profile = (minor_profile - minor_profile.mean()) / minor_profile.std()

    best_major = max(np.corrcoef(np.roll(major_profile, i), chroma)[0, 1] for i in range(12))
    best_minor = max(np.corrcoef(np.roll(minor_profile, i), chroma)[0, 1] for i in range(12))

    if best_major >= best_minor:
        return "major", float(best_major)
    return "minor", float(best_minor)


def analyze_audio(path):
    # Ambil maksimal 90 detik agar proses cepat dan stabil
    y, sr = librosa.load(path, sr=22050, mono=True, duration=90)

    if len(y) == 0:
        raise ValueError("Audio kosong atau gagal dibaca.")

    # Fitur utama
    tempo_arr = librosa.beat.tempo(y=y, sr=sr)
    tempo = float(tempo_arr[0]) if len(tempo_arr) else 0.0

    rms = librosa.feature.rms(y=y)[0]
    rms_mean = float(np.mean(rms))

    loudness_db = float(20 * np.log10(rms_mean + 1e-9))

    centroid = librosa.feature.spectral_centroid(y=y, sr=sr)[0]
    spectral_centroid = float(np.mean(centroid))

    rolloff = librosa.feature.spectral_rolloff(y=y, sr=sr)[0]
    spectral_rolloff = float(np.mean(rolloff))

    zcr = librosa.feature.zero_crossing_rate(y)[0]
    zcr_mean = float(np.mean(zcr))

    chroma = librosa.feature.chroma_stft(y=y, sr=sr)
    chroma_mean = np.mean(chroma, axis=1)
    mode, mode_conf = estimate_mode_from_chroma(chroma_mean)

    mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
    mfcc_mean = np.mean(mfcc, axis=1)

    # Normalisasi heuristik
    tempo_n = norm(tempo, 60, 180)
    energy_n = norm(rms_mean, 0.015, 0.12)
    loudness_n = norm(loudness_db, -45, -10)
    centroid_n = norm(spectral_centroid, 900, 4500)
    rolloff_n = norm(spectral_rolloff, 1500, 8500)
    zcr_n = norm(zcr_mean, 0.02, 0.18)

    # Arousal = intensitas/energi musik
    arousal = clamp(
        0.30 * tempo_n +
        0.30 * energy_n +
        0.20 * loudness_n +
        0.10 * centroid_n +
        0.10 * rolloff_n
    )

    # Aggression = keras, tajam, intens
    aggression = clamp(
        0.35 * energy_n +
        0.25 * loudness_n +
        0.20 * centroid_n +
        0.20 * zcr_n
    )

    # Mode mayor menaikkan valence, minor menurunkan valence
    mode_bonus = 0.10 if mode == "major" else -0.10 if mode == "minor" else 0

    # Valence = positif/negatif nuansa lagu
    # Ini rule-based, bukan model supervised.
    valence = clamp(
        0.52 +
        0.20 * tempo_n +
        0.12 * energy_n +
        mode_bonus -
        0.28 * aggression -
        0.10 * (1 - loudness_n)
    )

    # Rule mood berdasarkan pola jurnal:
    # happy: valence tinggi + arousal tinggi
    # sad: valence rendah + arousal rendah
    # angry: valence rendah + arousal tinggi/aggression tinggi
    # neutral: di tengah/rendah
    if arousal >= 0.58 and valence >= 0.50 and aggression < 0.78:
        predicted_mood = "happy"
    elif arousal >= 0.55 and (valence < 0.50 or aggression >= 0.72):
        predicted_mood = "angry"
    elif arousal < 0.48 and valence < 0.52:
        predicted_mood = "sad"
    else:
        predicted_mood = "neutral"

    confidence = max(
        abs(arousal - 0.50),
        abs(valence - 0.50),
        aggression * 0.35
    )
    confidence = clamp(confidence * 1.4)

    return {
        "tempo_bpm": round(tempo, 2),
        "rms_energy": round(rms_mean, 6),
        "loudness_db": round(loudness_db, 2),
        "spectral_centroid": round(spectral_centroid, 2),
        "spectral_rolloff": round(spectral_rolloff, 2),
        "zero_crossing_rate": round(zcr_mean, 6),
        "mode_estimate": mode,
        "mode_confidence": round(mode_conf, 4),
        "valence": round(valence, 4),
        "arousal": round(arousal, 4),
        "aggression": round(aggression, 4),
        "predicted_mood": predicted_mood,
        "confidence": round(confidence, 4),
        "mfcc_mean": [round(float(x), 4) for x in mfcc_mean],
    }


def iter_audio_files():
    for folder_label, folder_path in DATASET_DIRS.items():
        p = Path(folder_path)
        if not p.exists():
            print(f"Folder tidak ditemukan: {p}")
            continue

        for file in p.rglob("*"):
            if file.is_file() and file.suffix.lower() in AUDIO_EXTS:
                yield folder_label, file


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    os.makedirs(CLEAN_DIR, exist_ok=True)

    rows = []
    files = list(iter_audio_files())

    print(f"Total file audio ditemukan: {len(files)}")

    for original_label, audio_path in tqdm(files, desc="Analisis lagu"):
        try:
            features = analyze_audio(str(audio_path))
            bitrate = get_bitrate_kbps(audio_path)

            row = {
                "file_name": audio_path.name,
                "file_path": str(audio_path),
                "original_folder_label": original_label,
                "bitrate_kbps": bitrate,
                "quality_status": "ok" if (bitrate is None or bitrate >= 128) else "low_bitrate",
                **features
            }

            rows.append(row)

            # COPY ke folder hasil berdasarkan prediksi, jangan move agar data asli aman
            pred = features["predicted_mood"]
            target_dir = Path(CLEAN_DIR) / pred
            target_dir.mkdir(parents=True, exist_ok=True)

            safe_name = f"{original_label}__{audio_path.name}"
            target_file = target_dir / safe_name

            if not target_file.exists():
                shutil.copy2(audio_path, target_file)

        except Exception as e:
            rows.append({
                "file_name": audio_path.name,
                "file_path": str(audio_path),
                "original_folder_label": original_label,
                "error": str(e)
            })

    df = pd.DataFrame(rows)

    csv_path = Path(OUTPUT_DIR) / "hasil_analisis_lagu.csv"
    json_path = Path(OUTPUT_DIR) / "hasil_analisis_lagu.json"
    summary_path = Path(OUTPUT_DIR) / "ringkasan_mood.csv"

    df.to_csv(csv_path, index=False, encoding="utf-8-sig")
    df.to_json(json_path, orient="records", force_ascii=False, indent=2)

    if "predicted_mood" in df.columns:
        summary = pd.crosstab(
            df["original_folder_label"],
            df["predicted_mood"],
            margins=True
        )
        summary.to_csv(summary_path, encoding="utf-8-sig")
        print("\n=== RINGKASAN LABEL FOLDER VS PREDIKSI AUDIO ===")
        print(summary)

    print("\nSelesai.")
    print(f"CSV    : {csv_path}")
    print(f"JSON   : {json_path}")
    print(f"CLEAN  : {CLEAN_DIR}")


if __name__ == "__main__":
    main()