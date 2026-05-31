const express = require("express");
const { spawn } = require("child_process");
const ytSearch = require("yt-search");
const rateLimit = require("express-rate-limit");
const https = require("https");
const path = require("path");
const fs = require("fs");
require("dotenv").config();

// ==========================
// LAST.FM CONFIG (dari .env: genre=)
// ==========================
const LASTFM_KEY = process.env.genre;

// Genre user → Last.fm tag name
// Sesuai pilihan genre di app: Phonk, Pop, Rock, Hip Hop, Jazz, Lo-fi, Indie, Chill, Classical, Dangdut, K-Pop, Metal
function genreToLastfmTag(genre) {
    if (!genre) return null;
    const map = {
        'phonk': 'phonk', 'pop': 'pop',
        'rock': 'rock', 'hip hop': 'hip-hop',
        'jazz': 'jazz', 'lo-fi': 'lo-fi',
        'indie': 'indie', 'chill': 'chill',
        'classical': 'classical', 'dangdut': 'dangdut',
        'k-pop': 'k-pop', 'metal': 'metal',
    };
    return map[genre.toLowerCase()] || genre.toLowerCase();
}

// Ambil top tracks dari Last.fm berdasarkan tag genre
function fetchLastfmTracks(tag) {
    return new Promise((resolve) => {
        const url = `https://ws.audioscrobbler.com/2.0/?method=tag.gettoptracks&tag=${encodeURIComponent(tag)}&api_key=${LASTFM_KEY}&format=json&limit=10`;
        https.get(url, resp => {
            let data = "";
            resp.on("data", chunk => data += chunk);
            resp.on("end", () => {
                try {
                    const parsed = JSON.parse(data);
                    const tracks = parsed?.tracks?.track || [];
                    resolve(tracks.map(t => `${t.name} ${t.artist.name}`));
                } catch { resolve([]); }
            });
        }).on("error", () => resolve([]));
    });
}

// ==========================
// YOUTUBE API KEY ROTATION
// Dari .env: music1 - music10
// ==========================
const YT_KEYS = [];
for (let i = 1; i <= 10; i++) {
    const k = process.env[`music${i}`];
    if (k) YT_KEYS.push(k);
}
console.log(`✅ Loaded ${YT_KEYS.length} YouTube API keys`);

let ytKeyIndex = 0;
const ytKeyFailed = new Set(); // Index key yang quota habis

// Reset otomatis setiap 24 jam (quota YouTube reset harian jam 00:00 PST)
setInterval(() => {
    ytKeyFailed.clear();
    ytKeyIndex = 0;
    console.log("🔄 YouTube API key quota reset (daily)");
}, 24 * 60 * 60 * 1000);

// Ambil key YouTube yang masih aktif
function getActiveYtKey() {
    for (let i = 0; i < YT_KEYS.length; i++) {
        const idx = (ytKeyIndex + i) % YT_KEYS.length;
        if (!ytKeyFailed.has(idx)) return { key: YT_KEYS[idx], idx };
    }
    return null; // Semua key habis
}

// Helper: HTTP GET → parse JSON
function fetchJson(url) {
    return new Promise((resolve, reject) => {
        https.get(url, resp => {
            let data = "";
            resp.on("data", chunk => data += chunk);
            resp.on("end", () => {
                try { resolve(JSON.parse(data)); }
                catch (e) { reject(e); }
            });
        }).on("error", reject);
    });
}

// Cari video YouTube pakai API v3 + rotasi key otomatis
// Kalau semua key quota habis → fallback ke yt-search (gratis)
async function ytApiSearch(query, limit = 5) {
    let tries = 0;
    while (tries < YT_KEYS.length) {
        const next = getActiveYtKey();
        if (!next) break; // Semua key sudah dicoba
        const { key, idx } = next;
        try {
            const data = await fetchJson(
                `https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=${limit}&q=${encodeURIComponent(query)}&type=video&videoCategoryId=10&key=${key}`
            );
            if (data.error) {
                const reason = data.error.errors?.[0]?.reason || "";
                const isQuota = reason.includes("quota") || reason.includes("Limit") || reason.includes("exceeded");
                if (isQuota) {
                    ytKeyFailed.add(idx);
                    ytKeyIndex = (idx + 1) % YT_KEYS.length;
                    console.warn(`⚠️  YT API key ${idx + 1} quota habis → coba key berikutnya`);
                    tries++;
                    continue;
                }
                throw new Error(data.error.message);
            }
            // Normalize format agar cocok dengan output yt-search
            return (data.items || []).map(item => ({
                title: item.snippet.title,
                author: { name: item.snippet.channelTitle },
                videoId: item.id.videoId,
                thumbnail: item.snippet.thumbnails?.high?.url || item.snippet.thumbnails?.default?.url,
                duration: { seconds: 210, timestamp: "–" }, // durasi tidak diambil (hemat kuota)
                url: `https://www.youtube.com/watch?v=${item.id.videoId}`,
                _fromApi: true // marker: dari YouTube Data API v3
            }));
        } catch (err) {
            tries++;
        }
    }
    // Fallback: semua key habis → pakai yt-search gratis
    console.log(`🔄 Semua YT API key habis → fallback yt-search: "${query}"`);
    try {
        const r = await ytSearch(query);
        return r.videos.slice(0, limit);
    } catch { return []; }
}

// ==========================
// EMOTION → QUERY MAPPING
// ==========================
// emotion + genre → list query yt-search
function getQueryList(emotion, genre = '') {
    // Artis/query base per emotion
    const queries = {
        happy: ["Bruno Mars", "Dua Lipa", "Pharrell", "Taylor Swift", "Maroon 5", "Justin Timberlake", "Katy Perry", "Coldplay", "Ed Sheeran", "Charlie Puth"],
        sad: ["Blue - Yung kai", "d4vd", "Billie Eilish", "Adele", "Lewis Capaldi", "Olivia Rodrigo", "Sam Smith", "Joji", "Conan Gray", "Lana Del Rey"],
        angry: ["Linkin Park", "Eminem", "Bring Me The Horizon", "Paramore", "Slipknot", "Rage Against The Machine", "System Of A Down", "Metallica", "Nirvana", "Skillet"],
        neutral: ["Lofi Girl", "Laufey", "Aisha Badru", "Norah Jones", "Jack Johnson", "John Mayer", "Kina Grannis", "Jason Mraz", "Colbie Caillat", "Mac DeMarco"],
    };

    let rawEmotion = emotion?.toLowerCase() || "happy";
    if (rawEmotion === "anger") rawEmotion = "angry";
    if (rawEmotion === "netral") rawEmotion = "neutral";

    // Hanya happy/sad/angry/neutral yang didukung; fallback ke happy
    const baseEmotion = Object.keys(queries).find(k => rawEmotion.startsWith(k)) || "happy";
    const genreSuffix = genre ? ` ${genre}` : "";

    // Gabungkan artis + genre (misal: "Bruno Mars Jazz music")
    let emotionList = queries[baseEmotion].map(q => q + genreSuffix);

    // Shuffle & ambil 4 query
    for (let i = emotionList.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [emotionList[i], emotionList[j]] = [emotionList[j], emotionList[i]];
    }
    return emotionList.slice(0, 4).map(q => q + " music");
}

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
// Daftar emotion keyword yang valid
const EMOTION_KEYWORDS = ["happy", "sad", "angry", "neutral"];

app.get("/music", async (req, res) => {
    try {
        const rawQ = req.query.q || "";
        const emotion = req.query.emotion || "";
        const genre = req.query.genre || "";   // misal: "Jazz", "Lo-fi", "K-Pop"
        const artist = req.query.artist || "";  // Artis favorit user
        const limit = parseInt(req.query.limit) || 50;

        // ==========================
        // CABANG A: PENCARIAN LANGSUNG
        // Jika ?q= bukan emotion keyword → cari langsung ke YouTube
        // Contoh: ?q=kobo+official+audio → hasil: lagu Kobo
        // ==========================
        const isEmotionQuery = EMOTION_KEYWORDS.some(k => rawQ.toLowerCase().startsWith(k));
        if (rawQ && !isEmotionQuery && !emotion) {
            const searchResults = await ytApiSearch(rawQ, 20);
            // Fallback ke yt-search jika API habis
            let items = searchResults.length > 0 ? searchResults : await ytSearch(rawQ).then(r => r.videos.slice(0, 20)).catch(() => []);

            // Filter konten bermasalah
            const BLOCKED_Q = ["full album", "reaction", "podcast", "karaoke", "#shorts", "meme", "funny"];
            items = items.filter(v => {
                const t = v.title.toLowerCase();
                return !BLOCKED_Q.some(w => t.includes(w));
            });

            const songs = items.slice(0, limit).map(v => ({
                title: v.title,
                artist: v.author?.name || v.snippet?.channelTitle || "Unknown",
                duration: v.duration?.timestamp || "–",
                thumbnail: v.thumbnail || "",
                videoId: v.videoId || "",
                stream_url: `http://${req.get('host') || '103.247.11.142'}/stream?videoId=${v.videoId}`
            }));

            return res.json({ query: rawQ, total: songs.length, songs });
        }

        // ==========================
        // CABANG B: REKOMENDASI BERBASIS EMOSI (behaviour lama)
        // ==========================
        const resolvedEmotion = emotion || rawQ || "happy";

        // ==========================
        // STEP 1: Siapkan semua query
        // Emotion + Genre (yt-search) + Last.fm top tracks by genre (paralel)
        // ==========================
        const emotionQueries = getQueryList(resolvedEmotion, genre); // 4 query: artis + genre
        const lastfmTag = genreToLastfmTag(genre);      // tag Last.fm dari genre user

        // Ambil semua sumber SECARA PARALEL
        const [ytResults, lastfmVideos, artistVideos] = await Promise.all([
            // Sumber 1: emotion+genre queries via yt-search gratis (4 query × 8 video)
            Promise.all(
                emotionQueries.map(q =>
                    ytSearch(q).then(r => r.videos.slice(0, 8)).catch(() => [])
                )
            ),
            // Sumber 2: Last.fm top tracks by genre → cari di YouTube pakai API v3 + rotasi key
            lastfmTag
                ? fetchLastfmTracks(lastfmTag).then(trackQueries =>
                    Promise.all(
                        trackQueries.slice(0, 5).map(q => ytApiSearch(q, 3))
                    ).then(results => results.flat())
                ).catch(() => [])
                : Promise.resolve([]),
            // Sumber 3: Artis Favorit (Prioritas Sangat Tinggi)
            artist
                ? ytSearch(`${artist} official music`).then(r => r.videos.slice(0, 30)).catch(() => [])
                : Promise.resolve([])
        ]);

        // Gabungkan: 
        // 1. Artis Favorit (porsi besar)
        // 2. yt-search (broad emotion)
        // 3. Last.fm (spesifik genre)
        let allItems = [
            ...artistVideos,
            ...ytResults.flat(),
            ...lastfmVideos
        ];

        if (allItems.length === 0) {
            return res.json({ emotion: resolvedEmotion, genre, total: 0, songs: [] });
        }

        // ==========================
        // STEP 2: Filter
        // Items dari YouTube API v3 (_fromApi) → skip filter durasi (tidak ada data durasi)
        // ==========================
        const BLOCKED = ["full album", "reaction", "podcast", "karaoke"];
        const filtered = allItems.filter(v => {
            const title = v.title.toLowerCase();
            const blocked = BLOCKED.some(w => title.includes(w));
            if (blocked) return false;
            if (v._fromApi) return true; // API v3: skip durasi, cukup filter judul
            const mins = v.duration.seconds / 60;
            return mins >= 1 && mins <= 8 &&
                !title.includes("live") && !title.includes("concert");
        });

        // ==========================
        // STEP 3: Deduplicate by title
        // ==========================
        const seen = new Set();
        const unique = [];
        for (let v of filtered) {
            const key = v.title.toLowerCase().replace(/\(.*?\)/g, "").replace(/\[.*?\]/g, "").trim();
            if (!seen.has(key)) { seen.add(key); unique.push(v); }
        }

        // ==========================
        // STEP 4: Shuffle Fisher-Yates
        // ==========================
        for (let i = unique.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [unique[i], unique[j]] = [unique[j], unique[i]];
        }

        const songs = unique.slice(0, limit).map(v => ({
            title: v.title,
            artist: v.author.name,
            duration: v.duration.timestamp,
            thumbnail: v.thumbnail,
            videoId: v.videoId,
            stream_url: `http://${req.get('host') || '103.247.11.142'}/stream?videoId=${v.videoId}`
        }));

        res.json({ emotion: resolvedEmotion, genre, total: songs.length, songs });

    } catch (err) {
        console.error("[/music error]", err.message);
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
    const localYtdlpPath = path.join(__dirname, "yt-dlp", "yt-dlp.exe");
    const localFfmpegPath = path.join(__dirname, "ffmpeg-8.1-essentials_build", "bin");

    let ytdlpCmd = "yt-dlp";
    const spawnArgs = [
        url,
        "-f", "bestaudio[ext=m4a]/bestaudio",
        "--no-playlist",
        "-o", "-"
    ];

    if (fs.existsSync(localYtdlpPath)) {
        ytdlpCmd = localYtdlpPath;
        if (fs.existsSync(localFfmpegPath)) {
            spawnArgs.push("--ffmpeg-location", localFfmpegPath);
        }
    }

    const ytdlp = spawn(ytdlpCmd, spawnArgs);

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
