const express = require("express");
const fs = require("fs");
const path = require("path");
const rateLimit = require("express-rate-limit");
const cors = require("cors");

const app = express();

app.use(cors());

// ==========================
// RATE LIMIT (ANTI SPAM)
// ==========================
const limiter = rateLimit({
    windowMs: 60 * 1000, // 1 menit
    max: 100, // allow more for local streaming testing
    message: { error: "Terlalu banyak request, coba lagi nanti" }
});

app.use(limiter);

// ==========================
// LOAD KNN RESULTS
// ==========================
// Membaca file hasil klasifikasi KNN dari project python
const knnResultPath = path.join(__dirname, "../python/hasil_analisis-test2/knn_result/hasil_analisis_lagu_knn.json");
let localSongs = [];

if (fs.existsSync(knnResultPath)) {
    try {
        const rawData = fs.readFileSync(knnResultPath, 'utf-8');
        localSongs = JSON.parse(rawData);
        console.log(`✅ Loaded ${localSongs.length} local songs from KNN analysis result.`);
    } catch (e) {
        console.error("❌ Failed to parse KNN result JSON:", e.message);
    }
} else {
    console.warn(`⚠️ KNN result not found at ${knnResultPath}`);
}

// ==========================
// ROOT
// ==========================
app.get("/", (req, res) => {
    res.json({ status: "New Local Music API running 🚀", loaded_songs: localSongs.length });
});

// ==========================
// SEARCH MUSIC
// ==========================
app.get("/music", async (req, res) => {
    try {
        const rawQ = req.query.q || "";
        const emotion = (req.query.emotion || "").toLowerCase();
        const limit = parseInt(req.query.limit) || 50;

        // Resolve emotion: fallback to 'happy' if none matched
        let resolvedEmotion = emotion || rawQ || "happy";
        
        // Normalize
        if (resolvedEmotion === "anger") resolvedEmotion = "angry";
        if (resolvedEmotion === "netral") resolvedEmotion = "neutral";

        // Filter local songs based on KNN predicted mood
        let filteredSongs = localSongs.filter(s => {
            const m = (s.knn_predicted_mood || s.predicted_mood || "unknown").toLowerCase();
            return m.includes(resolvedEmotion) || resolvedEmotion.includes(m);
        });

        // Fallback if no matching emotion is found
        if (filteredSongs.length === 0) {
            filteredSongs = localSongs; // Return all songs and just shuffle
        }

        // Shuffle the results
        filteredSongs = filteredSongs.sort(() => 0.5 - Math.random());

        const host = req.get("host") || "localhost:2000";

        // Map into expected app format
        const songs = filteredSongs.slice(0, limit).map((s) => {
            const moodFolder = s.knn_predicted_mood || s.predicted_mood || "unknown";
            const folderLabel = s.original_folder_label || "random";
            const actualFileName = `${folderLabel}__${s.file_name}`;

            const actualFilePath = path.join(
                __dirname,
                "../python/clean_by_knn_mood-test2",
                moodFolder,
                actualFileName
            );

            const vId = Buffer.from(actualFilePath).toString("base64");

            return {
                title: s.file_name.replace(/\.[^/.]+$/, ""),
                artist: "Famotion Local Music",
                duration: "03:00",
                thumbnail: `http://${host}/cover?videoId=${encodeURIComponent(vId)}`,
                videoId: vId,
                stream_url: `http://${host}/stream?videoId=${encodeURIComponent(vId)}`,

                detected_mood: s.knn_predicted_mood || s.predicted_mood || "unknown",
                mood_score: s.knn_confidence || s.confidence || 0,

                method: "knn"
            };
        });

        return res.json({
            emotion: resolvedEmotion,
            genre: req.query.genre || "",
            method: "local_knn_audio_files",
            total: songs.length,
            songs: songs
        });

    } catch (err) {
        console.error("[/music error]", err.message);
        res.status(500).json({ error: "Gagal ambil musik dari database lokal." });
    }
});

// ==========================
// STREAM AUDIO (LOCAL)
// ==========================
app.get("/stream", (req, res) => {
    try {
        const videoId = req.query.videoId;
        if (!videoId) {
            return res.status(400).send("videoId required");
        }

        // Decode absolute path from base64
        const filePath = Buffer.from(videoId, 'base64').toString('utf-8');

        if (fs.existsSync(filePath)) {
            // Gunakan res.sendFile agar Express otomatis menangani Content-Length, 
            // Range (untuk seeking/maju-mundur menit lagu), dan Content-Type yang benar.
            res.sendFile(filePath);
        } else {
            console.error(`File not found: ${filePath}`);
            res.status(404).send("File not found locally.");
        }
    } catch (e) {
        console.error("[/stream error]", e.message);
        res.status(500).send("Stream error.");
    }
});

// ==========================
// STREAM THUMBNAIL (LOCAL)
// ==========================
app.get("/cover", async (req, res) => {
    try {
        const videoId = req.query.videoId;
        if (!videoId) {
            return res.status(400).send("videoId required");
        }

        const filePath = Buffer.from(videoId, 'base64').toString('utf-8');

        if (!fs.existsSync(filePath)) {
            return res.status(404).send("File not found");
        }

        // Import music-metadata
        const mm = require("music-metadata");
        const metadata = await mm.parseFile(filePath, { duration: false });

        if (metadata.common.picture && metadata.common.picture.length > 0) {
            const cover = metadata.common.picture[0];
            res.setHeader("Content-Type", cover.format);
            res.send(cover.data);
        } else {
            // Jika mp3 tidak punya gambar cover, return gambar default (bisa redirect ke file lokal default)
            res.status(404).send("No cover art found in file.");
        }
    } catch (e) {
        console.error("[/cover error]", e.message);
        res.status(500).send("Error reading cover art.");
    }
});

// ==========================
// START SERVER
// ==========================
// Gunakan port 2000 agar otomatis bisa dipakai oleh aplikasi Flutter 
// (pastikan app.js lama dimatikan sebelum menjalankan ini)
app.listen(2000, "0.0.0.0", () => {
    console.log("🚀 New Local Music Server jalan di port 2000");
});
