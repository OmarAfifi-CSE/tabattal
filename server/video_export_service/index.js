const express = require('express');
const cors = require('cors');
const multer = require('multer');
const rateLimit = require('express-rate-limit');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { exec } = require('child_process');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 8080;
const isRunningLocally = !process.env.K_SERVICE && !process.env.GOOGLE_CLOUD_PROJECT;

// Logging middleware
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url} - Origin: ${req.headers.origin || 'none'}`);
  next();
});

// 1. CORS Configuration (Handles local dev on any port as well as production domain)
app.use(cors({
  origin: function (origin, callback) {
    if (!origin) return callback(null, true);
    
    // Production Cloud Run check
    if (!isRunningLocally) {
      if (origin.startsWith('https://omar-afifi.com') || origin.startsWith('https://www.omar-afifi.com')) {
        return callback(null, true);
      }
      return callback(new Error('Access denied: Unauthorized origin. Only https://omar-afifi.com is permitted.'));
    }

    // Local machine testing (localhost / 127.0.0.1 on any port)
    return callback(null, true);
  },
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept', 'Origin'],
  credentials: true
}));

app.options('*', cors());

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
app.use(express.json({ limit: '100mb' }));
app.use(express.urlencoded({ extended: true, limit: '100mb' }));

// Configure multer storage for uploaded frame images
const upload = multer({
  dest: path.join(os.tmpdir(), 'tabattal_uploads'),
  limits: { 
    fileSize: 50 * 1024 * 1024, // Max 50MB per frame
    files: 50 // Max 50 overlay units
  }
});

function runCommand(command, cwd) {
  return new Promise((resolve, reject) => {
    exec(command, { cwd, maxBuffer: 10 * 1024 * 1024 }, (error, stdout, stderr) => {
      if (error) {
        console.error(`FFmpeg error: ${stderr || error.message}`);
        return reject(new Error(stderr || error.message));
      }
      resolve(stdout);
    });
  });
}

async function downloadFile(url, destPath) {
  const response = await axios({
    method: 'GET',
    url: url,
    responseType: 'stream',
    timeout: 15000,
  });

  return new Promise((resolve, reject) => {
    const writer = fs.createWriteStream(destPath);
    response.data.pipe(writer);
    writer.on('finish', resolve);
    writer.on('error', reject);
  });
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'tabattal-video-export', 
    domain: 'omar-afifi.com',
    cloud: !isRunningLocally,
    timestamp: new Date().toISOString() 
  });
});

// Secure video export endpoint (Identical to Mobile Native FFmpeg Engine)
app.post('/api/export-video', upload.any(), async (req, res) => {
  const sessionId = `session_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
  const sessionDir = path.join(os.tmpdir(), sessionId);

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
    const crf = parseInt(metadata.crf || 23, 10);

    // Security constraints
    if (surahNumber < 1 || surahNumber > 114) {
      return res.status(400).json({
        code: 'INVALID_SURAH',
        messageAr: 'رقم السورة غير صالح.',
        messageEn: 'Invalid surah number provided.'
      });
    }
    if (unitConfigs.length > 50) {
      return res.status(400).json({
        code: 'EXCEEDED_SEGMENT_LIMIT',
        messageAr: 'عدد مقاطع الفيديو يتجاوز الحد الأقصى المسموح به (50 مقطعًا).',
        messageEn: 'Video segment count exceeds maximum limit (50 segments).'
      });
    }

    // Map uploaded files
    const fileMap = {};
    for (const file of req.files || []) {
      fileMap[file.fieldname] = file.path;
    }

    const baseFrameSrc = fileMap['base_frame'];
    if (!baseFrameSrc || !fs.existsSync(baseFrameSrc)) {
      return res.status(400).json({
        code: 'MISSING_BASE_FRAME',
        messageAr: 'صورة الإطار الأساسي مفقودة.',
        messageEn: 'Base frame image is missing.'
      });
    }

    const baseFrameDest = path.join(sessionDir, 'base_frame.png');
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

    // 1. Parallel Audio Download Promise
    const distinctVerses = [];
    for (let a = startAyah; a <= endAyah; a++) {
      distinctVerses.push(a);
    }

    const audioDownloadPromise = (async () => {
      const results = await Promise.all(distinctVerses.map(async (vNum) => {
        const sStr = String(surahNumber).padStart(3, '0');
        const aStr = String(vNum).padStart(3, '0');
        const audioDest = path.join(sessionDir, `audio_${sStr}_${aStr}.mp3`);
        
        const primaryUrl = `https://everyayah.com/data/${reciterPath}/${sStr}${aStr}.mp3`;
        const fallbackUrl = `https://audio.qurancdn.com/Alafasy/mp3/${sStr}${aStr}.mp3`;

        try {
          await downloadFile(primaryUrl, audioDest);
        } catch (err) {
          console.warn(`Primary audio download failed for ${primaryUrl}, trying fallback...`);
          try {
            await downloadFile(fallbackUrl, audioDest);
          } catch (fbErr) {
            console.error(`Fallback audio download failed for ${fallbackUrl}: ${fbErr.message}`);
          }
        }

        return fs.existsSync(audioDest) ? audioDest : null;
      }));
      return results.filter(Boolean);
    })();

    // 2. Parallel Video Segments Rendering (4 workers concurrency)
    const cpuCount = Math.max(os.cpus()?.length || 2, 2);
    const concurrency = Math.min(cpuCount, 4);

    const segmentRenderPromise = (async () => {
      const segmentPaths = await mapConcurrent(unitConfigs, concurrency, async (unit, u) => {
        const durSec = Math.max(parseFloat(unit.durSec || 4.0), 0.4);

        const overlaySrc = fileMap[`overlay_unit_${u}`];
        if (!overlaySrc || !fs.existsSync(overlaySrc)) {
          throw new Error(`MISSING_OVERLAY_FRAME: Overlay frame for unit ${u + 1} is missing.`);
        }

        const overlayDest = path.join(sessionDir, `overlay_unit_${u}.png`);
        fs.copyFileSync(overlaySrc, overlayDest);

        const segmentFile = path.join(sessionDir, `segment_${u}.ts`);

        // Luxury cross-fade transitions exactly matching Mobile Video Studio
        const fadeDur = 0.30;
        const safeFade = Math.min(Math.max(fadeDur, 0.05), durSec * 0.20);
        const fadeOutStart = Math.min(Math.max(durSec - safeFade, 0.08), durSec);

        const ffmpegCmd = `ffmpeg -y -loop 1 -t ${durSec} -framerate 30 -i "${baseFrameDest}" -loop 1 -t ${durSec} -framerate 30 -i "${overlayDest}" -filter_complex "[1:v]fade=t=in:st=0:d=${safeFade.toFixed(2)}:alpha=1,fade=t=out:st=${fadeOutStart.toFixed(2)}:d=${safeFade.toFixed(2)}:alpha=1[dyn];[0:v][dyn]overlay=0:0[v]" -map "[v]" -c:v libx264 -preset ultrafast -tune stillimage -crf ${crf} -pix_fmt yuv420p -r 30 -threads 2 "${segmentFile}"`;

        await runCommand(ffmpegCmd, sessionDir);
        return segmentFile;
      });
      return segmentPaths;
    })();

    // Run audio download and segment rendering in parallel
    const [validAudioFiles, segmentPaths] = await Promise.all([
      audioDownloadPromise,
      segmentRenderPromise
    ]);

    // 3. Concatenate all video segments into raw_video.mp4 (lossless copy)
    const concatListFile = path.join(sessionDir, 'concat_list.txt');
    const concatContent = segmentPaths.map(p => `file '${path.basename(p)}'`).join('\n');
    fs.writeFileSync(concatListFile, concatContent);

    const rawVideoMp4 = path.join(sessionDir, 'raw_video.mp4');
    const concatCmd = `ffmpeg -y -f concat -safe 0 -i concat_list.txt -c copy "${rawVideoMp4}"`;
    await runCommand(concatCmd, sessionDir);

    if (!fs.existsSync(rawVideoMp4)) {
      return res.status(500).json({
        code: 'FFMPEG_VIDEO_CONCAT_FAILED',
        messageAr: 'فشل في تجميع مقاطع الفيديو.',
        messageEn: 'Failed to concatenate video segments.'
      });
    }

    // 4. Final Mux: Video Track + 100% Continuous Original Audio Stream (Zero AAC padding / Zero stutter)
    const outputMp4 = path.join(sessionDir, `Tabattal_${surahNumber}_${startAyah}-${endAyah}_${Date.now()}.mp4`);

    if (validAudioFiles.length === 0) {
      const copyCmd = `ffmpeg -y -i "${rawVideoMp4}" -c copy -movflags +faststart "${outputMp4}"`;
      await runCommand(copyCmd, sessionDir);
    } else if (validAudioFiles.length === 1) {
      const singleAudio = validAudioFiles[0];
      const muxCmd = `ffmpeg -y -i "${rawVideoMp4}" -i "${singleAudio}" -c:v copy -c:a aac -b:a 192k -movflags +faststart "${outputMp4}"`;
      await runCommand(muxCmd, sessionDir);
    } else {
      const audioConcatFile = path.join(sessionDir, 'audio_segments.txt');
      const audioBuffer = validAudioFiles.map(p => `file '${path.basename(p)}'`).join('\n');
      fs.writeFileSync(audioConcatFile, audioBuffer);

      const muxCmd = `ffmpeg -y -i "${rawVideoMp4}" -f concat -safe 0 -i audio_segments.txt -c:v copy -c:a aac -b:a 192k -movflags +faststart "${outputMp4}"`;
      await runCommand(muxCmd, sessionDir);
    }

    if (!fs.existsSync(outputMp4)) {
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
    // Clean up on error
    try {
      if (fs.existsSync(sessionDir)) fs.rmSync(sessionDir, { recursive: true, force: true });
      for (const file of req.files || []) {
        if (fs.existsSync(file.path)) fs.unlinkSync(file.path);
      }
    } catch (_) {}

    res.status(500).json({ 
      code: 'SERVER_ERROR',
      messageAr: 'حدث خطأ أثناء معالجة الفيديو في السيرفر.',
      messageEn: 'An error occurred while processing the video on the server.',
      details: error.message 
    });
  }
});

const server = app.listen(PORT, () => {
  console.log(`Tabattal Quran Video Export Service running securely on port ${PORT}`);
});

// Configure 10-minute server timeouts for long renders
server.setTimeout(10 * 60 * 1000);
server.keepAliveTimeout = 120000;
server.headersTimeout = 125000;
