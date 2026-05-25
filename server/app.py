import os
import cv2
import uuid
import numpy as np
import joblib
import mediapipe as mp

from flask import Flask, request, jsonify
from collections import defaultdict
from pymongo import MongoClient
from datetime import datetime

from tensorflow.keras.applications import ResNet50
from tensorflow.keras.preprocessing import image
from tensorflow.keras.applications.resnet50 import preprocess_input


print("🚀 START VPS VIDEO EMOTION API - TEMP VIDEO ONLY")

app = Flask(__name__)

# =========================
# CONFIG
# =========================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

UPLOAD_FOLDER = os.path.join(BASE_DIR, "uploads")
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

app.config["MAX_CONTENT_LENGTH"] = 100 * 1024 * 1024


# =========================
# DATABASE
# =========================
client = MongoClient(
    "mongodb://dbfamotion:Rakasiwi2005@103.253.212.130:27017/db_famotion?authSource=admin"
)
db = client["db_famotion"]


# =========================
# LOAD MODEL
# =========================
print("⏳ Loading model...")

model = ResNet50(
    weights="imagenet",
    include_top=False,
    pooling="avg"
)

knn = joblib.load(
    os.path.join(BASE_DIR, "dataset", "knn_model.pkl")
)

scaler = joblib.load(
    os.path.join(BASE_DIR, "dataset", "scaler.pkl")
)

print("✅ Model siap")


# =========================
# MEDIAPIPE
# =========================
mp_face_mesh = mp.solutions.face_mesh

face_mesh = mp_face_mesh.FaceMesh(
    static_image_mode=False,
    max_num_faces=1,
    refine_landmarks=True,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
)


# =========================
# FEATURE EXTRACTION
# =========================
def extract_features_with_bbox(frame, landmarks):
    h, w, _ = frame.shape

    xs = [int(p.x * w) for p in landmarks.landmark]
    ys = [int(p.y * h) for p in landmarks.landmark]

    x_min, x_max = max(0, min(xs)), min(w, max(xs))
    y_min, y_max = max(0, min(ys)), min(h, max(ys))

    if x_max <= x_min or y_max <= y_min:
        return None

    face = frame[y_min:y_max, x_min:x_max]

    if face.size == 0:
        return None

    fh, fw, _ = face.shape

    face_area_ratio = (fw * fh) / (w * h)

    # Wajah terlalu jauh
    if face_area_ratio < 0.03:
        return None

    # Wajah terlalu dekat
    if face_area_ratio > 0.70:
        return None

    # Wajah terlalu kecil
    if fh < 50 or fw < 50:
        return None

    # ROI fokus ekspresi wajah
    roi = face[
        int(fh * 0.25):int(fh * 0.9),
        int(fw * 0.15):int(fw * 0.85)
    ]

    if roi.size == 0:
        return None

    try:
        roi = cv2.resize(roi, (224, 224))
    except Exception:
        return None

    img_array = image.img_to_array(roi)
    img_array = np.expand_dims(img_array, axis=0)
    img_array = preprocess_input(img_array)

    features = model.predict(
        img_array,
        verbose=0
    )

    return features.flatten()


# =========================
# PROCESS VIDEO TANPA SIMPAN OUTPUT
# =========================
def process_video(path):
    cap = cv2.VideoCapture(path)

    if not cap.isOpened():
        return None, {}

    frame_results = []
    frame_count = 0
    SKIP = 3

    while True:
        ret, frame = cap.read()

        if not ret:
            break

        frame_count += 1

        # proses tiap 3 frame agar VPS lebih ringan
        if frame_count % SKIP != 0:
            continue

        rgb = cv2.cvtColor(
            frame,
            cv2.COLOR_BGR2RGB
        )

        results = face_mesh.process(rgb)

        if results.multi_face_landmarks:
            landmarks = results.multi_face_landmarks[0]

            feat = extract_features_with_bbox(
                frame,
                landmarks
            )

            if feat is not None:
                feat = scaler.transform(
                    feat.reshape(1, -1)
                )

                probs = knn.predict_proba(feat)[0]

                frame_prob = {}

                for i, label in enumerate(knn.classes_):
                    frame_prob[label] = float(probs[i])

                frame_results.append(frame_prob)

    cap.release()

    if not frame_results:
        return None, {}

    # =========================
    # WEIGHTED VOTING ALL PROBABILITY
    # =========================
    vote_dict = defaultdict(float)
    count_dict = defaultdict(int)

    for item in frame_results:
        for emotion, prob in item.items():
            vote_dict[emotion] += prob
            count_dict[emotion] += 1

    final_pred = max(
        vote_dict,
        key=vote_dict.get
    )

    total_weight = sum(vote_dict.values())

    vote_percentage = {
        emotion: float(
            f"{(score / total_weight) * 100:.1f}"
        )
        for emotion, score in vote_dict.items()
    }

    avg_probability = {
        emotion: float(
            f"{(vote_dict[emotion] / count_dict[emotion]) * 100:.1f}"
        )
        for emotion in vote_dict
    }

    scores = {
        "weighted_votes": {
            emotion: float(f"{score:.4f}")
            for emotion, score in vote_dict.items()
        },
        "vote_percentage": vote_percentage,
        "avg_probability": avg_probability,
        "frame_count": dict(count_dict)
    }

    return final_pred, scores


# =========================
# ROUTES
# =========================
@app.route("/", methods=["GET"])
def home():
    return jsonify({
        "message": "Emotion API VPS aktif",
        "endpoint": "/predict_video",
        "mode": "video hanya sementara, tidak disimpan permanen"
    })


@app.route("/predict", methods=["POST"])
@app.route("/predict_video", methods=["POST"])
def predict_video():
    if "file" not in request.files:
        return jsonify({
            "error": "No file"
        }), 400

    user_id = (
        request.form.get("userId")
        or request.form.get("user_id")
        or request.form.get("_id")
        or "local_user"
    )

    file = request.files["file"]

    filename = str(uuid.uuid4()) + ".mp4"
    path = os.path.join(UPLOAD_FOLDER, filename)

    try:
        # video disimpan sementara
        file.save(path)

        pred, scores = process_video(path)

        if pred is None:
            return jsonify({
                "error": "No face detected"
            }), 400

        confidence = scores["vote_percentage"].get(pred, 0)

        db.emotions.insert_one({
            "userId": user_id,
            "emotion": pred,
            "confidence": confidence,
            "scores": scores,
            "created_at": datetime.utcnow()
        })

        return jsonify({
            "userId": user_id,
            "prediction": pred,
            "emotion": pred,
            "confidence": confidence,
            "scores": scores
        }), 200

    except Exception as e:
        print("❌ ERROR predict_video:", str(e))

        return jsonify({
            "error": str(e)
        }), 500

    finally:
        # video wajib dihapus setelah proses selesai
        if os.path.exists(path):
            os.remove(path)


# =========================
# RUN SERVER
# =========================
if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5000,
        debug=False,
        use_reloader=False
    )