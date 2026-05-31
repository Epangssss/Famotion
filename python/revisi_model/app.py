import os
import uuid
import cv2
import joblib
import numpy as np
import mediapipe as mp

from flask import Flask, request, jsonify
from flask_cors import CORS
from tensorflow.keras.models import load_model, Model


# =========================
# CONFIG
# =========================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

UPLOAD_DIR = os.path.join(BASE_DIR, "uploads")
DEBUG_FRAME_DIR = os.path.join(BASE_DIR, "debug_frames")
DEBUG_CROP_DIR = os.path.join(BASE_DIR, "debug_crops")

os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(DEBUG_FRAME_DIR, exist_ok=True)
os.makedirs(DEBUG_CROP_DIR, exist_ok=True)

RESNET_MODEL_PATH = os.path.join(
    BASE_DIR,
    "models",
    "best_resnet50v2_4emosi.keras"
)

KNN_MODEL_PATH = os.path.join(
    BASE_DIR,
    "models",
    "best_knn_finetuned_resnet50v2.pkl"
)

CLASSES = ["anger", "happy", "neutral", "sad"]

IMG_SIZE = (224, 224)

# Ambil maksimal frame yang dipakai dari 1 video
MAX_USED_FRAMES = 15

# Ambil frame setiap 5 frame video
FRAME_STEP = 5

# Kalau True, sistem menyimpan gambar face mesh dan crop wajah
SAVE_DEBUG = True


# =========================
# FLASK
# =========================
app = Flask(__name__)
CORS(app)


# =========================
# LOAD MODEL
# =========================
print("Loading fine-tuned ResNet50V2...")
resnet_model = load_model(RESNET_MODEL_PATH)

# Ambil layer sebelum softmax sebagai feature extractor 128 fitur
feature_extractor = Model(
    inputs=resnet_model.input,
    outputs=resnet_model.layers[-2].output
)

print("Loading KNN pipeline...")
knn_model = joblib.load(KNN_MODEL_PATH)

print("Model siap.")


# =========================
# MEDIAPIPE FACE MESH
# =========================
mp_face_mesh = mp.solutions.face_mesh
mp_drawing = mp.solutions.drawing_utils
mp_styles = mp.solutions.drawing_styles

face_mesh = mp_face_mesh.FaceMesh(
    static_image_mode=False,
    max_num_faces=1,
    refine_landmarks=True,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
)


# =========================
# ROI WAJAH + MASKING
# =========================
def detect_face_roi(frame, margin=0.20):
    """
    Input  : frame video BGR dari OpenCV
    Output : crop_face 224x224, masked_frame
    """

    h, w = frame.shape[:2]

    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    results = face_mesh.process(rgb)

    if not results.multi_face_landmarks:
        return None, None

    landmarks = results.multi_face_landmarks[0]

    xs = [int(lm.x * w) for lm in landmarks.landmark]
    ys = [int(lm.y * h) for lm in landmarks.landmark]

    x_min = max(0, min(xs))
    x_max = min(w, max(xs))
    y_min = max(0, min(ys))
    y_max = min(h, max(ys))

    box_w = x_max - x_min
    box_h = y_max - y_min

    if box_w <= 0 or box_h <= 0:
        return None, None

    mx = int(box_w * margin)
    my = int(box_h * margin)

    x1 = max(0, x_min - mx)
    y1 = max(0, y_min - my)
    x2 = min(w, x_max + mx)
    y2 = min(h, y_max + my)

    crop_face = frame[y1:y2, x1:x2]

    if crop_face.size == 0:
        return None, None

    crop_face = cv2.resize(crop_face, IMG_SIZE)

    masked_frame = frame.copy()

    # kotak ROI wajah
    cv2.rectangle(masked_frame, (x1, y1), (x2, y2), (0, 255, 0), 2)

    # face mesh / struktur wajah
    mp_drawing.draw_landmarks(
        image=masked_frame,
        landmark_list=landmarks,
        connections=mp_face_mesh.FACEMESH_TESSELATION,
        landmark_drawing_spec=None,
        connection_drawing_spec=mp_styles.get_default_face_mesh_tesselation_style()
    )

    mp_drawing.draw_landmarks(
        image=masked_frame,
        landmark_list=landmarks,
        connections=mp_face_mesh.FACEMESH_CONTOURS,
        landmark_drawing_spec=None,
        connection_drawing_spec=mp_styles.get_default_face_mesh_contours_style()
    )

    return crop_face, masked_frame


# =========================
# PREDIKSI 1 FRAME
# =========================
def predict_frame(crop_face):
    "crop_face → ResNet50V2 fitur 128 → KNN probability"
    

    face_rgb = cv2.cvtColor(crop_face, cv2.COLOR_BGR2RGB)

    arr = face_rgb.astype("float32")
    arr = np.expand_dims(arr, axis=0)

    # model fine-tuned sudah punya preprocess_input di dalam graph
    feature = feature_extractor.predict(arr, verbose=0)

    pred_idx = knn_model.predict(feature)[0]

    if isinstance(pred_idx, (int, np.integer)):
        pred_label = CLASSES[pred_idx]
    else:
        pred_label = str(pred_idx)
        pred_idx = CLASSES.index(pred_label)

    if hasattr(knn_model, "predict_proba"):
        proba = knn_model.predict_proba(feature)[0]
    else:
        proba = np.zeros(len(CLASSES), dtype=np.float32)
        proba[pred_idx] = 1.0

    return pred_label, proba


# =========================
# PROSES VIDEO
# =========================
def process_video(video_path, request_id):
    cap = cv2.VideoCapture(video_path)

    # Enable auto-rotation from metadata if supported
    auto_rotated = False
    if hasattr(cv2, 'CAP_PROP_ORIENTATION_AUTO'):
        auto_rotated = cap.set(cv2.CAP_PROP_ORIENTATION_AUTO, 1)

    if not cap.isOpened():
        raise RuntimeError("Video tidak bisa dibuka")

    # Read orientation metadata
    rotation = 0
    if hasattr(cv2, 'CAP_PROP_ORIENTATION_META'):
        rotation = cap.get(cv2.CAP_PROP_ORIENTATION_META)

    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS)

    # Detect if manual rotation is needed
    ret, test_frame = cap.read()
    needs_manual_rotation = False
    rotation_code = None
    if ret:
        h, w = test_frame.shape[:2]
        # Reset VideoCapture
        cap.release()
        cap = cv2.VideoCapture(video_path)
        if hasattr(cv2, 'CAP_PROP_ORIENTATION_AUTO'):
            cap.set(cv2.CAP_PROP_ORIENTATION_AUTO, 1)

        # If metadata is portrait rotation (90/270) but frame is still landscape
        if rotation in [90, 270] and w > h:
            needs_manual_rotation = True
            if rotation == 90:
                rotation_code = cv2.ROTATE_90_CLOCKWISE
            elif rotation == 270:
                rotation_code = cv2.ROTATE_90_COUNTERCLOCKWISE
        elif rotation == 180:
            needs_manual_rotation = True
            rotation_code = cv2.ROTATE_180

    frame_idx = 0
    used_frames = 0

    probas = []
    frame_details = []

    while True:
        ret, frame = cap.read()

        if not ret:
            break

        if frame_idx % FRAME_STEP != 0:
            frame_idx += 1
            continue

        if used_frames >= MAX_USED_FRAMES:
            break

        # Apply manual rotation if OpenCV's auto-rotation didn't work
        if needs_manual_rotation and rotation_code is not None:
            frame = cv2.rotate(frame, rotation_code)

        crop_face, masked_frame = detect_face_roi(frame)

        if crop_face is None:
            frame_details.append({
                "frame": frame_idx,
                "status": "NO_FACE"
            })
            frame_idx += 1
            continue

        pred_label, proba = predict_frame(crop_face)
        probas.append(proba)

        detail = {
            "frame": frame_idx,
            "status": "OK",
            "prediction": pred_label,
            "probabilities": {
                CLASSES[i]: float(proba[i]) for i in range(len(CLASSES))
            }
        }

        frame_details.append(detail)

        if SAVE_DEBUG:
            crop_name = f"{request_id}_frame_{frame_idx}_{pred_label}.jpg"
            crop_path = os.path.join(DEBUG_CROP_DIR, crop_name)
            cv2.imwrite(crop_path, crop_face)

            cv2.putText(
                masked_frame,
                f"Frame {frame_idx} | {pred_label}",
                (20, 40),
                cv2.FONT_HERSHEY_SIMPLEX,
                1,
                (0, 255, 0),
                2
            )

            mask_name = f"{request_id}_frame_{frame_idx}_{pred_label}_mesh.jpg"
            mask_path = os.path.join(DEBUG_FRAME_DIR, mask_name)
            cv2.imwrite(mask_path, masked_frame)

        used_frames += 1
        frame_idx += 1

    cap.release()

    if len(probas) == 0:
        return {
            "error": "Wajah tidak terdeteksi pada video",
            "total_frames": total_frames,
            "fps": fps,
            "used_frames": 0,
            "frame_details": frame_details
        }

    avg_proba = np.mean(probas, axis=0)
    final_idx = int(np.argmax(avg_proba))
    final_label = CLASSES[final_idx]
    confidence = float(avg_proba[final_idx])

    scores = {
        CLASSES[i]: round(float(avg_proba[i]) * 100, 2)
        for i in range(len(CLASSES))
    }

    return {
        "prediction": final_label,
        "emotion": final_label,
        "label": final_label,
        "confidence": round(confidence * 100, 2),
        "scores": scores,
        "probabilities": scores,
        "method": "video_frame_sampling_mediapipe_resnet50v2_knn_average_probability",
        "model": "Fine-tuned ResNet50V2 + KNN K25 Euclidean",
        "total_frames": total_frames,
        "fps": fps,
        "used_frames": len(probas),
        "frame_step": FRAME_STEP,
        "frame_details": frame_details
    }


# =========================
# ROUTES
# =========================
@app.route("/", methods=["GET"])
def index():
    return jsonify({
        "status": "ok",
        "message": "Famotion Emotion API - ResNet50V2 + KNN",
        "endpoint": "/predict_video"
    })


@app.route("/predict_video", methods=["POST"])
def predict_video():
    if "file" not in request.files:
        return jsonify({
            "error": "Field file tidak ditemukan. Flutter harus mengirim multipart field bernama file."
        }), 400

    uploaded_file = request.files["file"]
    user_id = request.form.get("userId", "")

    if uploaded_file.filename == "":
        return jsonify({"error": "Nama file kosong"}), 400

    request_id = str(uuid.uuid4())[:8]
    ext = os.path.splitext(uploaded_file.filename)[1]

    if ext == "":
        ext = ".mp4"

    save_path = os.path.join(UPLOAD_DIR, f"{request_id}{ext}")
    uploaded_file.save(save_path)

    try:
        result = process_video(save_path, request_id)
        result["userId"] = user_id
        result["request_id"] = request_id

        if "error" in result:
            return jsonify(result), 400

        return jsonify(result), 200

    except Exception as e:
        return jsonify({
            "error": str(e),
            "request_id": request_id
        }), 500


# Optional: test foto juga kalau nanti dibutuhkan
@app.route("/predict", methods=["POST"])
def predict_image_legacy():
    return jsonify({
        "error": "Endpoint ini belum dipakai. Gunakan /predict_video untuk Flutter saat ini."
    }), 400


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5000,
        debug=False
    )