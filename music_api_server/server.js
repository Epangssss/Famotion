import express from "express"
import cors from "cors"
import axios from "axios"
import dotenv from "dotenv"
import { spawn } from "child_process"
import ytSearch from "yt-search"

dotenv.config()

const app = express()
app.use(cors())

const YOUTUBE_API_KEY = process.env.API_YT

// ==========================
// mapping emotion → query
// ==========================
function getQueryList(emotion) {
  const queries = {
    happy: ["Bruno Mars", "Dua Lipa", "Pharrell", "upbeat pop hits", "Taylor Swift", "Maroon 5", "Justin Timberlake", "Katy Perry", "Coldplay", "Ed Sheeran happy"],
    sad: ["Blue - Yung kai", "d4vd", "Billie Eilish", "sad emotional pop", "Adele", "Lewis Capaldi", "Olivia Rodrigo", "Sam Smith", "Joji", "Conan Gray"],
    angry: ["Linkin Park", "Eminem", "hard rock", "Bring Me The Horizon", "Paramore", "Slipknot", "Rage Against The Machine", "System Of A Down", "Metallica", "Nirvana"],
  };

  const emotionKey = emotion?.toLowerCase() || "relax";
  const emotionList = queries[emotionKey] || [
    `best ${emotionKey} songs`,
    `popular ${emotionKey} music`,
    `${emotionKey} playlist`,
    `${emotionKey} hits`
  ];

  // --- KODE LAMA (Pilih 2 acak dengan sort biasa) ---
  // const shuffled = emotionList.sort(() => 0.5 - Math.random());
  // return shuffled.slice(0, 2).map(q => q + " music");

  // --- KODE BARU (Pilih 4 acak dengan Fisher-Yates yang akurat) ---
  for (let i = emotionList.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [emotionList[i], emotionList[j]] = [emotionList[j], emotionList[i]];
  }
  return emotionList.slice(0, 4).map(q => q + " music");
}

app.get("/", (req, res) => {
  res.json({
    status: "FAMOTION Music API running"
  })
})

// --- KODE LAMA ---
// Helper parse durasi ISO 8601 (PT3M4S) => MM:SS
function parseDurationData(isoDuration) {
  if (!isoDuration) return { formatted: "0:00", totalMinutes: 0 };
  const match = isoDuration.match(/PT(\d+H)?(\d+M)?(\d+S)?/);
  const hours = parseInt(match?.[1]) || 0;
  const minutes = parseInt(match?.[2]) || 0;
  const seconds = parseInt(match?.[3]) || 0;
  const totalMinutes = hours * 60 + minutes;
  return { formatted: `${totalMinutes}:${seconds.toString().padStart(2, '0')}`, totalMinutes };
}

// ==========================
// ambil musik dari youtube
// ==========================
app.get("/music", async (req, res) => {
  try {
    const emotion = req.query.emotion || "relax"
    const limit = parseInt(req.query.limit) || 50

    const queryList = getQueryList(emotion)

    let allItems = []

    // ==========================
    // 1. PENGAMBILAN DATA (FETCHING)
    // ==========================

    /* --- KODE LAMA (GOOGLE API BERBAYAR / KUOTA) ---
    for (let q of queryList) {
      let nextPageToken = null
      for (let i = 0; i < 2; i++) { // 2 page per query (100 data)
        const url = `https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=50&q=${encodeURIComponent(q)}&type=video&videoCategoryId=10&key=${YOUTUBE_API_KEY}${nextPageToken ? \`&pageToken=${nextPageToken}\` : ''}`
        const response = await axios.get(url)
        allItems = [...allItems, ...response.data.items]
        nextPageToken = response.data.nextPageToken
        if (!nextPageToken) break
      }
    }
    */

    // --- KODE BARU (YT-SEARCH GRATIS) ---
    for (let q of queryList) {
      try {
        const r = await ytSearch(q)
        const videos = r.videos.slice(0, 15) // Kita ambil 15 per kueri (dari 4 kueri acak)
        allItems = [...allItems, ...videos]
      } catch (err) {
        console.error("Error dari yt-search:", q, err)
      }
    }

    if (allItems.length === 0) {
      return res.json({ emotion, total: 0, songs: [] })
    }

    // ==========================
    // 2. MENDAPATKAN DURASI PADA KODE LAMA (DI-SKIP DI BARU)
    // ==========================

    /* --- KODE LAMA (Ambil Durasi Tambahan Pakai Kuota API) ---
    const allVideoIds = allItems.map(i => i.id.videoId)
    let durations = {}
    for (let i = 0; i < allVideoIds.length; i += 50) {
      const chunkIds = allVideoIds.slice(i, i + 50).join(',')
      try {
        const videoResponse = await axios.get(
          \`https://www.googleapis.com/youtube/v3/videos?part=contentDetails&id=\${chunkIds}&key=\${YOUTUBE_API_KEY}\`
        )
        const vItems = videoResponse.data.items || []
        vItems.forEach(v => {
          durations[v.id] = v.contentDetails.duration
        })
      } catch (err) {
        console.error("Error fetching chunk: " + err.message)
      }
    }
    */

    // ==========================
    // 3. FILTER LAGU
    // ==========================
    let filtered = []

    /* --- KODE LAMA ---
    for (let item of allItems) {
      const videoId = item.id.videoId
      const durationData = parseDurationData(durations[videoId])
      const title = item.snippet.title.toLowerCase()

      if (durationData.totalMinutes >= 1 && durationData.totalMinutes <= 8 && !title.includes("full album") && !title.includes("live") && !title.includes("concert")) {
        filtered.push({ item, durationData })
      }
    }
    */

    // --- KODE BARU ---
    for (let video of allItems) {
      const title = video.title.toLowerCase()
      const durationMins = video.duration.seconds / 60

      if (durationMins >= 1 && durationMins <= 8 && !title.includes("full album") && !title.includes("live") && !title.includes("concert")) {
        filtered.push(video) // video sudah memuat durasi, thumbnail, URL, dsb
      }
    }

    // ==========================
    // 4. DEDUPLICATE
    // ==========================
    const unique = []
    const seen = new Set()

    /* --- KODE LAMA ---
    for (let data of filtered) {
      const title = data.item.snippet.title.toLowerCase().replace(/\(.*?\)/g, "")
      if (!seen.has(title)) { seen.add(title); unique.push(data) }
    }
    */

    // --- KODE BARU ---
    for (let video of filtered) {
      const title = video.title.toLowerCase().replace(/\(.*?\)/g, "")
      if (!seen.has(title)) { seen.add(title); unique.push(video) }
    }

    // ==========================
    // 5. SHUFFLE + LIMIT
    // ==========================

    /* --- KODE LAMA ---
    unique.sort(() => Math.random() - 0.5)
    */

    // --- KODE BARU (Acak Sempurna) ---
    for (let i = unique.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [unique[i], unique[j]] = [unique[j], unique[i]];
    }

    const finalItems = unique.slice(0, limit)

    // ==========================
    // 6. FORMAT OUTPUT
    // ==========================

    /* --- KODE LAMA ---
    const songs = finalItems.map(({ item, durationData }) => {
      const videoId = item.id.videoId
      return {
        title: item.snippet.title,
        artist: item.snippet.channelTitle,
        album: "YouTube Music",
        thumbnail: item.snippet.thumbnails?.high?.url || item.snippet.thumbnails?.medium?.url || item.snippet.thumbnails?.default?.url,
        duration: durationData.formatted,
        youtube_url: \`https://www.youtube.com/watch?v=\${videoId}\`,
        stream_url: \`http://localhost:3000/stream?videoId=\${videoId}\`
      }
    })
    */

    // --- KODE BARU ---
    const songs = finalItems.map((video) => {
      return {
        title: video.title,
        artist: video.author.name,
        album: "YouTube Music",
        thumbnail: video.thumbnail || video.image,
        duration: video.duration.timestamp,
        youtube_url: video.url,
        stream_url: `http://localhost:3000/stream?videoId=${video.videoId}`
      }
    })

    res.json({
      emotion,
      total: songs.length,
      songs
    })

  } catch (err) {
    console.log(err.message)
    res.status(500).json({ error: err.message })
  }
})

// ==========================
// streaming audio
// ==========================
app.get("/stream", (req, res) => {
  const videoId = req.query.videoId
  const title = req.query.title
  const artist = req.query.artist

  let ytdlpArgs = [];
  if (videoId) {
    ytdlpArgs = [`https://www.youtube.com/watch?v=${videoId}`, "-f", "bestaudio", "-o", "-"];
  } else if (title && artist) {
    ytdlpArgs = [`ytsearch1:${title} ${artist}`, "-f", "bestaudio", "-o", "-"];
  } else {
    return res.status(400).send("videoId or title and artist required")
  }

  const ytdlp = spawn("C:/tools/yt-dlp/yt-dlp.exe", ytdlpArgs)
  const ffmpeg = spawn("ffmpeg", ["-i", "pipe:0", "-f", "mp3", "-"])

  ytdlp.stdout.pipe(ffmpeg.stdin)
  ffmpeg.stdout.pipe(res)
})

app.listen(2000, () => {
  console.log("YouTube Music API running on port 2000")
})