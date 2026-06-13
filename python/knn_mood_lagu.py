import os
import ast
import json
import shutil
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from tqdm import tqdm

from sklearn.model_selection import train_test_split, GridSearchCV
from sklearn.preprocessing import StandardScaler
from sklearn.neighbors import KNeighborsClassifier
from sklearn.pipeline import Pipeline
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score


# =====================================================
# PATH INPUT DARI HASIL ANALISIS LIBROSA SEBELUMNYA
# =====================================================
CSV_PATH = r"C:\famotion\famotion\python\hasil_analisis-test2\hasil_analisis_lagu.csv"
JSON_PATH = r"C:\famotion\famotion\python\hasil_analisis-test2\hasil_analisis_lagu.json"
OLD_SUMMARY_PATH = r"C:\famotion\famotion\python\hasil_analisis-test2\ringkasan_mood.csv"

# Folder hasil rule-based sebelumnya
CLEAN_RULE_BASED_DIR = r"C:\famotion\famotion\python\clean_by_predicted_mood-test2"

# Folder output KNN
OUTPUT_DIR = r"C:\famotion\famotion\python\hasil_analisis-test2\knn_result"
CLEAN_KNN_DIR = r"C:\famotion\famotion\python\clean_by_knn_mood-test2"

MODEL_PATH = os.path.join(OUTPUT_DIR, "knn_mood_lagu_model.pkl")
RESULT_CSV_PATH = os.path.join(OUTPUT_DIR, "hasil_analisis_lagu_knn.csv")
RESULT_JSON_PATH = os.path.join(OUTPUT_DIR, "hasil_analisis_lagu_knn.json")
SUMMARY_KNN_PATH = os.path.join(OUTPUT_DIR, "ringkasan_mood_knn.csv")
REPORT_PATH = os.path.join(OUTPUT_DIR, "classification_report_knn.txt")
CONFUSION_MATRIX_PATH = os.path.join(OUTPUT_DIR, "confusion_matrix_knn.csv")


# =====================================================
# FITUR YANG DIPAKAI KNN
# =====================================================
BASE_FEATURES = [
    "tempo_bpm",
    "rms_energy",
    "loudness_db",
    "spectral_centroid",
    "spectral_rolloff",
    "zero_crossing_rate",
    "mode_confidence",
    "valence",
    "arousal",
    "aggression",
]

MOOD_ORDER = ["angry", "happy", "sad", "neutral"]


def load_data():
    """
    Prioritas baca JSON karena mfcc_mean di JSON masih berupa list asli.
    Kalau JSON tidak ada, baca CSV.
    """
    if os.path.exists(JSON_PATH):
        print(f"Membaca JSON: {JSON_PATH}")
        df = pd.read_json(JSON_PATH)
    elif os.path.exists(CSV_PATH):
        print(f"Membaca CSV: {CSV_PATH}")
        df = pd.read_csv(CSV_PATH)
    else:
        raise FileNotFoundError("File hasil_analisis_lagu.csv/json tidak ditemukan.")

    return df


def parse_mfcc(value):
    """
    Mengubah mfcc_mean menjadi list angka.
    Bisa dari JSON list asli atau dari CSV string seperti '[1, 2, 3]'.
    """
    if isinstance(value, list):
        return value

    if isinstance(value, np.ndarray):
        return value.tolist()

    if pd.isna(value):
        return [0.0] * 13

    if isinstance(value, str):
        try:
            parsed = ast.literal_eval(value)
            if isinstance(parsed, list):
                return parsed
        except Exception:
            pass

    return [0.0] * 13


def prepare_features(df):
    """
    Membersihkan data dan membuat fitur numerik untuk KNN.
    """
    df = df.copy()

    # Buang baris error atau baris tanpa mood
    if "error" in df.columns:
        df = df[df["error"].isna() | (df["error"].astype(str).str.strip() == "")]

    df = df.dropna(subset=["predicted_mood"])

    # Kalau nanti Papa punya label manual, gunakan manual_mood sebagai label utama.
    # Kalau belum ada, KNN akan belajar dari predicted_mood rule-based.
    if "manual_mood" in df.columns:
        label_col = "manual_mood"
        print("Label training memakai kolom: manual_mood")
    else:
        label_col = "predicted_mood"
        print("Label training memakai kolom: predicted_mood")
        print("Catatan: ini berarti KNN belajar dari hasil rule-based Librosa sebelumnya.")

    df[label_col] = df[label_col].astype(str).str.lower().str.strip()

    # Ambil hanya label mood yang valid
    df = df[df[label_col].isin(MOOD_ORDER)]

    # Pastikan kolom fitur utama ada
    for col in BASE_FEATURES:
        if col not in df.columns:
            df[col] = 0.0

    # Konversi fitur utama ke numerik
    for col in BASE_FEATURES:
        df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0.0)

    # Mode estimate: major/minor/unknown jadi fitur one-hot
    if "mode_estimate" not in df.columns:
        df["mode_estimate"] = "unknown"

    df["mode_estimate"] = df["mode_estimate"].fillna("unknown").astype(str).str.lower()

    mode_dummies = pd.get_dummies(df["mode_estimate"], prefix="mode")
    df = pd.concat([df, mode_dummies], axis=1)

    mode_features = list(mode_dummies.columns)

    # MFCC jadi 13 kolom
    if "mfcc_mean" not in df.columns:
        df["mfcc_mean"] = [[0.0] * 13 for _ in range(len(df))]

    mfcc_values = df["mfcc_mean"].apply(parse_mfcc)

    for i in range(13):
        df[f"mfcc_{i+1}"] = mfcc_values.apply(
            lambda x: float(x[i]) if len(x) > i else 0.0
        )

    mfcc_features = [f"mfcc_{i+1}" for i in range(13)]

    feature_cols = BASE_FEATURES + mode_features + mfcc_features

    X = df[feature_cols].fillna(0.0)
    y = df[label_col]

    return df, X, y, feature_cols, label_col


def train_knn(X, y):
    """
    Training KNN dengan StandardScaler.
    KNN sensitif terhadap skala angka, jadi scaler wajib.
    """
    if len(X) < 2:
        raise ValueError("Data terlalu sedikit untuk training KNN.")

    class_counts = y.value_counts()
    print("\nJumlah data per label:")
    print(class_counts)

    # Split bisa stratify kalau tiap kelas minimal punya 2 data
    can_stratify = class_counts.min() >= 2 and len(class_counts) > 1

    if can_stratify:
        X_train, X_test, y_train, y_test = train_test_split(
            X,
            y,
            test_size=0.2,
            random_state=42,
            stratify=y
        )
    else:
        X_train, X_test, y_train, y_test = train_test_split(
            X,
            y,
            test_size=0.2,
            random_state=42
        )

    max_k = len(X_train)

    candidate_k = [3, 5, 7, 9, 11, 15]
    candidate_k = [k for k in candidate_k if k <= max_k]

    if not candidate_k:
        candidate_k = [1]

    pipeline = Pipeline([
        ("scaler", StandardScaler()),
        ("knn", KNeighborsClassifier())
    ])

    # CV hanya bisa kalau tiap kelas di train minimal punya 2 data
    train_class_counts = y_train.value_counts()
    min_train_class = train_class_counts.min()

    if min_train_class >= 2 and len(candidate_k) > 1:
        cv = min(5, min_train_class)

        param_grid = {
            "knn__n_neighbors": candidate_k,
            "knn__weights": ["distance", "uniform"],
            "knn__metric": ["euclidean", "manhattan"]
        }

        grid = GridSearchCV(
            pipeline,
            param_grid=param_grid,
            cv=cv,
            scoring="accuracy",
            n_jobs=-1
        )

        grid.fit(X_train, y_train)
        model = grid.best_estimator_

        print("\nBest parameter KNN:")
        print(grid.best_params_)
    else:
        model = Pipeline([
            ("scaler", StandardScaler()),
            ("knn", KNeighborsClassifier(
                n_neighbors=candidate_k[0],
                weights="distance",
                metric="euclidean"
            ))
        ])
        model.fit(X_train, y_train)

    y_pred = model.predict(X_test)

    acc = accuracy_score(y_test, y_pred)

    print("\nAkurasi testing KNN:", round(acc * 100, 2), "%")

    report = classification_report(y_test, y_pred, zero_division=0)
    cm = confusion_matrix(y_test, y_pred, labels=MOOD_ORDER)

    return model, acc, report, cm


def copy_by_knn_prediction(df):
    """
    Copy lagu asli ke folder berdasarkan prediksi KNN.
    Tidak menghapus data lama.
    """
    os.makedirs(CLEAN_KNN_DIR, exist_ok=True)

    copied = 0
    skipped = 0

    for _, row in tqdm(df.iterrows(), total=len(df), desc="Copy lagu berdasarkan KNN"):
        file_path = row.get("file_path", None)
        pred = row.get("knn_predicted_mood", None)

        if not file_path or not pred:
            skipped += 1
            continue

        src = Path(file_path)

        if not src.exists():
            skipped += 1
            continue

        target_dir = Path(CLEAN_KNN_DIR) / str(pred)
        target_dir.mkdir(parents=True, exist_ok=True)

        original_folder_label = str(row.get("original_folder_label", "random"))
        safe_name = f"{original_folder_label}__{src.name}"

        dst = target_dir / safe_name

        if not dst.exists():
            shutil.copy2(src, dst)
            copied += 1
        else:
            skipped += 1

    print(f"\nFile berhasil dicopy: {copied}")
    print(f"File dilewati: {skipped}")


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    os.makedirs(CLEAN_KNN_DIR, exist_ok=True)

    df_raw = load_data()

    print("\nTotal data awal:", len(df_raw))

    df, X, y, feature_cols, label_col = prepare_features(df_raw)

    print("Total data valid untuk KNN:", len(df))
    print("Jumlah fitur:", len(feature_cols))
    print("Kolom label:", label_col)

    if len(df) == 0:
        raise ValueError("Tidak ada data valid untuk training KNN.")

    model, acc, report, cm = train_knn(X, y)

    # Prediksi semua data menggunakan KNN
    df["knn_predicted_mood"] = model.predict(X)

    # Kalau model mendukung predict_proba, ambil confidence
    if hasattr(model.named_steps["knn"], "predict_proba"):
        proba = model.predict_proba(X)
        df["knn_confidence"] = np.max(proba, axis=1)
        df["knn_confidence"] = df["knn_confidence"].round(4)
    else:
        df["knn_confidence"] = None

    # Simpan model
    joblib.dump(
        {
            "model": model,
            "feature_cols": feature_cols,
            "label_col": label_col,
            "mood_order": MOOD_ORDER
        },
        MODEL_PATH
    )

    # Simpan hasil CSV dan JSON
    df.to_csv(RESULT_CSV_PATH, index=False, encoding="utf-8-sig")
    df.to_json(RESULT_JSON_PATH, orient="records", force_ascii=False, indent=2)

    # Ringkasan hasil KNN
    if "original_folder_label" in df.columns:
        summary = pd.crosstab(
            df["original_folder_label"],
            df["knn_predicted_mood"],
            margins=True
        )
    else:
        summary = df["knn_predicted_mood"].value_counts().to_frame("jumlah")

    summary.to_csv(SUMMARY_KNN_PATH, encoding="utf-8-sig")

    # Simpan classification report
    with open(REPORT_PATH, "w", encoding="utf-8") as f:
        f.write("=== CLASSIFICATION REPORT KNN ===\n")
        f.write(f"Akurasi testing: {round(acc * 100, 2)}%\n\n")
        f.write(report)

    # Simpan confusion matrix
    cm_df = pd.DataFrame(
        cm,
        index=[f"actual_{m}" for m in MOOD_ORDER],
        columns=[f"pred_{m}" for m in MOOD_ORDER]
    )
    cm_df.to_csv(CONFUSION_MATRIX_PATH, encoding="utf-8-sig")

    # Copy lagu ke folder berdasarkan KNN
    copy_by_knn_prediction(df)

    print("\n=== SELESAI KNN ===")
    print(f"Model KNN        : {MODEL_PATH}")
    print(f"Hasil CSV        : {RESULT_CSV_PATH}")
    print(f"Hasil JSON       : {RESULT_JSON_PATH}")
    print(f"Ringkasan KNN    : {SUMMARY_KNN_PATH}")
    print(f"Report KNN       : {REPORT_PATH}")
    print(f"Confusion Matrix : {CONFUSION_MATRIX_PATH}")
    print(f"Folder Clean KNN : {CLEAN_KNN_DIR}")


if __name__ == "__main__":
    main()