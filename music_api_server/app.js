const express = require("express");
const { spawn } = require("child_process");
const ytSearch = require("yt-search");
const rateLimit = require("express-rate-limit");

const app = express();

// ==========================
// RATE LIMIT (ANTI SPAM)
// ==========================
const limiter = rateLimit({
    windowMs: 60 * 1000, // 1 menit
    max: 20, // max 20 request per menit per IP
    message: { error: "Terlalu banyak request, coba lagi nanti" }
});

app.use(limiter);

// ==========================
// TRACK USER STREAM
// ==========================
const userStreams = new Map();
const MAX_STREAM_PER_USER = 5;
const MAX_GLOBAL_STREAM = 20;
let currentGlobalStream = 0;

// Auto-reset stuck counters setiap 60 detik
setInterval(() => {
    userStreams.clear();
    currentGlobalStream = 0;
}, 60000);

// ==========================
// ROOT
// ==========================
app.get("/", (req, res) => {
    res.json({ status: "Music API running 🚀" });
});

// ==========================
// SEARCH MUSIC
// ==========================
app.get("/music", async (req, res) => {
    try {
        const query = req.query.q || "lofi music";


        const result = await ytSearch(query);

        const songs = result.videos
            .filter(v => {
                const title = v.title.toLowerCase();
                const duration = v.duration.seconds / 60;

                return (
                    duration >= 1 &&
                    duration <= 8 &&
                    !title.includes("live") &&
                    !title.includes("concert") &&
                    !title.includes("full album") &&
                    !title.includes("reaction") &&
                    !title.includes("podcast")
                );
            })
            .slice(0, 10)
            .map(v => ({
                title: v.title,
                artist: v.author.name,
                duration: v.timestamp,
                thumbnail: v.thumbnail,
                videoId: v.videoId,
                stream_url: `http://103.253.212.130:2000/stream?videoId=${v.videoId}`
            }));

        res.json({ total: songs.length, songs });

    } catch (err) {
        res.status(500).json({ error: "Gagal ambil musik" });
    }


});

// ==========================
// STREAM AUDIO (PROTECTED)
// ==========================
app.get("/stream", (req, res) => {
    const ip = req.ip;
    const videoId = req.query.videoId;


    if (!videoId) {
        return res.status(400).send("videoId required");
    }

    // cek limit per user
    const userCount = userStreams.get(ip) || 0;

    if (userCount >= MAX_STREAM_PER_USER) {
        return res.status(429).json({
            error: "Limit stream per user tercapai"
        });
    }

    // cek global limit
    if (currentGlobalStream >= MAX_GLOBAL_STREAM) {
        return res.status(503).json({
            error: "Server sedang sibuk"
        });
    }

    // increment
    userStreams.set(ip, userCount + 1);
    currentGlobalStream++;
    const url = `https://www.youtube.com/watch?v=${videoId}`;

    // LANGKAH 1: Kirim header DULUAN agar ExoPlayer Android tidak timeout
    // (yt-dlp butuh 5-10 detik untuk mulai, tapi Android cuma sabar 8 detik)
    res.writeHead(200, {
        "Content-Type": "audio/mp4",
        "Transfer-Encoding": "chunked",
        "Connection": "keep-alive"
    });
    res.flushHeaders();

    // LANGKAH 2: Jalankan yt-dlp dengan format M4A (bukan WebM!)
    // WebM bikin ExoPlayer Android nge-hang karena tidak ada Content-Length
    const ytdlp = spawn("yt-dlp", [
        url,
        "-f", "bestaudio[ext=m4a]/bestaudio",
        "--no-playlist",
        "-o", "-"
    ]);

    ytdlp.stdout.pipe(res);

    let cleaned = false;
    const cleanup = () => {
        if (cleaned) return; // Cegah double-cleanup
        cleaned = true;
        const cur = userStreams.get(ip) || 1;
        userStreams.set(ip, Math.max(0, cur - 1));
        currentGlobalStream = Math.max(0, currentGlobalStream - 1);
    };

    res.on("close", () => {
        ytdlp.kill(); // Hentikan download jika user ganti lagu
        cleanup();
    });
    ytdlp.on("close", cleanup);

    ytdlp.stderr.on("data", (data) => {
        console.log("yt-dlp:", data.toString());
    });

});

// ==========================
// START SERVER
// ==========================
app.listen(2000, "0.0.0.0", () => {
    console.log("🚀 Server jalan di port 2000");
});
