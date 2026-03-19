import express from "express"
import cors from "cors"
import axios from "axios"
import dotenv from "dotenv"
import { spawn } from "child_process"

dotenv.config()

const app = express()
app.use(cors())

const CLIENT_ID = process.env.SPOTIFY_CLIENT_ID
const CLIENT_SECRET = process.env.SPOTIFY_CLIENT_SECRET

// ==========================
// ambil token spotify
// ==========================
async function getToken() {

  const response = await axios.post(
    "https://accounts.spotify.com/api/token",
    "grant_type=client_credentials",
    {
      headers: {
        "Content-Type": "application/x-www-form-urlencoded"
      },
      auth: {
        username: CLIENT_ID,
        password: CLIENT_SECRET
      }
    }
  )

  return response.data.access_token
}

// ==========================
// mapping emotion → query
// ==========================
function getQuery(emotion) {
  const queries = {
    happy: ["Bruno Mars", "Dua Lipa", "Pharrell", "upbeat pop hits", "Taylor Swift"],
    sad: ["Yung Kai Blue", "d4vd", "Billie Eilish", "sad emotional pop", "Adele"],
    angry: ["Linkin Park", "Eminem", "hard rock", "Bring Me The Horizon", "Paramore"],
    stress: ["Laufey", "NIKI", "lofi chill beats", "Daniel Caesar", "Mac Ayres"]
  };

  const emotionList = queries[emotion] || ["relaxing chill pop", "Ed Sheeran", "John Mayer", "acoustic"];
  // Pilih satu artis / kata kunci secara acak setiap kali dipanggil
  return emotionList[Math.floor(Math.random() * emotionList.length)];
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
// ambil musik dari spotify
// ==========================
app.get("/music", async (req, res) => {

  try {

    const emotion = req.query.emotion || "relax"

    const limit = parseInt(req.query.limit) || 10

    // Offset diatur lebih kecil (maks. 5) agar hasil dari pencarian spesifik artis tidak menjadi kosong
    const offset = Math.floor(Math.random() * 5)

    const query = encodeURIComponent(getQuery(emotion))

    const token = await getToken()

    const response = await axios.get(

      `https://api.spotify.com/v1/search?q=${query}&type=track&limit=${limit}&offset=${offset}&market=ID`,

      {
        headers: {
          Authorization: `Bearer ${token}`
        }
      }

    )

    const songs = response.data.tracks.items.map(track => ({

      title: track.name,

      artist: track.artists[0].name,

      album: track.album.name,

      thumbnail: track.album.images[0]?.url,

      duration: `${Math.floor(track.duration_ms / 60000)}:${Math.floor((track.duration_ms % 60000) / 1000).toString().padStart(2, '0')}`,

      spotify_url: track.external_urls.spotify,

      stream_url:
        `http://localhost:3000/stream?title=${encodeURIComponent(track.name)}&artist=${encodeURIComponent(track.artists[0].name)}`

    }))

    res.json({

      emotion: emotion,

      query: query,

      total: songs.length,

      songs: songs

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

  const title = req.query.title
  const artist = req.query.artist

  if (!title || !artist) {
    return res.status(400).send("title and artist required")
  }

  const search = `${title} ${artist}`

  //  const ytdlp = spawn("yt-dlp",[
  const ytdlp = spawn("C:/tools/yt-dlp/yt-dlp.exe", [

    `ytsearch1:${search}`,
    "-f", "bestaudio",
    "-o", "-"

  ])

  const ffmpeg = spawn("ffmpeg", [

    "-i", "pipe:0",
    "-f", "mp3",
    "-"

  ])

  ytdlp.stdout.pipe(ffmpeg.stdin)

  ffmpeg.stdout.pipe(res)

})

// ==========================
// run server
// ==========================
app.listen(3000, () => {

  console.log("Spotify Music API running on port 3000")

})