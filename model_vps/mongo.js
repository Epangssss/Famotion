const express = require('express');
const { OAuth2Client } = require('google-auth-library');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const cors = require('cors');
const nodemailer = require('nodemailer');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// Sambungkan ke MongoDB (VPS)
// Jika node.js ini dijalankan di komputermu sendiri, ganti "localhost" dengan IP address VPS-mu.
const mongoURI = process.env.MONGO_URI;

mongoose.connect(mongoURI)
    .then(() => console.log("MongoDB Connected"))
    .catch(err => console.log(err));

// Buat Schema User
const userSchema = new mongoose.Schema({
    email: String,
    name: String,
    googleId: String,
    password: { type: String, default: null },
    picture: String,
    resetPasswordOtp: String,
    resetPasswordExpires: Date,
});
const User = mongoose.model('User', userSchema);

// Buat Schema Daftar Putar & Like Lagu
const playlistSchema = new mongoose.Schema({
    userId: { type: String, required: true, unique: true },
    likedSongs: { type: Array, default: [] },
    playlists: { type: Object, default: {} }
});
const Playlist = mongoose.model('Playlist', playlistSchema);

// Buat Schema Data Emosi (seperti di script Python)
const emotionSchema = new mongoose.Schema({
    userId: { type: String, required: true },
    emotion: String,
    confidence: Number,
    created_at: { type: Date, default: Date.now }
});
const Emotion = mongoose.model('Emotion', emotionSchema);

// Buat Schema History Lagu
const historySchema = new mongoose.Schema({
    userId: { type: String, required: true },
    audioUrl: String,
    title: String,
    artist: String,
    imageUrl: String,
    durationMs: Number,
    playedAt: { type: Date, default: Date.now }
});
const History = mongoose.model('History', historySchema);

const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

app.post('/api/auth/google/login', async (req, res) => {
    const { idToken } = req.body;
    try {
        const ticket = await client.verifyIdToken({
            idToken: idToken,
            audience: process.env.GOOGLE_CLIENT_ID
        });
        const payload = ticket.getPayload();
        const { email, name, sub: googleId, picture } = payload;

        // Cari berdasarkan email terlebih dahulu agar bisa menyambung
        let user = await User.findOne({ email });
        if (!user) {
            return res.status(404).json({ error: 'Akun belum terdaftar, silakan Sign Up terlebih dahulu.' });
        }

        // Akun ditemukan via email, pastikan googleId tercatat (Merge)
        if (!user.googleId) {
            user.googleId = googleId;
            user.picture = picture;
            await user.save();
        }

        const sessionToken = jwt.sign({ userId: user._id, email: user.email }, process.env.JWT_SECRET, { expiresIn: '7d' });
        res.status(200).json({ message: 'Login berhasil', token: sessionToken, user: user });
    } catch (error) {
        console.log("Error verifikasi token:", error);
        res.status(401).json({ error: 'Token tidak valid' });
    }
});

app.post('/api/auth/google/signup', async (req, res) => {
    const { idToken } = req.body;
    try {
        const ticket = await client.verifyIdToken({
            idToken: idToken,
            audience: process.env.GOOGLE_CLIENT_ID,
        });
        const payload = ticket.getPayload();
        const { email, name, sub: googleId, picture } = payload;

        let user = await User.findOne({ email });
        if (user) {
            // Jika sudah terdaftar (baik Manual maupun Google), sambungkan!
            if (!user.googleId) {
                user.googleId = googleId;
                user.picture = picture;
                await user.save();
                const sessionToken = jwt.sign({ userId: user._id, email: user.email }, process.env.JWT_SECRET, { expiresIn: '7d' });
                return res.status(200).json({ message: 'Akun dihubungkan dengan Google', token: sessionToken, user: user });
            }
            return res.status(409).json({ error: 'Akun sudah terdaftar, silakan Login.' });
        }

        // Insert new
        user = await User.create({ email, name, googleId, picture });
        const sessionToken = jwt.sign({ userId: user._id, email: user.email }, process.env.JWT_SECRET, { expiresIn: '7d' });
        res.status(201).json({ message: 'Sign Up berhasil', token: sessionToken, user: user });
    } catch (error) {
        console.log("Error verifikasi token:", error);
        res.status(401).json({ error: 'Token tidak valid' });
    }
});

// =========== MANUAL AUTHENTICATION =========== //

app.post('/api/auth/register', async (req, res) => {
    const { email, name, password } = req.body;
    try {
        let user = await User.findOne({ email });
        if (user) {
            return res.status(409).json({ error: 'Email sudah terdaftar. Silakan login.' });
        }

        const hashedPassword = await bcrypt.hash(password, 10);
        user = await User.create({ email, name, password: hashedPassword });

        const sessionToken = jwt.sign({ userId: user._id, email: user.email }, process.env.JWT_SECRET, { expiresIn: '7d' });
        res.status(201).json({ message: 'Registrasi berhasil', token: sessionToken, user: user });
    } catch (error) {
        res.status(500).json({ error: 'Terjadi kesalahan di server.' });
    }
});

app.post('/api/auth/login', async (req, res) => {
    const { email, password } = req.body;
    try {
        const user = await User.findOne({ email });
        if (!user) {
            return res.status(404).json({ error: 'Email belum terdaftar. Silakan sign up.' });
        }

        if (!user.password) {
            return res.status(400).json({ error: 'Akun ini terdaftar via Google. Silakan gunakan Google Sign-In.' });
        }

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(401).json({ error: 'Password salah.' });
        }

        const sessionToken = jwt.sign({ userId: user._id, email: user.email }, process.env.JWT_SECRET, { expiresIn: '7d' });
        res.status(200).json({ message: 'Login berhasil', token: sessionToken, user: user });
    } catch (error) {
        res.status(500).json({ error: 'Terjadi kesalahan di server.' });
    }
});

// Nodemailer transporter config
const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
        user: process.env.GMAIL_USER || 'dummy@gmail.com',
        pass: process.env.GMAIL_PASS || 'dummy123',
    }
});

app.post('/api/auth/forgot-password', async (req, res) => {
    const { email } = req.body;
    try {
        const user = await User.findOne({ email });
        if (!user) {
            return res.status(404).json({ error: 'Email tidak ditemukan.' });
        }

        // Buat 4-digit OTP
        const otp = Math.floor(1000 + Math.random() * 9000).toString();
        user.resetPasswordOtp = otp;
        user.resetPasswordExpires = Date.now() + 15 * 60 * 1000; // 15 menit
        await user.save();

        if (process.env.GMAIL_USER && process.env.GMAIL_PASS) {
            const mailOptions = {
                from: process.env.GMAIL_USER,
                to: user.email,
                subject: 'Famotion - Reset Password Anda',
                html: `<p>Halo ${user.name},</p><p>Kode OTP Anda untuk mereset sandi adalah: <strong>${otp}</strong></p><p>Kode ini berlaku selama 15 menit.</p>`
            };
            await transporter.sendMail(mailOptions);
        } else {
            console.log(`[SIMULASI EMAIL OTP] Karena GMAIL_USER kosong, OTP untuk ${email} adalah: ${otp}`);
        }

        res.status(200).json({ message: 'OTP telah dikirim ke email Anda.' });
    } catch (error) {
        res.status(500).json({ error: 'Terjadi kesalahan saat mengirim OTP.' });
    }
});

app.post('/api/auth/reset-password', async (req, res) => {
    const { email, otp, newPassword } = req.body;
    try {
        const user = await User.findOne({
            email,
            resetPasswordOtp: otp,
            resetPasswordExpires: { $gt: Date.now() }
        });

        if (!user) {
            return res.status(400).json({ error: 'OTP salah atau sudah kedaluwarsa.' });
        }

        const hashedPassword = await bcrypt.hash(newPassword, 10);
        user.password = hashedPassword;
        user.resetPasswordOtp = undefined;
        user.resetPasswordExpires = undefined;
        await user.save();

        res.status(200).json({ message: 'Sandi berhasil direset. Silakan login kembali.' });
    } catch (error) {
        res.status(500).json({ error: 'Terjadi kesalahan saat verifikasi OTP.' });
    }
});

app.post('/api/auth/change-password', async (req, res) => {
    const { email, oldPassword, newPassword } = req.body;
    try {
        const user = await User.findOne({ email });
        if (!user) {
            return res.status(404).json({ error: 'User tidak ditemukan.' });
        }

        // Kalau akun murni Google, mereka mungkin tidak punya password lama
        if (user.password) {
            const isMatch = await bcrypt.compare(oldPassword, user.password);
            if (!isMatch) {
                return res.status(401).json({ error: 'Sandi lama salah.' });
            }
        }

        const hashedPassword = await bcrypt.hash(newPassword, 10);
        user.password = hashedPassword;
        await user.save();

        res.status(200).json({ message: 'Sandi berhasil diubah!' });
    } catch (error) {
        res.status(500).json({ error: 'Terjadi kesalahan di server.' });
    }
});

// =========== PLAYLIST CLOUD SYNC =========== //

app.post('/api/playlist/sync', async (req, res) => {
    const { userId, likedSongs, playlists } = req.body;
    if (!userId) return res.status(400).json({ error: 'User ID diperlukan' });

    try {
        await Playlist.findOneAndUpdate(
            { userId }, 
            { likedSongs: likedSongs || [], playlists: playlists || {} }, 
            { upsert: true, new: true }
        );
        res.status(200).json({ message: 'Playlist tersimpan di awan MongoDB', status: 'success' });
    } catch (error) {
        res.status(500).json({ error: 'Terjadi kesalahan saat sinkronisasi.' });
    }
});

app.get('/api/playlist/:userId', async (req, res) => {
    try {
        const data = await Playlist.findOne({ userId: req.params.userId });
        if (!data) {
            // Jika user baru dan belum punya table playlist, kembalikan data kosong
            return res.status(200).json({ likedSongs: [], playlists: {} });
        }
        res.status(200).json(data);
    } catch (error) {
        res.status(500).json({ error: 'Terjadi kesalahan server saat tarik data.' });
    }
});

// =========== EMOTION LOGGING =========== //

app.post('/api/emotions', async (req, res) => {
    const { userId, emotion, confidence } = req.body;
    if (!userId) return res.status(400).json({ error: 'User ID diperlukan' });

    try {
        const newEmotion = await Emotion.create({ userId, emotion, confidence });
        res.status(201).json({ message: 'OK data lengkap masuk', data: newEmotion });
    } catch (error) {
        res.status(500).json({ error: 'Gagal menyimpan data emosi.' });
    }
});

app.get('/api/emotions/:userId', async (req, res) => {
    try {
        // Tarik data emosi 7 hari terakhir
        const sevenDaysAgo = new Date();
        sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

        const data = await Emotion.find({
            userId: req.params.userId,
            created_at: { $gte: sevenDaysAgo }
        }).sort({ created_at: -1 });

        res.status(200).json(data);
    } catch (error) {
        res.status(500).json({ error: 'Gagal mengambil data emosi.' });
    }
});

// =========== LISTENING HISTORY =========== //

app.post('/api/history', async (req, res) => {
    const { userId, audioUrl, title, artist, imageUrl, durationMs } = req.body;
    if (!userId) return res.status(400).json({ error: 'User ID diperlukan' });

    try {
        const newHistory = await History.create({ userId, audioUrl, title, artist, imageUrl, durationMs });
        res.status(201).json({ message: 'History tersimpan', data: newHistory });
    } catch (error) {
        res.status(500).json({ error: 'Gagal menyimpan riwayat lagu.' });
    }
});

app.get('/api/history/:userId', async (req, res) => {
    try {
        // Ambil 50 pemutaran terakhir
        const data = await History.find({ userId: req.params.userId })
                                  .sort({ playedAt: -1 })
                                  .limit(50);
        res.status(200).json(data);
    } catch (error) {
        res.status(500).json({ error: 'Gagal mengambil riwayat lagu.' });
    }
});

app.get('/', (req, res) => {
    res.json({
        status: 'Famotion backend running',
        port: process.env.PORT || 4000
    });
});

app.listen(process.env.PORT || 4000, () => {
    console.log(`Server berjalan di port ${process.env.PORT}`);
});

