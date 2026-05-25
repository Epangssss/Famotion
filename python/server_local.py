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

print("🚀 START LOCAL VIDEO EMOTION API")

app = Flask(__name__)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, "uploads")
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

app.config["MAX_CONTENT_LENGTH"] = 50 * 1024 * 1024

# =========================
# DATABASE LOCAL
# =========================
client = MongoClient(
    "mongodb://dbfamotion:Rakasiwi2005@103.253.212.130:27017/db_famotion?authSource=admin"
)
db = client["db_famotion"]
# =========================
# LOAD MODEL
# =========================
print("⏳ Loading model...")
model = ResNet50(weights="imagenet", include_top=False, pooling="avg")

knn = joblib.load(os.path.join(BASE_DIR, "dataset", "knn_model.pkl"))
scaler = joblib.load(os.path.join(BASE_DIR, "dataset", "scaler.pkl"))

print("✅ Model siap")

# =========================
# MEDIAPIPE
# =========================
mp_face_mesh = mp.solutions.face_mesh
face_mesh = mp_face_mesh.FaceMesh(
    static_image_mode=False,
    max_num_faces=1
)

def extract_features(frame, landmarks):
    h, w, _ = frame.shape

    xs = [int(p.x * w) for p in landmarks.landmark]
    ys = [int(p.y * h) for p in landmarks.landmark]

    x_min, x_max = max(0, min(xs)), min(w, max(xs))
    y_min, y_max = max(0, min(ys)), min(h, max(ys))

    if x_max <= x_min or y_max <= y_min:
        return None

    face = frame[y_min:y_max, x_min:x_max]
    fh, fw, _ = face.shape

    face_area_ratio = (fw * fh) / (w * h)

    if face_area_ratio < 0.06:
        return None

    if face_area_ratio > 0.55:
        return None

    if fh < 100 or fw < 100:
        return None

    roi = face[
        int(fh * 0.25):int(fh * 0.9),
        int(fw * 0.15):int(fw * 0.85)
    ]

    if roi.size == 0:
        return None

    roi = cv2.resize(roi, (224, 224))

    img_array = image.img_to_array(roi)
    img_array = np.expand_dims(img_array, axis=0)
    img_array = preprocess_input(img_array)

    features = model.predict(img_array, verbose=0)
    return features.flatten()

def process_video(path):
    cap = cv2.VideoCapture(path)

    frame_results = []
    frame_count = 0
    SKIP = 3

    while True:
        ret, frame = cap.read()

        if not ret:
            break

        frame_count += 1

        if frame_count % SKIP != 0:
            continue

        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = face_mesh.process(rgb)

        if results.multi_face_landmarks:
            for landmarks in results.multi_face_landmarks:
                feat = extract_features(frame, landmarks)

                if feat is not None:
                    feat = scaler.transform(feat.reshape(1, -1))

                    probs = knn.predict_proba(feat)[0]

                    frame_prob = {}
                    for i, label in enumerate(knn.classes_):
                        frame_prob[label] = float(probs[i])

                    frame_results.append(frame_prob)

    cap.release()

    if not frame_results:
        return None, {}

    vote_dict = defaultdict(float)
    count_dict = defaultdict(int)

    for item in frame_results:
        for emotion, prob in item.items():
            vote_dict[emotion] += prob
            count_dict[emotion] += 1

    final_pred = max(vote_dict, key=vote_dict.get)
    total_weight = sum(vote_dict.values())

    vote_percentage = {
        emotion: float(f"{(score / total_weight) * 100:.1f}")
        for emotion, score in vote_dict.items()
    }

    avg_probability = {
        emotion: float(f"{(vote_dict[emotion] / count_dict[emotion]) * 100:.1f}")
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

@app.route("/", methods=["GET"])
def home():
    return jsonify({
        "message": "Emotion API Local aktif",
        "endpoint": "/predict atau /predict_video"
    })

@app.route("/predict", methods=["POST"])
@app.route("/predict_video", methods=["POST"])
def predict_video():
    if "file" not in request.files:
        return jsonify({"error": "No file"}), 400

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
        file.save(path)

        pred, scores = process_video(path)

        if pred is None:
            return jsonify({"error": "No face detected"}), 400

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
        print("❌ Error:", str(e))
        return jsonify({"error": str(e)}), 500

    finally:
        if os.path.exists(path):
            os.remove(path)

if __name__ == "__main__":
   app.run(host="0.0.0.0", port=5000, debug=False, use_reloader=False)