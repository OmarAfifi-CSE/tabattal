const express = require('express');
const cors = require('cors');
const multer = require('multer');
const rateLimit = require('express-rate-limit');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawn, spawnSync, execSync } = require('child_process');
const axios = require('axios');
const dns = require('dns');
const { isAllowedOrigin } = require('./cors_policy');

const app = express();
const PORT = process.env.PORT || 8080;
const isRunningLocally = !process.env.K_SERVICE && !process.env.GOOGLE_CLOUD_PROJECT;

// Logging & CORS middleware
app.use((req, res, next) => {
  const origin = req.headers.origin;
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url} - Origin: ${origin || 'none'}`);
  
  if (isAllowedOrigin(origin, { isRunningLocally })) {
    if (origin) {
      res.setHeader('Access-Control-Allow-Origin', origin);
      res.setHeader('Access-Control-Allow-Credentials', 'true');
    }
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With, Accept, Origin');
    res.setHeader('Access-Control-Max-Age', '86400');
  }

  if (req.method === 'OPTIONS') {
    if (isAllowedOrigin(origin, { isRunningLocally })) {
      return res.status(204).end();
    }
    return res.status(403).end();
  }
  next();
});

// 1. CORS Configuration
const corsOptions = {
  origin: function (origin, callback) {
    if (isAllowedOrigin(origin, { isRunningLocally })) {
      return callback(null, true);
    }
    return callback(null, false);
  },
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept', 'Origin'],
  credentials: true
};

app.use(cors(corsOptions));
app.options('*', cors(corsOptions));

// 🔒 Strict Origin & Referer Verification for Export API in Production
app.use('/api/export-video', (req, res, next) => {
  if (isRunningLocally) {
    return next();
  }

  const origin = req.headers.origin;
  const referer = req.headers.referer;
  let effectiveOrigin = origin;
  if (!effectiveOrigin && referer) {
    try {
      effectiveOrigin = new URL(referer).origin;
    } catch (_) {}
  }

  if (!isAllowedOrigin(effectiveOrigin, { allowMissing: false, isRunningLocally: false })) {
    return res.status(403).json({
      code: 'FORBIDDEN_ORIGIN',
      messageAr: 'غير مصرح بالوصول: الخدمة متاحة فقط من خلال نطاقات تطبيق تبتل الرسمية.',
      messageEn: 'Forbidden: Video export service is only accessible from official Tabattal domains.'
    });
  }
  next();
});

// 2. Strict Rate Limiting Protection (Prevents automated abuse with Bilingual Error Message)
const exportLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 minutes
  max: 10, // Max 10 exports per 5 minutes per IP
  standardHeaders: true,
  legacyHeaders: false,
  skip: () => isRunningLocally, // Don't rate limit local development
  handler: (req, res) => {
    res.status(429).json({
      code: 'RATE_LIMIT_EXCEEDED',
      messageAr: 'لقد تجاوزت الحد المسموح به لطلبات التصدير في وقت قصير. يرجى الانتظار بضع دقائق ثم المحاولة مجددًا.',
      messageEn: 'You have exceeded the maximum export limit in a short time. Please wait a few minutes and try again.'
    });
  }
});

app.use('/api/export-video', exportLimiter);
app.use(express.json({ limit: '150mb' }));
app.use(express.urlencoded({ extended: true, limit: '150mb' }));

// Configure multer storage for uploaded frame images and custom background videos
const upload = multer({
  dest: path.join(os.tmpdir(), 'tabattal_uploads'),
  limits: { 
    fileSize: 150 * 1024 * 1024, // Max 150MB per file (supports up to 150MB custom videos)
    files: 165 // Max 165 files (supports 150 overlay units + base frame + custom video + headroom)
  }
});

// Granular Multer error handling middleware with bilingual messages
const handleVideoUpload = (req, res, next) => {
  upload.any()(req, res, (err) => {
    if (err) {
      if (err instanceof multer.MulterError) {
        if (err.code === 'LIMIT_FILE_SIZE') {
          return res.status(413).json({
            code: 'FILE_TOO_LARGE',
            messageAr: 'حجم ملف الفيديو المخصص كبير جدًا (الحد الأقصى المسموح به 150 ميجابايت). يُرجى اختيار فيديو أصغر.',
            messageEn: 'Custom video file is too large (maximum allowed size is 150MB). Please select a smaller video.',
            details: err.message
          });
        }
        if (err.code === 'LIMIT_FILE_COUNT') {
          return res.status(400).json({
            code: 'TOO_MANY_FILES',
            messageAr: 'تجاوز عدد الملفات المرفوعة الحد الأقصى المسموح به.',
            messageEn: 'Uploaded file count exceeds maximum limit.',
            details: err.message
          });
        }
        return res.status(400).json({
          code: 'UPLOAD_ERROR',
          messageAr: 'حدث خطأ أثناء رفع ملفات الفيديو إلى السيرفر.',
          messageEn: 'An error occurred while uploading video files to the server.',
          details: err.message
        });
      }
      return res.status(500).json({
        code: 'UPLOAD_INTERNAL_ERROR',
        messageAr: 'فشل استقبال ملفات التصدير في السيرفر.',
        messageEn: 'Failed to receive export files on the server.',
        details: err.message
      });
    }
    next();
  });
};

const activeJobs = new Map();

// Progress polling endpoint for real-time hardware metrics
app.get('/api/export-progress/:jobId', (req, res) => {
  const jobId = req.params.jobId;
  const job = activeJobs.get(jobId);
  if (!job) {
    return res.json({ status: 'unknown' });
  }
  return res.json({
    status: job.status,
    renderedSec: job.renderedSec,
    totalSec: job.totalSec,
    speed: job.speed,
    progress: job.progress
  });
});

// Cancellation endpoint to terminate FFmpeg process immediately
app.post('/api/cancel-export/:jobId', (req, res) => {
  const jobId = req.params.jobId;
  const job = activeJobs.get(jobId);
  if (job && job.process) {
    try {
      job.process.kill('SIGKILL');
    } catch (_) {}
  }
  activeJobs.delete(jobId);
  return res.json({ status: 'cancelled' });
});

function runFfmpegWithProgress(args, cwd, jobId, totalDurationSec) {
  return new Promise((resolve, reject) => {
    const fullArgs = [...args, '-progress', 'pipe:1'];
    console.log(`[Job ${jobId || 'direct'}] Spawning FFmpeg process: ffmpeg ${fullArgs.slice(0, 10).join(' ')}...`);

    const ffmpegProc = spawn('ffmpeg', fullArgs, { cwd });

    if (jobId) {
      activeJobs.set(jobId, {
        status: 'encoding',
        renderedSec: 0.0,
        totalSec: totalDurationSec,
        speed: null,
        progress: 0.50,
        process: ffmpegProc
      });
    }

    let stderrBuffer = '';
    let stdoutBuffer = '';

    ffmpegProc.stdout.on('data', (chunk) => {
      stdoutBuffer += chunk.toString();
      const lines = stdoutBuffer.split('\n');
      stdoutBuffer = lines.pop();

      let outTimeUs = null;
      let speedStr = null;

      for (const line of lines) {
        const parts = line.trim().split('=');
        if (parts.length === 2) {
          const key = parts[0].trim();
          const value = parts[1].trim();
          if (key === 'out_time_us' || key === 'out_time_ms') {
            outTimeUs = parseInt(value, 10);
          } else if (key === 'speed') {
            speedStr = value;
          }
        }
      }

      if (outTimeUs !== null && !isNaN(outTimeUs) && jobId) {
        const renderedSec = Math.max(0.0, Math.min(totalDurationSec, outTimeUs / 1000000.0));
        let speedNum = null;
        if (speedStr && speedStr.includes('x')) {
          const parsed = parseFloat(speedStr.replace('x', '').trim());
          if (!isNaN(parsed) && parsed > 0.01) {
            speedNum = parsed;
          }
        }

        const percent = totalDurationSec > 0 ? Math.min(1.0, renderedSec / totalDurationSec) : 0.0;
        const progress = 0.50 + (percent * 0.49);

        const currentJob = activeJobs.get(jobId) || {};
        activeJobs.set(jobId, {
          ...currentJob,
          status: 'encoding',
          renderedSec: parseFloat(renderedSec.toFixed(3)),
          totalSec: parseFloat(totalDurationSec.toFixed(3)),
          speed: speedNum,
          progress: parseFloat(progress.toFixed(3))
        });
      }
    });

    ffmpegProc.stderr.on('data', (chunk) => {
      stderrBuffer += chunk.toString();
    });

    ffmpegProc.on('error', (err) => {
      if (jobId) activeJobs.delete(jobId);
      console.error(`FFmpeg spawn error: ${err.message}`);
      reject(err);
    });

    ffmpegProc.on('close', (code) => {
      if (jobId) {
        const currentJob = activeJobs.get(jobId);
        if (currentJob) {
          activeJobs.set(jobId, {
            ...currentJob,
            status: code === 0 ? 'completed' : 'failed',
            renderedSec: totalDurationSec,
            progress: 0.99
          });
        }
      }
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`FFmpeg exited with code ${code}: ${stderrBuffer.slice(-1000)}`));
      }
    });
  });
}

async function downloadFile(url, destPath, options = {}) {
  const { verifyFinalUrl = false, maxRedirects = 5 } = options;
  let currentUrl = url;
  let redirectCount = 0;

  while (true) {
    if (verifyFinalUrl) {
      await assertPublicHttpUrl(currentUrl);
    }

    const response = await axios({
      method: 'GET',
      url: currentUrl,
      responseType: 'stream',
      timeout: 60000,
      maxRedirects: 0,
      validateStatus: (status) => status >= 200 && status < 400,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'video/webm,video/ogg,video/*;q=0.9,audio/*;q=0.8,*/*;q=0.5',
        'Accept-Language': 'en-US,en;q=0.9,ar;q=0.8',
      }
    });

    if (response.status >= 300 && response.status < 400 && response.headers.location) {
      redirectCount++;
      if (redirectCount > maxRedirects) {
        if (response.data && typeof response.data.destroy === 'function') {
          response.data.destroy();
        }
        throw new Error(`Too many redirects (max ${maxRedirects})`);
      }
      if (response.data && typeof response.data.destroy === 'function') {
        response.data.destroy();
      }
      currentUrl = new URL(response.headers.location, currentUrl).toString();
      continue;
    }

    if (response.status < 200 || response.status >= 300) {
      if (response.data && typeof response.data.destroy === 'function') {
        response.data.destroy();
      }
      throw new Error(`HTTP download failed with status ${response.status}`);
    }

    return new Promise((resolve, reject) => {
      const writer = fs.createWriteStream(destPath);
      response.data.pipe(writer);
      writer.on('finish', () => {
        try {
          const stats = fs.statSync(destPath);
          if (stats.size === 0) {
            return reject(new Error('Downloaded file is empty (0 bytes).'));
          }
          resolve();
        } catch (err) {
          reject(err);
        }
      });
      writer.on('error', (err) => {
        try { if (fs.existsSync(destPath)) fs.unlinkSync(destPath); } catch (_) {}
        reject(err);
      });
      response.data.on('error', (err) => {
        try { if (fs.existsSync(destPath)) fs.unlinkSync(destPath); } catch (_) {}
        reject(err);
      });
    });
  }
}

// --- SSRF protection for user-supplied URLs (custom background video) ---
// Only public http(s) destinations are allowed. Literal private IPs are
// rejected outright; hostnames are resolved and EVERY returned address must
// be public (blocks DNS tricks pointing at loopback/LAN).
function isPublicIpv4(parts) {
  if (parts.length !== 4) return false;
  const [a, b, c, d] = parts;
  if ([a, b, c, d].some((n) => !Number.isInteger(n) || n < 0 || n > 255)) return false;
  if (a === 10) return false; // RFC1918
  if (a === 172 && b >= 16 && b <= 31) return false; // RFC1918
  if (a === 192 && b === 168) return false; // RFC1918
  if (a === 127) return false; // loopback
  if (a === 169 && b === 254) return false; // link-local
  if (a === 0) return false; // current network
  if (a >= 224) return false; // multicast + reserved
  if (a === 100 && b >= 64 && b <= 127) return false; // CGNAT
  if (a === 192 && b === 0 && (c === 0 || c === 2)) return false; // special/docs
  if (a === 198 && (b === 18 || b === 19)) return false; // benchmarking
  if (a === 198 && b === 51 && c === 100) return false; // TEST-NET-2
  if (a === 203 && b === 0 && c === 113) return false; // TEST-NET-3
  if (a === 192 && b === 88 && c === 99) return false; // deprecated relay
  return true;
}

function isPublicIpLiteral(host) {
  const h = String(host || '').toLowerCase().replace(/^\[|\]$/g, '');
  if (h === 'localhost') return false;
  // IPv4-mapped IPv6 embeds a v4 address — classify the inner address.
  const mapped = h.match(/^::ffff:(\d+\.\d+\.\d+\.\d+)$/);
  const v4 = mapped ? mapped[1] : h;
  if (/^\d+\.\d+\.\d+\.\d+$/.test(v4)) {
    return isPublicIpv4(v4.split('.').map((n) => parseInt(n, 10)));
  }
  if (h.includes(':')) {
    if (h === '::' || h === '::1') return false; // unspecified / loopback
    const compact = h.replace(/:/g, '');
    if (/^fe[89ab]/i.test(compact)) return false; // fe80::/10 link-local
    if (/^fc/i.test(compact) || /^fd/i.test(compact)) return false; // unique-local
    if (/^ff/i.test(compact)) return false; // multicast
    return true;
  }
  return true; // not an IP literal — caller resolves via DNS
}

async function assertPublicHttpUrl(urlStr) {
  let parsed;
  try {
    parsed = new URL(urlStr);
  } catch (_) {
    throw new Error(`BLOCKED_URL: malformed URL rejected.`);
  }
  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    throw new Error(`BLOCKED_URL: only http(s) destinations are allowed.`);
  }
  const host = parsed.hostname;
  if (!host) {
    throw new Error(`BLOCKED_URL: missing host rejected.`);
  }
  const looksLikeIp = /^\d+\.\d+\.\d+\.\d+$/.test(host) ||
    host.includes(':') ||
    host.toLowerCase() === 'localhost';
  if (looksLikeIp) {
    if (!isPublicIpLiteral(host)) {
      throw new Error(`BLOCKED_URL: internal/reserved destination rejected.`);
    }
    return;
  }
  let records;
  try {
    records = await dns.promises.lookup(host, { all: true, verbatim: true });
  } catch (_) {
    throw new Error(`BLOCKED_URL: hostname could not be resolved.`);
  }
  if (!records || records.length === 0) {
    throw new Error(`BLOCKED_URL: hostname could not be resolved.`);
  }
  for (const r of records) {
    const addr = r.family === 6 ? `[${r.address}]` : r.address;
    if (!isPublicIpLiteral(addr)) {
      throw new Error(`BLOCKED_URL: hostname resolves to an internal address.`);
    }
  }
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'tabattal-video-export', 
    site: 'https://tabattal.omar-afifi.com',
    cloud: !isRunningLocally,
    timestamp: new Date().toISOString() 
  });
});

// Secure video export endpoint (Identical to Mobile Native FFmpeg Engine)
app.post('/api/export-video', handleVideoUpload, async (req, res) => {
  const sessionId = `session_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
  const sessionDir = path.join(os.tmpdir(), sessionId);

  // Centralized session cleanup: defined in outer handler scope so it is always
  // available in try and catch blocks (even if metadata parsing or early validation fails).
  const cleanupSession = () => {
    try {
      if (fs.existsSync(sessionDir)) fs.rmSync(sessionDir, { recursive: true, force: true });
    } catch (_) {}
    try {
      for (const file of req.files || []) {
        if (fs.existsSync(file.path)) fs.unlinkSync(file.path);
      }
    } catch (_) {}
  };

  try {
    fs.mkdirSync(sessionDir, { recursive: true });

    // Parse and validate metadata
    let metadata = {};
    if (req.body.metadata) {
      metadata = typeof req.body.metadata === 'string' ? JSON.parse(req.body.metadata) : req.body.metadata;
    }

    const surahNumber = parseInt(metadata.surahNumber || 1, 10);
    const startAyah = parseInt(metadata.startAyah || 1, 10);
    const endAyah = parseInt(metadata.endAyah || 1, 10);
    const reciterPath = metadata.reciterPath || 'Minshawy_Murattal_128kbps';
    const unitConfigs = metadata.unitConfigs || [];
    const badgeConfigs = Array.isArray(metadata.badgeConfigs) ? metadata.badgeConfigs : [];
    const tafsirConfigs = Array.isArray(metadata.tafsirConfigs) ? metadata.tafsirConfigs : [];
    const crf = Math.min(Math.max(parseInt(metadata.crf || 22, 10), 16), 32);

    // Security constraints
    if (surahNumber < 1 || surahNumber > 114) {
      cleanupSession();
      return res.status(400).json({
        code: 'INVALID_SURAH',
        messageAr: 'رقم السورة غير صالح.',
        messageEn: 'Invalid surah number provided.'
      });
    }
    // Bounded verse range: integers only, ordered, and capped at the same
    // 10-ayah export window the app enforces client-side. Without this, a
    // single request could allocate an unbounded array + Promise.all storm.
    if (!Number.isInteger(startAyah) || !Number.isInteger(endAyah) ||
        startAyah < 1 || endAyah < startAyah || (endAyah - startAyah + 1) > 10) {
      cleanupSession();
      return res.status(400).json({
        code: 'INVALID_RANGE',
        messageAr: 'نطاق الآيات غير صالح (آية بداية ≤ آية نهاية، بحد أقصى 10 آيات).',
        messageEn: 'Invalid ayah range (start <= end, max 10 ayahs per export).'
      });
    }
    // reciterPath is interpolated into download URLs: restrict to safe path
    // characters so it cannot smuggle queries, fragments, or traversals.
    // Forward slashes ARE allowed: audio-translation reciters live in real
    // EveryAyah subfolders (e.g. "English/Sahih_Intnl_Ibrahim_Walk_192kbps",
    // "MultiLanguage/Basfar_Walk_192kbps"), and single dots are needed by
    // real paths like "Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net".
    // The guards still block: traversal (".."), leading/trailing dots at a
    // segment boundary, double slashes, and every character outside
    // [A-Za-z0-9_./-], so constructed URLs remain server-safe.
    if (typeof reciterPath !== 'string' ||
        !/^(?!\/)(?!\.)(?!.*\.\.)(?!.*\/\/)(?!.*\/\.)(?!.*\/$)[A-Za-z0-9_.\-\/]{1,120}$/.test(reciterPath)) {
      cleanupSession();
      return res.status(400).json({
        code: 'INVALID_RECITER',
        messageAr: 'مسار القارئ غير صالح.',
        messageEn: 'Invalid reciter path provided.'
      });
    }
    if (unitConfigs.length > 150) {
      cleanupSession();
      return res.status(400).json({
        code: 'EXCEEDED_SEGMENT_LIMIT',
        messageAr: 'عدد مقاطع الفيديو يتجاوز الحد الأقصى المسموح به (150 مقطعًا). يُرجى اختيار نطاق أصغر أو وضع عرض أبسط.',
        messageEn: 'Video segment count exceeds maximum limit (150 segments). Please choose a smaller range.'
      });
    }

    // Map uploaded files
    const fileMap = {};
    for (const file of req.files || []) {
      fileMap[file.fieldname] = file.path;
    }

    const baseFrameFile = (req.files || []).find(f => f.fieldname === 'base_frame');
    const baseFrameSrc = baseFrameFile ? baseFrameFile.path : fileMap['base_frame'];
    if (!baseFrameSrc || !fs.existsSync(baseFrameSrc)) {
      cleanupSession();
      return res.status(400).json({
        code: 'MISSING_BASE_FRAME',
        messageAr: 'صورة الإطار الأساسي مفقودة.',
        messageEn: 'Base frame image is missing.'
      });
    }

    const baseFrameExt = path.extname(baseFrameFile?.originalname || '.jpg') || '.jpg';
    const baseFrameDest = path.join(sessionDir, `base_frame${baseFrameExt}`);
    fs.copyFileSync(baseFrameSrc, baseFrameDest);

    // Helper for parallel worker concurrency
    async function mapConcurrent(items, concurrency, fn) {
      const results = new Array(items.length);
      let currentIndex = 0;

      async function worker() {
        while (currentIndex < items.length) {
          const index = currentIndex++;
          results[index] = await fn(items[index], index);
        }
      }

      const workers = [];
      const workerCount = Math.min(concurrency, items.length);
      for (let w = 0; w < workerCount; w++) {
        workers.push(worker());
      }
      await Promise.all(workers);
      return results;
    }

    // Helper to measure exact media duration via ffprobe
    function getExactMediaDuration(filePath) {
      try {
        const result = spawnSync('ffprobe', [
          '-v', 'error',
          '-show_entries', 'format=duration',
          '-of', 'default=noprint_wrappers=1:nokey=1',
          filePath
        ], { encoding: 'utf-8' });
        if (result.stdout) {
          const dur = parseFloat(result.stdout.trim());
          if (!isNaN(dur) && dur > 0) return dur;
        }
      } catch (_) {}
      return null;
    }

    function getExactAudioDuration(filePath) {
      return getExactMediaDuration(filePath);
    }

    function getExactVideoDuration(filePath) {
      return getExactMediaDuration(filePath);
    }

    // 1. Download all verse audio files in parallel and measure exact durations
    const distinctVerses = [];
    for (let a = startAyah; a <= endAyah; a++) {
      distinctVerses.push(a);
    }

    const audioMap = {};
    const validAudioFiles = [];

    // Bounded concurrency (not an unbounded Promise.all storm): at most 4
    // simultaneous verse downloads; https URLs here are server-constructed
    // from the validated surah/ayah range, never raw user input.
    await mapConcurrent(distinctVerses, 4, async (vNum) => {
      const sStr = String(surahNumber).padStart(3, '0');
      const aStr = String(vNum).padStart(3, '0');
      const audioDest = path.join(sessionDir, `audio_${sStr}_${aStr}.mp3`);

      const primaryUrl = `https://everyayah.com/data/${reciterPath}/${sStr}${aStr}.mp3`;
      const mirrorUrl = `https://mirrors.quranicaudio.com/everyayah/data/${reciterPath}/${sStr}${aStr}.mp3`;

      try {
        await downloadFile(primaryUrl, audioDest);
      } catch (err) {
        console.warn(`Primary audio download failed for ${primaryUrl}, trying EveryAyah mirror...`);
        try {
          await downloadFile(mirrorUrl, audioDest);
        } catch (fbErr) {
          console.error(`EveryAyah audio download failed for ${reciterPath} [${sStr}:${aStr}]: ${fbErr.message}`);
        }
      }

      if (fs.existsSync(audioDest)) {
        const exactDur = getExactAudioDuration(audioDest);
        audioMap[vNum] = { path: audioDest, duration: exactDur };
      }
    });

    for (const vNum of distinctVerses) {
      if (audioMap[vNum]?.path) {
        validAudioFiles.push(audioMap[vNum].path);
      }
    }

    const hasCustomVideo = Boolean(metadata.hasCustomVideo);
    let backgroundDimming = 0.35;
    if (metadata.backgroundDimming !== undefined && metadata.backgroundDimming !== null && metadata.backgroundDimming !== '') {
      const parsedDimming = parseFloat(metadata.backgroundDimming);
      if (!Number.isNaN(parsedDimming) && Number.isFinite(parsedDimming)) {
        backgroundDimming = Math.min(Math.max(parsedDimming, 0.0), 1.0);
      }
    }
    const targetWidth = parseInt(metadata.targetWidth || 1080, 10);
    const targetHeight = parseInt(metadata.targetHeight || 1920, 10);

    let customVideoDest = null;
    const customVideoFile = (req.files || []).find(f => f.fieldname === 'custom_video');
    const customVideoSrc = customVideoFile ? customVideoFile.path : fileMap['custom_video'];

    if (hasCustomVideo) {
      if (customVideoSrc && fs.existsSync(customVideoSrc)) {
        customVideoDest = path.join(sessionDir, 'custom_video.mp4');
        fs.copyFileSync(customVideoSrc, customVideoDest);
      } else if (metadata.customVideoUrl && (metadata.customVideoUrl.startsWith('http://') || metadata.customVideoUrl.startsWith('https://'))) {
        customVideoDest = path.join(sessionDir, 'custom_video.mp4');
        try {
          await assertPublicHttpUrl(metadata.customVideoUrl);
          await downloadFile(metadata.customVideoUrl, customVideoDest, { verifyFinalUrl: true, maxRedirects: 5 });
        } catch (vErr) {
          console.error(`Custom video download failed from ${metadata.customVideoUrl}: ${vErr.message}`);
          cleanupSession();
          return res.status(400).json({
            code: 'CUSTOM_VIDEO_DOWNLOAD_FAILED',
            messageAr: 'تعذر تنزيل ملف الفيديو المخصص من الرابط المحدد. يرجى التأكد من صلاحية الرابط والمحاولة مجددًا.',
            messageEn: 'Failed to download custom background video from the provided URL. Please verify the link and try again.'
          });
        }
      }
    }

    const customVideoDuration = (customVideoDest && fs.existsSync(customVideoDest))
      ? (getExactVideoDuration(customVideoDest) || 10.0)
      : 10.0;

    // 2. Auto-Calibrate Unit Durations: Match each verse's video units to the exact audio duration
    const unitsByVerse = {};
    unitConfigs.forEach((unit, idx) => {
      const vNum = parseInt(unit.verseNumber || (startAyah + (parseInt(unit.verseIndex || 0, 10))), 10);
      if (!unitsByVerse[vNum]) unitsByVerse[vNum] = [];
      unitsByVerse[vNum].push({ unit, idx });
    });

    for (const [vNumStr, group] of Object.entries(unitsByVerse)) {
      const vNum = parseInt(vNumStr, 10);
      const realDur = audioMap[vNum]?.duration;
      if (!realDur || realDur <= 0) {
        throw new Error(`MISSING_AUDIO_DURATION: تعذر قياس المدة الصوتية الدقيقة للآية ${vNum}`);
      }
      const currentSum = group.reduce((sum, g) => {
        const d = parseFloat(g.unit.durSec);
        if (isNaN(d) || d <= 0) {
          throw new Error(`INVALID_UNIT_DURATION: مدة المقطع غير صالحة للآية ${vNum}`);
        }
        return sum + d;
      }, 0);

      if (currentSum > 0) {
        const ratio = realDur / currentSum;
        for (const g of group) {
          g.unit.durSec = (parseFloat(g.unit.durSec) * ratio).toFixed(3);
        }
      }
    }

    let cumulativeStartSec = 0;
    for (let u = 0; u < unitConfigs.length; u++) {
      unitConfigs[u].globalStartSec = cumulativeStartSec;
      const d = parseFloat(unitConfigs[u].durSec);
      if (isNaN(d) || d <= 0) {
        throw new Error(`INVALID_UNIT_DURATION: مدة السطر ${u + 1} غير صالحة`);
      }
      cumulativeStartSec += d;
    }

    // Re-synchronize badgeConfigs and tafsirConfigs with audio-adjusted verse boundaries
    const verseStartMap = {};
    const verseDurMap = {};
    for (const [vNumStr, group] of Object.entries(unitsByVerse)) {
      if (group.length > 0) {
        const firstUnit = group[0].unit;
        const totalVDur = group.reduce((sum, g) => sum + parseFloat(g.unit.durSec), 0);
        verseStartMap[vNumStr] = firstUnit.globalStartSec;
        verseDurMap[vNumStr] = totalVDur;
      }
    }

    for (const badge of badgeConfigs) {
      const vNum = badge.verseNumber || (startAyah + (badge.verseIndex || 0));
      if (verseStartMap[vNum] !== undefined) {
        badge.startSec = verseStartMap[vNum];
        badge.durSec = verseDurMap[vNum];
      }
    }

    for (const tafsir of tafsirConfigs) {
      const vNum = tafsir.verseNumber || (startAyah + (tafsir.verseIndex || 0));
      if (verseStartMap[vNum] !== undefined) {
        tafsir.startSec = verseStartMap[vNum];
        tafsir.durSec = verseDurMap[vNum];
      }
    }

    // 3. Ultra-fast Single-Pass Video Rendering & Direct Muxing
    const cpuCount = process.env.FFMPEG_THREADS
      ? parseInt(process.env.FFMPEG_THREADS, 10)
      : Math.min(Math.max(os.cpus()?.length || 4, 2), 8);
    const outputMp4 = path.join(sessionDir, `Tabattal_${surahNumber}_${startAyah}-${endAyah}_${Date.now()}.mp4`);
    const ffmpegArgs = ['-y'];
    const filterChains = [];
    const isCustom = customVideoDest && fs.existsSync(customVideoDest);

    if (isCustom) {
      ffmpegArgs.push('-stream_loop', '-1', '-i', customVideoDest);
      ffmpegArgs.push('-loop', '1', '-t', cumulativeStartSec.toFixed(3), '-framerate', '30', '-i', baseFrameDest);

      for (let b = 0; b < badgeConfigs.length; b++) {
        const badgeSrc = fileMap[`badge_unit_${b}`];
        if (!badgeSrc || !fs.existsSync(badgeSrc)) {
          throw new Error(`MISSING_BADGE_FRAME: Badge frame for unit ${b + 1} is missing.`);
        }
        const badgeDest = path.join(sessionDir, `badge_unit_${b}.png`);
        fs.copyFileSync(badgeSrc, badgeDest);
        const durSec = parseFloat(badgeConfigs[b].durSec);
        ffmpegArgs.push('-loop', '1', '-t', durSec.toFixed(3), '-framerate', '30', '-i', badgeDest);
      }

      for (let t = 0; t < tafsirConfigs.length; t++) {
        const tafsirSrc = fileMap[`tafsir_unit_${t}`];
        if (!tafsirSrc || !fs.existsSync(tafsirSrc)) {
          throw new Error(`MISSING_TAFSIR_FRAME: Tafsir frame for unit ${t + 1} is missing.`);
        }
        const tafsirDest = path.join(sessionDir, `tafsir_unit_${t}.png`);
        fs.copyFileSync(tafsirSrc, tafsirDest);
        const durSec = parseFloat(tafsirConfigs[t].durSec);
        ffmpegArgs.push('-loop', '1', '-t', durSec.toFixed(3), '-framerate', '30', '-i', tafsirDest);
      }

      for (let u = 0; u < unitConfigs.length; u++) {
        const overlaySrc = fileMap[`overlay_unit_${u}`];
        if (!overlaySrc || !fs.existsSync(overlaySrc)) {
          throw new Error(`MISSING_OVERLAY_FRAME: Overlay frame for unit ${u + 1} is missing.`);
        }
        const overlayDest = path.join(sessionDir, `overlay_unit_${u}.png`);
        fs.copyFileSync(overlaySrc, overlayDest);
        const durSec = parseFloat(unitConfigs[u].durSec);
        ffmpegArgs.push('-loop', '1', '-t', durSec.toFixed(3), '-framerate', '30', '-i', overlayDest);
      }

      filterChains.push(`[0:v]setpts=PTS-STARTPTS,scale=${targetWidth}:${targetHeight}:force_original_aspect_ratio=increase,crop=${targetWidth}:${targetHeight},setsar=1,format=yuv420p,drawbox=color=black@${backgroundDimming.toFixed(2)}:t=fill[bg]`);
      filterChains.push(`[bg][1:v]overlay=0:0[canvas0]`);
      let currentCanvas = 'canvas0';

      for (let b = 0; b < badgeConfigs.length; b++) {
        const bStart = parseFloat(badgeConfigs[b].startSec);
        const bDur = parseFloat(badgeConfigs[b].durSec);
        const bEnd = (b === badgeConfigs.length - 1) ? (bStart + bDur) : (bStart + bDur - 0.001);
        const nextBadgeCanvas = `canvas_b${b + 1}`;
        filterChains.push(`[${currentCanvas}][${b + 2}:v]overlay=0:0:enable='between(t,${bStart.toFixed(3)},${bEnd.toFixed(3)})'[${nextBadgeCanvas}]`);
        currentCanvas = nextBadgeCanvas;
      }

      for (let t = 0; t < tafsirConfigs.length; t++) {
        const tStart = parseFloat(tafsirConfigs[t].startSec);
        const tDur = parseFloat(tafsirConfigs[t].durSec);
        const fadeDur = 0.30;
        const safeFade = Math.max(0.01, Math.min(fadeDur, tDur * 0.20));
        const fadeOutStart = Math.max(0.0, tDur - safeFade);
        const nextTafsirCanvas = `canvas_tf${t + 1}`;
        const rawCropY = parseInt(tafsirConfigs[t].cropY, 10);
        const cropY = isNaN(rawCropY) || rawCropY < 0 ? 0 : rawCropY;
        const inputIdx = 2 + badgeConfigs.length + t;

        filterChains.push(`[${inputIdx}:v]fade=t=in:st=0:d=${safeFade.toFixed(2)}:alpha=1,fade=t=out:st=${fadeOutStart.toFixed(2)}:d=${safeFade.toFixed(2)}:alpha=1,setpts=PTS-STARTPTS+${tStart.toFixed(3)}/TB[ov_tf${t}]`);
        filterChains.push(`[${currentCanvas}][ov_tf${t}]overlay=0:${cropY}:enable='between(t,${tStart.toFixed(3)},${(tStart + tDur).toFixed(3)})'[${nextTafsirCanvas}]`);
        currentCanvas = nextTafsirCanvas;
      }

      for (let u = 0; u < unitConfigs.length; u++) {
        const segStart = unitConfigs[u].globalStartSec;
        const durSec = parseFloat(unitConfigs[u].durSec);
        const segEnd = segStart + durSec;
        const fadeDur = 0.30;
        const safeFade = Math.max(0.01, Math.min(fadeDur, durSec * 0.20));
        const fadeOutStart = Math.max(0.0, durSec - safeFade);
        const nextCanvas = (u === unitConfigs.length - 1) ? 'v' : `canvas_t${u + 1}`;
        const rawCropY = parseInt(unitConfigs[u].cropY, 10);
        const cropY = isNaN(rawCropY) || rawCropY < 0 ? 0 : rawCropY;
        const inputIdx = 2 + badgeConfigs.length + tafsirConfigs.length + u;

        filterChains.push(`[${inputIdx}:v]fade=t=in:st=0:d=${safeFade.toFixed(2)}:alpha=1,fade=t=out:st=${fadeOutStart.toFixed(2)}:d=${safeFade.toFixed(2)}:alpha=1,setpts=PTS-STARTPTS+${segStart.toFixed(3)}/TB[ov${u}]`);
        filterChains.push(`[${currentCanvas}][ov${u}]overlay=0:${cropY}:enable='between(t,${segStart.toFixed(3)},${segEnd.toFixed(3)})'[${nextCanvas}]`);
        currentCanvas = nextCanvas;
      }
    } else {
      ffmpegArgs.push('-loop', '1', '-t', cumulativeStartSec.toFixed(3), '-framerate', '30', '-i', baseFrameDest);

      for (let b = 0; b < badgeConfigs.length; b++) {
        const badgeSrc = fileMap[`badge_unit_${b}`];
        if (!badgeSrc || !fs.existsSync(badgeSrc)) {
          throw new Error(`MISSING_BADGE_FRAME: Badge frame for unit ${b + 1} is missing.`);
        }
        const badgeDest = path.join(sessionDir, `badge_unit_${b}.png`);
        fs.copyFileSync(badgeSrc, badgeDest);
        const durSec = parseFloat(badgeConfigs[b].durSec);
        ffmpegArgs.push('-loop', '1', '-t', durSec.toFixed(3), '-framerate', '30', '-i', badgeDest);
      }

      for (let t = 0; t < tafsirConfigs.length; t++) {
        const tafsirSrc = fileMap[`tafsir_unit_${t}`];
        if (!tafsirSrc || !fs.existsSync(tafsirSrc)) {
          throw new Error(`MISSING_TAFSIR_FRAME: Tafsir frame for unit ${t + 1} is missing.`);
        }
        const tafsirDest = path.join(sessionDir, `tafsir_unit_${t}.png`);
        fs.copyFileSync(tafsirSrc, tafsirDest);
        const durSec = parseFloat(tafsirConfigs[t].durSec);
        ffmpegArgs.push('-loop', '1', '-t', durSec.toFixed(3), '-framerate', '30', '-i', tafsirDest);
      }

      for (let u = 0; u < unitConfigs.length; u++) {
        const overlaySrc = fileMap[`overlay_unit_${u}`];
        if (!overlaySrc || !fs.existsSync(overlaySrc)) {
          throw new Error(`MISSING_OVERLAY_FRAME: Overlay frame for unit ${u + 1} is missing.`);
        }
        const overlayDest = path.join(sessionDir, `overlay_unit_${u}.png`);
        fs.copyFileSync(overlaySrc, overlayDest);
        const durSec = parseFloat(unitConfigs[u].durSec);
        ffmpegArgs.push('-loop', '1', '-t', durSec.toFixed(3), '-framerate', '30', '-i', overlayDest);
      }

      let currentCanvas = '0:v';
      for (let b = 0; b < badgeConfigs.length; b++) {
        const bStart = parseFloat(badgeConfigs[b].startSec);
        const bDur = parseFloat(badgeConfigs[b].durSec);
        const bEnd = (b === badgeConfigs.length - 1) ? (bStart + bDur) : (bStart + bDur - 0.001);
        const nextBadgeCanvas = `canvas_b${b + 1}`;
        filterChains.push(`[${currentCanvas}][${b + 1}:v]overlay=0:0:enable='between(t,${bStart.toFixed(3)},${bEnd.toFixed(3)})'[${nextBadgeCanvas}]`);
        currentCanvas = nextBadgeCanvas;
      }

      for (let t = 0; t < tafsirConfigs.length; t++) {
        const tStart = parseFloat(tafsirConfigs[t].startSec);
        const tDur = parseFloat(tafsirConfigs[t].durSec);
        const fadeDur = 0.30;
        const safeFade = Math.max(0.01, Math.min(fadeDur, tDur * 0.20));
        const fadeOutStart = Math.max(0.0, tDur - safeFade);
        const nextTafsirCanvas = `canvas_tf${t + 1}`;
        const rawCropY = parseInt(tafsirConfigs[t].cropY, 10);
        const cropY = isNaN(rawCropY) || rawCropY < 0 ? 0 : rawCropY;
        const inputIdx = 1 + badgeConfigs.length + t;

        filterChains.push(`[${inputIdx}:v]fade=t=in:st=0:d=${safeFade.toFixed(2)}:alpha=1,fade=t=out:st=${fadeOutStart.toFixed(2)}:d=${safeFade.toFixed(2)}:alpha=1,setpts=PTS-STARTPTS+${tStart.toFixed(3)}/TB[ov_tf${t}]`);
        filterChains.push(`[${currentCanvas}][ov_tf${t}]overlay=0:${cropY}:enable='between(t,${tStart.toFixed(3)},${(tStart + tDur).toFixed(3)})'[${nextTafsirCanvas}]`);
        currentCanvas = nextTafsirCanvas;
      }

      for (let u = 0; u < unitConfigs.length; u++) {
        const segStart = unitConfigs[u].globalStartSec;
        const durSec = parseFloat(unitConfigs[u].durSec);
        const segEnd = segStart + durSec;
        const fadeDur = 0.30;
        const safeFade = Math.max(0.01, Math.min(fadeDur, durSec * 0.20));
        const fadeOutStart = Math.max(0.0, durSec - safeFade);
        const nextCanvas = (u === unitConfigs.length - 1) ? 'v' : `canvas_t${u + 1}`;
        const rawCropY = parseInt(unitConfigs[u].cropY, 10);
        const cropY = isNaN(rawCropY) || rawCropY < 0 ? 0 : rawCropY;
        const inputIdx = 1 + badgeConfigs.length + tafsirConfigs.length + u;

        filterChains.push(`[${inputIdx}:v]fade=t=in:st=0:d=${safeFade.toFixed(2)}:alpha=1,fade=t=out:st=${fadeOutStart.toFixed(2)}:d=${safeFade.toFixed(2)}:alpha=1,setpts=PTS-STARTPTS+${segStart.toFixed(3)}/TB[ov${u}]`);
        filterChains.push(`[${currentCanvas}][ov${u}]overlay=0:${cropY}:enable='between(t,${segStart.toFixed(3)},${segEnd.toFixed(3)})'[${nextCanvas}]`);
        currentCanvas = nextCanvas;
      }
    }

    // Audio Input Integration
    const hasAudio = validAudioFiles.length > 0;
    const audioInputIndex = isCustom
      ? unitConfigs.length + badgeConfigs.length + tafsirConfigs.length + 2
      : unitConfigs.length + badgeConfigs.length + tafsirConfigs.length + 1;
    if (hasAudio) {
      if (validAudioFiles.length === 1) {
        ffmpegArgs.push('-i', validAudioFiles[0]);
      } else {
        const audioConcatFile = path.join(sessionDir, 'audio_segments.txt');
        const audioBuffer = validAudioFiles.map(p => `file '${path.basename(p)}'`).join('\n');
        fs.writeFileSync(audioConcatFile, audioBuffer, 'utf-8');
        ffmpegArgs.push('-f', 'concat', '-safe', '0', '-i', 'audio_segments.txt');
      }
    }

    // MP3 in MP4 container is rejected by Apple AVFoundation (iOS/macOS).
    // Only native AAC (.m4a/.aac) can be safely stream-copied; MP3 must be encoded to AAC.
    const isCopySafeAudio = validAudioFiles.every(p => {
      const lower = p.toLowerCase();
      return lower.endsWith('.m4a') || lower.endsWith('.aac');
    });

    const filter = filterChains.join(';\n');
    const filterScriptPath = path.join(sessionDir, 'filter_graph.txt');
    fs.writeFileSync(filterScriptPath, filter, 'utf-8');

    ffmpegArgs.push('-filter_complex_script', filterScriptPath);
    ffmpegArgs.push('-map', '[v]');

    if (hasAudio) {
      ffmpegArgs.push('-map', `${audioInputIndex}:a`);
      if (isCopySafeAudio) {
        ffmpegArgs.push('-c:a', 'copy');
      } else {
        ffmpegArgs.push('-c:a', 'aac', '-b:a', '192k', '-ar', '44100');
      }
      ffmpegArgs.push('-shortest');
    }

    ffmpegArgs.push(
      '-t', cumulativeStartSec.toFixed(3),
      '-c:v', 'libx264',
      '-preset', 'ultrafast'
    );
    if (!isCustom) {
      ffmpegArgs.push('-tune', 'stillimage');
    }
    ffmpegArgs.push(
      '-crf', crf.toString(),
      '-pix_fmt', 'yuv420p',
      '-r', '30',
      '-threads', cpuCount.toString(),
      '-movflags', '+faststart',
      outputMp4
    );

    const jobId = req.body.jobId || metadata.jobId || req.query.jobId || 'job_' + Date.now();
    await runFfmpegWithProgress(ffmpegArgs, sessionDir, jobId, cumulativeStartSec);

    if (!fs.existsSync(outputMp4)) {
      if (jobId) activeJobs.delete(jobId);
      cleanupSession();
      return res.status(500).json({
        code: 'FFMPEG_OUTPUT_MISSING',
        messageAr: 'فشل في تجميع ملف الفيديو النهائي.',
        messageEn: 'Failed to generate final MP4 video.'
      });
    }

    // Send the MP4 file
    const outputFilename = path.basename(outputMp4);
    res.setHeader('Content-Type', 'video/mp4');
    res.setHeader('Content-Disposition', `attachment; filename="${outputFilename}"`);

    const fileStream = fs.createReadStream(outputMp4);
    fileStream.pipe(res);

    fileStream.on('close', () => {
      if (jobId) activeJobs.delete(jobId);
      // Clean up temp directories
      try {
        fs.rmSync(sessionDir, { recursive: true, force: true });
        for (const file of req.files || []) {
          if (fs.existsSync(file.path)) fs.unlinkSync(file.path);
        }
      } catch (_) {}
    });

  } catch (error) {
    console.error(`Export video error: ${error.message}`);
    // Centralized cleanup covers validation failures, download failures, and
    // ffmpeg errors alike. (The success path keeps files until the response
    // stream closes — see the fileStream 'close' handler above.)
    cleanupSession();

    if (!res.headersSent) {
      res.status(500).json({ 
        code: 'SERVER_ERROR',
        messageAr: 'حدث خطأ أثناء معالجة الفيديو في السيرفر.',
        messageEn: 'An error occurred while processing the video on the server.',
        details: error.message 
      });
    }
  }
});

const server = app.listen(PORT, () => {
  console.log(`Tabattal Quran Video Export Service running securely on port ${PORT}`);
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.log(`[Tabattal] Port ${PORT} is already in use by another instance. Video Export Service is ready.`);
    process.exit(0);
  } else {
    console.error('[Tabattal] Server error:', err);
  }
});

// Configure 15-minute server timeouts for large uploads on slow connections and long renders
server.setTimeout(15 * 60 * 1000);
server.requestTimeout = 15 * 60 * 1000;
server.keepAliveTimeout = 120000;
server.headersTimeout = 125000;

