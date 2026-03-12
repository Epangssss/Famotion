import express from "express"
import cors from "cors"
import YTMusic from "ytmusic-api"

const app = express()
app.use(cors())

const ytmusic = new YTMusic()

await ytmusic.initialize()

app.get("/music", async (req, res) => {

  try {

    const query = req.query.q || "relaxing music"

    const songs = await ytmusic.searchSongs(query)

    const result = songs.slice(0,25).map(song => ({
      title: song.name,
      artist: song.artist?.name,
      duration: song.duration,
      thumbnail: `https://img.youtube.com/vi/${song.videoId}/hqdefault.jpg`,
      videoId: song.videoId
    }))

    res.json(result)

  } catch (err) {

    res.status(500).json({error: err.toString()})

  }

})

const PORT = process.env.PORT || 3000

app.listen(PORT, () => {
  console.log("Music API running")
})      