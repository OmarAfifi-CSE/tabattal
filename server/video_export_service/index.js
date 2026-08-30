const express = require('express');
const cors = require('cors');
const multer = require('multer');
const rateLimit = require('express-rate-limit');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { exec, execSync } = require('child_process');
const axios = require('axios');
const { isAllowedOrigin } = require('./cors_policy');

const app = express();
const PORT = process.env.PORT || 8080;
const isRunningLocally = !process.env.K_SERVICE && !process.env.GOOGLE_CLOUD_PROJECT;

// Logging middleware
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url} - Origin: ${req.headers.origin || 'none'}`);
  next();
});

// 1. CORS Configuration (exact production origins only)
const corsOptions = {
  origin: function (origin, callback) {
    // In local dev allow all origins
    if (isRunningLocally) {
      return callback(null, true);
    }

    if (isAllowedOrigin(origin)) {
      return callback(null, true);
    }

    return callback(new Error('Access denied: Unauthorized origin. Only official Tabattal domains are permitted.'));
  },
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept', 'Origin'],
  credentials: true
};

app.use(cors(corsOptions));
app.options('*', cors(corsOptions));

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
    timeout: 60000,
    maxRedirects: 10,
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Accept': 'video/webm,video/ogg,video/*;q=0.9,audio/*;q=0.8,*/*;q=0.5',
      'Accept-Language': 'en-US,en;q=0.9,ar;q=0.8',
    }
  });

  return new Promise((resolve, reject) => {
    const writer = fs.createWriteStream(destPath);
    response.data.pipe(writer);
    writer.on('finish', () => {
      // Validate that file actually contains data
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
    writer.on('error', reject);
  });
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
    const crf = Math.min(Math.max(parseInt(metadata.crf || 22, 10), 16), 32);

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

    const baseFrameFile = (req.files || []).find(f => f.fieldname === 'base_frame');
    const baseFrameSrc = baseFrameFile ? baseFrameFile.path : fileMap['base_frame'];
    if (!baseFrameSrc || !fs.existsSync(baseFrameSrc)) {
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
        const stdout = execSync(`ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "${filePath}"`, { encoding: 'utf-8' });
        const dur = parseFloat(stdout.trim());
        if (!isNaN(dur) && dur > 0) return dur;
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

    await Promise.all(distinctVerses.map(async (vNum) => {
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

      if (fs.existsSync(audioDest)) {
        const exactDur = getExactAudioDuration(audioDest);
        audioMap[vNum] = { path: audioDest, duration: exactDur };
      }
    }));

    for (const vNum of distinctVerses) {
      if (audioMap[vNum]?.path) {
        validAudioFiles.push(audioMap[vNum].path);
      }
    }

    const hasCustomVideo = Boolean(metadata.hasCustomVideo);
    const backgroundDimming = parseFloat(metadata.backgroundDimming || 0.35);
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
          await downloadFile(metadata.customVideoUrl, customVideoDest);
        } catch (vErr) {
          console.error(`Custom video download failed from ${metadata.customVideoUrl}: ${vErr.message}`);
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

    // 3. Ultra-fast Single-Pass Video Rendering & Direct Muxing
    const cpuCount = Math.max(os.cpus()?.length || 2, 2);
    const outputMp4 = path.join(sessionDir, `Tabattal_${surahNumber}_${startAyah}-${endAyah}_${Date.now()}.mp4`);
    const inputs = [];
    const filterChains = [];
    const isCustom = customVideoDest && fs.existsSync(customVideoDest);

    if (isCustom) {
      inputs.push(`-stream_loop -1 -t ${cumulativeStartSec.toFixed(3)} -i "${customVideoDest}"`);
      inputs.push(`-loop 1 -t ${cumulativeStartSec.toFixed(3)} -framerate 25 -i "${baseFrameDest}"`);

      for (let u = 0; u < unitConfigs.length; u++) {
        const overlaySrc = fileMap[`overlay_unit_${u}`];
        if (!overlaySrc || !fs.existsSync(overlaySrc)) {
          throw new Error(`MISSING_OVERLAY_FRAME: Overlay frame for unit ${u + 1} is missing.`);
        }
        const overlayDest = path.join(sessionDir, `overlay_unit_${u}.png`);
        fs.copyFileSync(overlaySrc, overlayDest);
        const durSec = parseFloat(unitConfigs[u].durSec);
        inputs.push(`-loop 1 -t ${durSec.toFixed(3)} -framerate 25 -i "${overlayDest}"`);
      }

      filterChains.push(`[0:v]setpts=PTS-STARTPTS,scale=${targetWidth}:${targetHeight}:force_original_aspect_ratio=increase,crop=${targetWidth}:${targetHeight},setsar=1,drawbox=color=black@${backgroundDimming.toFixed(2)}:t=fill[bg]`);
      filterChains.push(`[bg][1:v]overlay=0:0[canvas0]`);
      let currentCanvas = 'canvas0';

      for (let u = 0; u < unitConfigs.length; u++) {
        const segStart = unitConfigs[u].globalStartSec;
        const durSec = parseFloat(unitConfigs[u].durSec);
        const segEnd = segStart + durSec;
        const fadeDur = 0.30;
        const safeFade = Math.min(Math.max(fadeDur, 0.05), durSec * 0.20);
        const fadeOutStart = Math.min(Math.max(durSec - safeFade, 0.08), durSec);
        const nextCanvas = (u === unitConfigs.length - 1) ? 'v' : `canvas${u + 1}`;
        const cropY = Math.max(0, parseInt(unitConfigs[u].cropY || 0, 10));

        filterChains.push(`[${u + 2}:v]fade=t=in:st=0:d=${safeFade.toFixed(2)}:alpha=1,fade=t=out:st=${fadeOutStart.toFixed(2)}:d=${safeFade.toFixed(2)}:alpha=1,setpts=PTS-STARTPTS+${segStart.toFixed(3)}/TB[ov${u}]`);
        filterChains.push(`[${currentCanvas}][ov${u}]overlay=0:${cropY}:enable='between(t,${segStart.toFixed(3)},${segEnd.toFixed(3)})'[${nextCanvas}]`);
        currentCanvas = nextCanvas;
      }
    } else {
      inputs.push(`-loop 1 -t ${cumulativeStartSec.toFixed(3)} -framerate 25 -i "${baseFrameDest}"`);

      for (let u = 0; u < unitConfigs.length; u++) {
        const overlaySrc = fileMap[`overlay_unit_${u}`];
        if (!overlaySrc || !fs.existsSync(overlaySrc)) {
          throw new Error(`MISSING_OVERLAY_FRAME: Overlay frame for unit ${u + 1} is missing.`);
        }
        const overlayDest = path.join(sessionDir, `overlay_unit_${u}.png`);
        fs.copyFileSync(overlaySrc, overlayDest);
        const durSec = parseFloat(unitConfigs[u].durSec);
        inputs.push(`-loop 1 -t ${durSec.toFixed(3)} -framerate 25 -i "${overlayDest}"`);
      }

      let currentCanvas = '0:v';
      for (let u = 0; u < unitConfigs.length; u++) {
        const segStart = unitConfigs[u].globalStartSec;
        const durSec = parseFloat(unitConfigs[u].durSec);
        const segEnd = segStart + durSec;
        const fadeDur = 0.30;
        const safeFade = Math.min(Math.max(fadeDur, 0.05), durSec * 0.20);
        const fadeOutStart = Math.min(Math.max(durSec - safeFade, 0.08), durSec);
        const nextCanvas = (u === unitConfigs.length - 1) ? 'v' : `canvas${u + 1}`;
        const cropY = Math.max(0, parseInt(unitConfigs[u].cropY || 0, 10));

        filterChains.push(`[${u + 1}:v]fade=t=in:st=0:d=${safeFade.toFixed(2)}:alpha=1,fade=t=out:st=${fadeOutStart.toFixed(2)}:d=${safeFade.toFixed(2)}:alpha=1,setpts=PTS-STARTPTS+${segStart.toFixed(3)}/TB[ov${u}]`);
        filterChains.push(`[${currentCanvas}][ov${u}]overlay=0:${cropY}:enable='between(t,${segStart.toFixed(3)},${segEnd.toFixed(3)})'[${nextCanvas}]`);
        currentCanvas = nextCanvas;
      }
    }

    // Audio Input Integration
    const hasAudio = validAudioFiles.length > 0;
    const audioInputIndex = isCustom ? unitConfigs.length + 2 : unitConfigs.length + 1;
    if (hasAudio) {
      if (validAudioFiles.length === 1) {
        inputs.push(`-i "${validAudioFiles[0]}"`);
      } else {
        const audioConcatFile = path.join(sessionDir, 'audio_segments.txt');
        const audioBuffer = validAudioFiles.map(p => `file '${path.basename(p)}'`).join('\n');
        fs.writeFileSync(audioConcatFile, audioBuffer);
        inputs.push(`-f concat -safe 0 -i audio_segments.txt`);
      }
    }

    const isCopySafeAudio = validAudioFiles.every(p => {
      const lower = p.toLowerCase();
      return lower.endsWith('.mp3') || lower.endsWith('.m4a') || lower.endsWith('.aac');
    });
    const audioCodecArg = isCopySafeAudio ? '-c:a copy' : '-c:a aac -b:a 128k';
    const audioMapArg = hasAudio ? `-map ${audioInputIndex}:a ${audioCodecArg} -shortest` : '';
    const preset = isCustom ? '-preset ultrafast' : '-preset ultrafast -tune stillimage';
    const filter = filterChains.join(';');

    const ffmpegSinglePassCmd = `ffmpeg -y ${inputs.join(' ')} -filter_complex "${filter}" -map "[v]" ${audioMapArg} -t ${cumulativeStartSec.toFixed(3)} -c:v libx264 ${preset} -crf ${crf} -pix_fmt yuv420p -r 25 -threads ${cpuCount} -movflags +faststart "${outputMp4}"`;
    await runCommand(ffmpegSinglePassCmd, sessionDir);

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

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.log(`[Tabattal] Port ${PORT} is already in use by another instance. Video Export Service is ready.`);
    process.exit(0);
  } else {
    console.error('[Tabattal] Server error:', err);
  }
});

// Configure 10-minute server timeouts for long renders
server.setTimeout(10 * 60 * 1000);
server.keepAliveTimeout = 120000;
server.headersTimeout = 125000;

