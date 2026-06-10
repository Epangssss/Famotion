````md
<div align="center">

# 🎵 Famotion  
### Face Mood Emotion Detection

Aplikasi mobile berbasis Flutter untuk mendeteksi emosi wajah pengguna dan memberikan rekomendasi musik berdasarkan mood.

![Flutter](https://img.shields.io/badge/Flutter-Mobile-blue?style=for-the-badge&logo=flutter)
![Python](https://img.shields.io/badge/Python-Backend-yellow?style=for-the-badge&logo=python)
![TA](https://img.shields.io/badge/TA-Manajemen%20Informatika-green?style=for-the-badge)

</div>

---

## 📱 Tentang Aplikasi

**Famotion** adalah aplikasi mobile yang dikembangkan untuk kebutuhan Tugas Akhir Program Studi Manajemen Informatika.

Aplikasi ini menggunakan konsep **Face Mood Emotion Detection**, yaitu mendeteksi ekspresi wajah pengguna untuk mengetahui kondisi emosi seperti:

- 😄 Happy
- 😢 Sad
- 😠 Angry
- 😐 Neutral

Hasil deteksi emosi kemudian digunakan untuk memberikan rekomendasi musik yang sesuai dengan mood pengguna.

---

## ✨ Fitur Utama

- 📷 Deteksi emosi wajah melalui kamera atau gambar
- 🧠 Klasifikasi emosi menggunakan model machine learning
- 🎧 Rekomendasi musik berdasarkan hasil mood
- 📱 Tampilan aplikasi mobile yang sederhana dan mudah digunakan
- 🔗 Integrasi Flutter dengan backend Python Flask
- 📊 Menampilkan hasil prediksi emosi dan confidence

---

## 🛠️ Teknologi yang Digunakan

- **Flutter**  
  Untuk pengembangan aplikasi mobile.

- **Dart**  
  Bahasa pemrograman utama pada Flutter.

- **Python Flask**  
  Sebagai backend untuk proses prediksi model.

- **ResNet50V2**  
  Digunakan untuk ekstraksi fitur citra wajah.

- **K-Nearest Neighbor**  
  Digunakan untuk klasifikasi emosi.

- **Librosa**  
  Digunakan untuk analisis fitur musik.

---

## 📂 Struktur Project

```bash
Famotion/
│
├── lib/
│   ├── main.dart
│   ├── pages/
│   ├── services/
│   └── widgets/
│
├── assets/
│   ├── images/
│   └── icons/
│
├── android/
├── ios/
├── pubspec.yaml
└── README.md
````

---

## 🚀 Cara Menjalankan Project

### 1. Clone Repository

```bash
git clone https://github.com/Epangssss/Famotion.git
```

### 2. Masuk ke Folder Project

```bash
cd Famotion
```

### 3. Install Dependency Flutter

```bash
flutter pub get
```

### 4. Jalankan Aplikasi

```bash
flutter run
```

---

## 🔌 Backend Model

Aplikasi ini terhubung dengan backend Python Flask yang digunakan untuk memproses gambar atau video wajah.

Pastikan server Flask sudah berjalan sebelum aplikasi digunakan.

Contoh menjalankan backend:

```bash
python app.py
```

---

## 🧪 Output Prediksi

Contoh hasil prediksi dari backend:

```json
{
  "emotion": "happy",
  "confidence": 68.65,
  "fps": 29.6
}
```

---

## 🎯 Tujuan Project

Project ini dibuat sebagai media rekomendasi terapi musik berbasis mobile dengan memanfaatkan deteksi emosi wajah.

Dengan adanya aplikasi ini, pengguna dapat memperoleh rekomendasi musik yang lebih sesuai dengan kondisi emosinya.

---

## 👨‍💻 Developer

**EdoLanpram**
Program Studi Manajemen Informatika
Politeknik Negeri Jember

GitHub: [Epangssss](https://github.com/Epangssss)

---

<div align="center">

### Famotion

**Face Mood Emotion Detection & Music Recommendation**

</div>
```
