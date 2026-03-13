import express from "express"
import cors from "cors"
import axios from "axios"
import dotenv from "dotenv"

dotenv.config()

const app = express()

app.use(cors())

const CLIENT_ID = process.env.SPOTIFY_CLIENT_ID
const CLIENT_SECRET = process.env.SPOTIFY_CLIENT_SECRET

// ambil token spotify
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

// mapping emotion
function getQuery(emotion){

 switch(emotion){

  case "happy":
   return "happy upbeat music"

  case "sad":
   return "sad piano music"

  case "angry":
   return "calming relaxing music"

  case "stress":
   return "stress relief music"

  default:
   return "relaxing music"
 }
}

// test server
app.get("/", (req,res)=>{
 res.json({
  status:"FAMOTION Music API running"
 })
})

app.get("/music", async (req,res)=>{

 try{

  const emotion = req.query.emotion || "relax"

  const limit = parseInt(req.query.limit) || 10

  const offset = Math.floor(Math.random() * 50)

  const query = encodeURIComponent(getQuery(emotion))

  const token = await getToken()

  const response = await axios.get(
   `https://api.spotify.com/v1/search?q=${query}&type=track&limit=${limit}&offset=${offset}&market=ID`,
   {
    headers:{
     Authorization:`Bearer ${token}`
    }
   }
  )

  const songs = response.data.tracks.items.map(track => ({
   title: track.name,
   artist: track.artists[0].name,
   album: track.album.name,
   thumbnail: track.album.images[0]?.url,
   preview: track.preview_url,
   spotify_url: track.external_urls.spotify
  }))

  res.json({
   emotion: emotion,
   query: query,
   total: songs.length,
   songs: songs
  })

 }catch(err){

  console.log(err.response?.data || err.message)

  res.status(500).json({
   error: err.response?.data || err.message
  })

 }

})

app.listen(3000, ()=>{
 console.log("Spotify Music API running on port 3000")
})