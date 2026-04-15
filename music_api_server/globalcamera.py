import numpy as np
import cv2
import joblib
import mediapipe as mp

from flask import Flask, request, jsonify

from tensorflow.keras.applications import ResNet50
from tensorflow.keras.preprocessing import image
from tensorflow.keras.applications.resnet50 import preprocess_input

print("🚀 START APP...")

app = Flask(__name__)

# =========================
# INIT MEDIAPIPE
# =========================
mp_face = mp.solutions.face_detection
face_detector = mp_face.FaceDetection(
    model_selection = 1,
    min_detection_confidence = 0.5
)



# =========================
# LOAD MODEL
# =========================
try:
    print("⏳ Loading ResNet50...")
    resnet = ResNet50(weights='imagenet', include_top=False, pooling='avg')
    print("✅ ResNet50 LOADED")

    print("⏳ Loading KNN...")
    knn = joblib.load("./dataset/knn_model.pkl")
    print("✅ KNN LOADED")

    print("⏳ Loading Scaler...")
    scaler = joblib.load("./dataset/scaler.pkl")
    print("✅ Scaler LOADED")

    print("📌 Classes:", knn.classes_)

except Exception as e:
    print("❌ ERROR LOAD MODEL:", e)


# =========================
# DETECT FACE
# =========================
def detect_face(img):
    try:
        h, w, _ = img.shape
        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

        results = face_detector.process(img_rgb)

        if not results.detections:
            return None

        detection = results.detections[0]
        bbox = detection.location_data.relative_bounding_box

        x1 = int(bbox.xmin * w)
        y1 = int(bbox.ymin * h)
        x2 = int((bbox.xmin + bbox.width) * w)
        y2 = int((bbox.ymin + bbox.height) * h)

        # Clamp biar tidak keluar frame
        x1, y1 = max(0, x1), max(0, y1)
        x2, y2 = min(w, x2), min(h, y2)

        face = img[y1:y2, x1:x2]

        if face.size == 0:
            return None
            
        return face

    except Exception as e:
        print("❌ Mediapipe error:", e)
        return None


# =========================
# FEATURE EXTRACTION
# =========================
def extract_features(img):
    try:
        print("➡️ Detecting face...")
        face = detect_face(img)

        if face is None:
            print("⚠️ No face detected")
            return None

        print("➡️ Resize face...")
        roi = cv2.resize(face, (224, 224))

        img_array = image.img_to_array(roi)
        img_array = np.expand_dims(img_array, axis=0)
        img_array = preprocess_input(img_array)

        print("➡️ Extracting features...")
        features = resnet.predict(img_array, verbose=0).flatten()

        return features

    except Exception as e:
        print("❌ Feature extraction error:", e)
        return None
        # =========================
# ROUTES
# =========================
@app.route('/')
def home():
    return "🔥 API Emotion Detection ACTIVE (MEDIAPIPE + RESNET + KNN)"

@app.route('/predict', methods=['POST'])
def predict():
    print("\n📥 Request masuk...")

    if 'file' not in request.files:
        return jsonify({"error": "No file uploaded"}), 400

    file = request.files['file']

    try:
        file_bytes = np.frombuffer(file.read(), np.uint8)
        img = cv2.imdecode(file_bytes, cv2.IMREAD_COLOR)

        if img is None:
            return jsonify({"error": "Invalid image"}), 400

        feat = extract_features(img)

        if feat is None:
            return jsonify({"error": "Face not detected"}), 400

        print("➡️ Scaling...")
        feat = feat.reshape(1, -1)
        feat = scaler.transform(feat)
        
        print("➡️ Predicting probability...")
        probs = knn.predict_proba(feat)[0]

        # Normalisasi (biar aman)
        probs = probs / np.sum(probs)

        # Convert ke persen
        percentages = (probs * 100).tolist()

        # Mapping label → persen
        confidence = dict(zip(knn.classes_, percentages))

        # Ambil prediksi tertinggi
        best_index = np.argmax(probs)
        prediction = knn.classes_[best_index]

        print("✅ RESULT:", prediction)
        print("📊 CONFIDENCE:", confidence)

        return jsonify({
            "prediction": str(prediction),
            "confidence": confidence
        })
        
    except Exception as e:
        print("❌ ERROR PREDICT:", e)
        return jsonify({
            "error": str(e)
        }), 500

# =========================
# RUN
# =========================
if __name__ == '__main__':
    print("🚀 Flask starting for deployment...")
    app.run(host='0.0.0.0', port=5000, debug=False)

    