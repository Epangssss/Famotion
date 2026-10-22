
<div align="center">

# 🎵 Famotion  
### Face Mood Emotion Detection

Aplikasi mobile berbasis Flutter untuk mendeteksi emosi wajah pengguna dan memberikan rekomendasi musik berdasarkan mood.

![Flutter](https://img.shields.io/badge/Flutter-Mobile-blue?style=for-the-badge&logo=flutter)
![Python](https://img.shields.io/badge/Python-Backend-yellow?style=for-the-badge&logo=python)
![TA](https://img.shields.io/badge/TA-Manajemen%20Informatika-green?style=for-the-badge)

</div>

---

## 📱 Preview Aplikasi

<div align="center">

<table>
  <tr>
    <td align="center">
      <img src="/1.jpg" width="240" alt="Famotion Screenshot 1">
    </td>
    <td align="center">
      <img src="/5.png" width="240" alt="Famotion Screenshot 2">
    </td>
      <td align="center">
      <img src="/2.jpg" width="240" alt="Famotion Screenshot 2">
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="/3.jpeg" width="240" alt="Famotion Screenshot 3">
    </td>
    <td align="center">
      <img src="/4.jpg" width="240" alt="Famotion Screenshot 4">
    </td>
      <td align="center">
      <img src="/6.jpg" width="240" alt="Famotion Screenshot 4">
    </td>
  </tr>
</table>

</div>

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
- 🎧 Rekomendasi musik berdasarkan hasil mood (mendukung pemutaran **Local** dan **YT Music**)
- 📱 Tampilan aplikasi mobile yang sederhana dan mudah digunakan
- 🔗 Integrasi Flutter dengan backend Python Flask dan Node.js
- 📊 Menampilkan hasil prediksi emosi dan confidence

---

## 🎵 Sumber Pemutaran Musik

Famotion mendukung dua metode penyediaan musik untuk direkomendasikan kepada pengguna:

1. **Local Music (Dataset Internal)**  
   Sistem membaca dan memutar lagu secara langsung dari database atau penyimpanan lokal server. Lagu-lagu pada dataset ini telah dianalisis nilai emosinya terlebih dahulu menggunakan algoritma **K-Nearest Neighbor (KNN)** agar presisi dengan hasil deteksi wajah pengguna.

2. **YouTube Music (YT Music / Stream)**  
   Aplikasi secara dinamis dapat mencari dan melakukan *streaming* lagu dari YouTube berdasarkan *mood* pengguna. Fitur ini terintegrasi menggunakan backend *Node.js* yang memanfaatkan *library* `yt-dlp` dan `ffmpeg` untuk memproses audio (dapat dilihat pada folder `model_vps` dan `music_api_server`). Hal ini memungkinkan rekomendasi lagu yang lebih *up-to-date* dan tak terbatas.

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
├── lib/                     # Aplikasi mobile (Flutter)
│   ├── main.dart            # Entry point aplikasi
│   ├── models/              # Struktur model data
│   ├── screen/              # Halaman/UI aplikasi
│   ├── services/            # Integrasi API & Backend
│   ├── utils/               # Fungsi utilitas
│   └── widgets/             # Komponen UI reusable
│
├── python/                  # Skrip & Model Machine Learning (Python)
│   ├── revisi_model/        # Pengembangan/revisi model ML
│   ├── analisis_dataset_lagu.py
│   └── knn_mood_lagu.py
│
├── model_vps/               # Backend server untuk VPS (Node.js)
│   ├── app.js
│   └── mongo.js
│
├── server/                  # Backend API utama (Flask & Node.js)
│   ├── app.py
│   └── app.js
│
├── music_api_server/        # Layanan API untuk musik (Node.js)
│   ├── app.js
│   └── server.js
│
├── assets/                  # Aset statis aplikasi (gambar, ikon, dll)
├── android/                 # Build konfigurasi Android
├── ios/                     # Build konfigurasi iOS
├── windows/                 # Build konfigurasi Windows
├── web/                     # Build konfigurasi Web
├── pubspec.yaml             # Konfigurasi package/dependensi Flutter
└── README.md                # Dokumentasi project
```

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

Project ini dibuat sebagai media rekomendasi emotion musik berbasis mobile dengan memanfaatkan deteksi emosi wajah.

Dengan adanya aplikasi ini, pengguna dapat memperoleh rekomendasi musik yang lebih sesuai dengan kondisi emosinya.

---

## 👨‍💻 Developer

**Edward Lanpram**
Program Studi Manajemen Informatika
Politeknik Negeri Jember

GitHub: [Epangssss](https://github.com/Epangssss)

---

<div align="center">

### Famotion

**Face Mood Emotion Detection & Music Recommendation**

</div>
