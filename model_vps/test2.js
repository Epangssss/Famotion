const { spawn } = require("child_process");
const path = require("path");

const ytdlpPath = path.join(__dirname, "yt-dlp", "yt-dlp.exe");
const ffmpegPath = path.join(__dirname, "ffmpeg-8.1-essentials_build", "bin");
const url = "https://www.youtube.com/watch?v=ZbZSe6N_BXs";

let ytdlpCmd = ytdlpPath;
const spawnArgs = [
    url,
    "-f", "bestaudio[ext=m4a]/bestaudio",
    "--no-playlist",
    "-o", "-",
    "--ffmpeg-location", ffmpegPath
];

console.log("Args:", spawnArgs);

const ytdlp = spawn(ytdlpCmd, spawnArgs);

let bytes = 0;
ytdlp.stdout.on("data", (c) => {
    bytes += c.length;
    if(bytes > 100000) {
        console.log("Success! Bytes:", bytes);
        ytdlp.kill();
        process.exit(0);
    }
});

ytdlp.stderr.on("data", (d) => console.log("STDERR:", d.toString()));
ytdlp.on("error", (e) => console.error("ERR:", e));
ytdlp.on("close", (c) => console.log("CLOSE:", c));
