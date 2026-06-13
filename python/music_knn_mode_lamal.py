import ast
import os
import joblib
import pandas as pd

from sklearn.model_selection import train_test_split, GridSearchCV
from sklearn.neighbors import KNeighborsClassifier
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.pipeline import Pipeline
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix


# =========================
# PATH CSV DARI LABEL FINAL
# =========================
CSV_PATH = r"C:\famotion\famotion\python\label-final\hasil_analisis\hasil_analisis_lagu.csv"

OUTPUT_DIR = r"C:\famotion\famotion\python\label-final\hasil_analisis"
MODEL_OUT = os.path.join(OUTPUT_DIR, "knn_mood_model.pkl")
ENCODER_OUT = os.path.join(OUTPUT_DIR, "label_encoder.pkl")
REPORT_OUT = os.path.join(OUTPUT_DIR, "classification_report_knn.txt")
CM_OUT = os.path.join(OUTPUT_DIR, "confusion_matrix_knn.csv")

os.makedirs(OUTPUT_DIR, exist_ok=True)

df = pd.read_csv(CSV_PATH)


# =========================
# LABEL YANG DIPAKAI
# =========================
# Jika ada label_final, pakai label_final.
# Jika tidak ada, pakai original_folder_label dari folder label-final.
# Jangan pakai predicted_mood untuk training final.
if "label_final" in df.columns:
    label_col = "label_final"
elif "original_folder_label" in df.columns:
    label_col = "original_folder_label"
else:
    raise ValueError(
        "Kolom label tidak ditemukan. Harus ada label_final atau original_folder_label."
    )


# =========================
# FITUR AUDIO DARI LIBROSA
# =========================
base_features = [
    "tempo_bpm",
    "rms_energy",
    "loudness_db",
    "spectral_centroid",
    "spectral_rolloff",
    "zero_crossing_rate",
    "valence",
    "arousal",
    "aggression",
]

missing = [col for col in base_features if col not in df.columns]
if missing:
    raise ValueError(f"Kolom fitur tidak ditemukan di CSV: {missing}")


# =========================
# BERSIHKAN DATA
# =========================
df = df.dropna(subset=base_features + [label_col]).copy()

df[label_col] = df[label_col].astype(str).str.lower().str.strip()

# Samakan nama label
df[label_col] = df[label_col].replace({
    "anger": "angry",
    "netral": "neutral"
})

valid_labels = ["angry", "happy", "sad", "neutral"]
df = df[df[label_col].isin(valid_labels)].copy()


# =========================
# OPSIONAL: PAKAI MFCC JIKA ADA
# =========================
mfcc_cols = []

if "mfcc_mean" in df.columns:
    def parse_mfcc(x):
        try:
            if isinstance(x, str):
                return ast.literal_eval(x)
            return x
        except Exception:
            return None

    mfcc_values = df["mfcc_mean"].apply(parse_mfcc)

    valid_mfcc = mfcc_values.apply(
        lambda x: isinstance(x, list) and len(x) == 13
    )

    df = df[valid_mfcc].copy()
    mfcc_values = mfcc_values[valid_mfcc]

    for i in range(13):
        col = f"mfcc_{i + 1}"
        df[col] = mfcc_values.apply(lambda x: float(x[i]))
        mfcc_cols.append(col)


features = base_features + mfcc_cols


# =========================
# SIAPKAN X DAN y
# =========================
X = df[features]
y_text = df[label_col].astype(str)

encoder = LabelEncoder()
y = encoder.fit_transform(y_text)

print("=== INFO DATASET ===")
print("CSV:", CSV_PATH)
print("Label yang dipakai:", label_col)
print("Label mood:", list(encoder.classes_))
print("Jumlah data:", len(df))

print("\nDistribusi label:")
print(y_text.value_counts())

print("\nFitur yang digunakan:")
print(features)


# =========================
# CEK DATA MINIMAL
# =========================
class_counts = y_text.value_counts()

if class_counts.min() < 2:
    raise ValueError(
        "Ada kelas dengan data kurang dari 2. Tambahkan data pada kelas tersebut."
    )


# =========================
# SPLIT DATA
# =========================
X_train, X_test, y_train, y_test = train_test_split(
    X,
    y,
    test_size=0.2,
    random_state=42,
    stratify=y
)


# =========================
# PIPELINE KNN
# =========================
pipeline = Pipeline([
    ("scaler", StandardScaler()),
    ("knn", KNeighborsClassifier())
])


# =========================
# CARI PARAMETER KNN TERBAIK
# =========================
train_labels = pd.Series(encoder.inverse_transform(y_train))
min_train_class = train_labels.value_counts().min()
cv_value = min(5, int(min_train_class))

if cv_value < 2:
    raise ValueError(
        "Data training per kelas terlalu sedikit untuk GridSearchCV."
    )

max_k = min(15, len(X_train) - 1)
k_values = [k for k in [3, 5, 7, 9, 11, 13, 15] if k <= max_k]

param_grid = {
    "knn__n_neighbors": k_values,
    "knn__weights": ["uniform", "distance"],
    "knn__metric": ["euclidean", "manhattan"]
}

grid = GridSearchCV(
    pipeline,
    param_grid,
    cv=cv_value,
    scoring="accuracy",
    n_jobs=-1
)

grid.fit(X_train, y_train)

best_model = grid.best_estimator_

print("\n=== PARAMETER TERBAIK ===")
print(grid.best_params_)


# =========================
# EVALUASI MODEL
# =========================
y_pred = best_model.predict(X_test)

acc = accuracy_score(y_test, y_pred)

report = classification_report(
    y_test,
    y_pred,
    target_names=encoder.classes_
)

cm = confusion_matrix(y_test, y_pred)

print("\n=== HASIL EVALUASI KNN ===")
print("Akurasi:", acc)

print("\nClassification Report:")
print(report)

print("\nConfusion Matrix:")
print(cm)


# =========================
# SIMPAN HASIL
# =========================
cm_df = pd.DataFrame(
    cm,
    index=[f"actual_{c}" for c in encoder.classes_],
    columns=[f"pred_{c}" for c in encoder.classes_]
)

cm_df.to_csv(CM_OUT, encoding="utf-8-sig")

with open(REPORT_OUT, "w", encoding="utf-8") as f:
    f.write("=== HASIL EVALUASI KNN MOOD LAGU ===\n")
    f.write(f"CSV: {CSV_PATH}\n")
    f.write(f"Label yang dipakai: {label_col}\n")
    f.write(f"Label mood: {list(encoder.classes_)}\n")
    f.write(f"Jumlah data: {len(df)}\n")
    f.write(f"Fitur: {features}\n")
    f.write(f"Parameter terbaik: {grid.best_params_}\n")
    f.write(f"Akurasi: {acc}\n\n")
    f.write("Classification Report:\n")
    f.write(report)
    f.write("\nConfusion Matrix:\n")
    f.write(str(cm))

joblib.dump(best_model, MODEL_OUT)
joblib.dump(encoder, ENCODER_OUT)

print("\n=== FILE DISIMPAN ===")
print("Model KNN       :", MODEL_OUT)
print("Label encoder   :", ENCODER_OUT)
print("Report evaluasi :", REPORT_OUT)
print("Confusion matrix:", CM_OUT)