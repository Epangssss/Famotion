import express from "express"
import cors from "cors"
import axios from "axios"
import dotenv from "dotenv"
import { spawn } from "child_process"

dotenv.config()

const app = express()
app.use(cors())

const YOUTUBE_API_KEY = process.env.API_YT

// ==========================
// mapping emotion → query
// ==========================
function getQueryList(emotion) {
  const queries = {
    happy: ["Bruno Mars", "Dua Lipa", "Pharrell", "upbeat pop hits", "Taylor Swift", "Maroon 5", "Justin Timberlake", "Katy Perry"],
    sad: ["Blue - Yung kai", "d4vd", "Billie Eilish", "sad emotional pop", "Adele", "Lewis Capaldi", "Olivia Rodrigo", "Sam Smith"],
    angry: ["Linkin Park", "Eminem", "hard rock", "Bring Me The Horizon", "Paramore", "Slipknot", "Rage Against The Machine", "System Of A Down"],
  };

  const emotionList = queries[emotion] || ["relaxing chill pop", "Ed Sheeran", "John Mayer", "acoustic"];

  // Pilih dua artis / kata kunci secara acak setiap kali dipanggil
  const shuffled = emotionList.sort(() => 0.5 - Math.random());
  return shuffled.slice(0, 2).map(q => q + " music");
}

// ==========================
// test server
// ==========================
app.get("/", (req, res) => {

  res.json({
    status: "FAMOTION Music API running"
  })

})

// ==========================
// Helper parse durasi ISO 8601 (PT3M4S) => MM:SS
// ==========================
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
    // 1. MULTI QUERY + PAGINATION
    // ==========================
    for (let q of queryList) {
      let nextPageToken = null

      for (let i = 0; i < 2; i++) { // 2 page per query (100 data)
        const url = `https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=50&q=${encodeURIComponent(q)}&type=video&videoCategoryId=10&key=${YOUTUBE_API_KEY}${nextPageToken ? `&pageToken=${nextPageToken}` : ''}`

        const response = await axios.get(url)

        allItems = [...allItems, ...response.data.items]

        nextPageToken = response.data.nextPageToken
        if (!nextPageToken) break
      }
    }

    if (allItems.length === 0) {
      return res.json({ emotion, total: 0, songs: [] })
    }

    // ==========================
    // 2. GET DURATIONS
    // ==========================
    // The maximum number of IDs for videos endpoint is 50. Since allItems can have up to 200 items,
    // we need to chunk the video IDs before fetching durations.
    const allVideoIds = allItems.map(i => i.id.videoId)

    let durations = {}

    // Chunk video IDs into batches of 50
    for (let i = 0; i < allVideoIds.length; i += 50) {
      const chunkIds = allVideoIds.slice(i, i + 50).join(',')
      try {
        const videoResponse = await axios.get(
          `https://www.googleapis.com/youtube/v3/videos?part=contentDetails&id=${chunkIds}&key=${YOUTUBE_API_KEY}`
        )
        const vItems = videoResponse.data.items || []
        vItems.forEach(v => {
          durations[v.id] = v.contentDetails.duration
        })
      } catch (err) {
        console.error("Error fetching video durations chunk: " + err.message)
      }
    }

    // ==========================
    // 3. FILTER LAGU
    // ==========================
    let filtered = []

    for (let item of allItems) {
      const videoId = item.id.videoId
      const durationData = parseDurationData(durations[videoId])

      const title = item.snippet.title.toLowerCase()

      // filter kualitas
      if (
        durationData.totalMinutes >= 1 &&
        durationData.totalMinutes <= 8 && // lebih fleksibel
        !title.includes("full album") &&
        !title.includes("live") &&
        !title.includes("concert")
      ) {
        filtered.push({ item, durationData })
      }
    }

    // ==========================
    // 4. DEDUPLICATE
    // ==========================
    const unique = []
    const seen = new Set()

    for (let data of filtered) {
      const title = data.item.snippet.title
        .toLowerCase()
        .replace(/\(.*?\)/g, "") // hapus (lyrics), (official), dll

      if (!seen.has(title)) {
        seen.add(title)
        unique.push(data)
      }
    }

    // ==========================
    // 5. SHUFFLE + LIMIT
    // ==========================
    unique.sort(() => Math.random() - 0.5)

    const finalItems = unique.slice(0, limit)

    // ==========================
    // 6. FORMAT OUTPUT
    // ==========================
    const songs = finalItems.map(({ item, durationData }) => {
      const videoId = item.id.videoId

      return {
        title: item.snippet.title,
        artist: item.snippet.channelTitle,
        album: "YouTube Music",
        thumbnail:
          item.snippet.thumbnails?.high?.url ||
          item.snippet.thumbnails?.medium?.url ||
          item.snippet.thumbnails?.default?.url,
        duration: durationData.formatted,
        youtube_url: `https://www.youtube.com/watch?v=${videoId}`,
        stream_url: `http://localhost:3000/stream?videoId=${videoId}`
      }
    })

    res.json({
      emotion,
      total: songs.length,
      songs
    })

  } catch (err) {
    console.log(err.response?.data || err.message)

    res.status(500).json({
      error: err.response?.data || err.message
    })
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

  // Jika memiliki Id, stream video secara spesifik, jika tidak ya fallback search judul
  if (videoId) {
    ytdlpArgs = [
      `https://www.youtube.com/watch?v=${videoId}`,
      "-f", "bestaudio",
      "-o", "-"
    ];
  } else if (title && artist) {
    const search = `${title} ${artist}`
    ytdlpArgs = [
      `ytsearch1:${search}`,
      "-f", "bestaudio",
      "-o", "-"
    ];
  } else {
    return res.status(400).send("videoId or title and artist required")
  }

  // const ytdlp = spawn("yt-dlp", ytdlpArgs)
  const ytdlp = spawn("C:/tools/yt-dlp/yt-dlp.exe", ytdlpArgs)

  const ffmpeg = spawn("ffmpeg", [
    "-i", "pipe:0",
    "-f", "mp3",
    "-"
  ])

  ytdlp.stdout.pipe(ffmpeg.stdin)

  ffmpeg.stdout.pipe(res)

})

// ==========================
// run serverF
// ==========================
app.listen(3000, () => {

  console.log("YouTube Music API running on port 3000")

})