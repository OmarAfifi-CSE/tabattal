import 'dart:io';
import 'dart:typed_data';

/// High-performance, zero-dependency pure Dart parser for extracting exact
/// durations from MP3 audio files on all platforms.
///
/// Bypasses native audio engine instantiation completely, eliminating WinRT/OS
/// thread-contention and use-after-free access violations during rapid probing.
class Mp3DurationParser {
  static const List<int> _bitratesMpeg1L3 = [
    0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0,
  ];

  static const List<int> _bitratesMpeg2L3 = [
    0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0,
  ];

  static const List<int> _sampleRatesMpeg1 = [44100, 48000, 32000];
  static const List<int> _sampleRatesMpeg2 = [22050, 24000, 16000];
  static const List<int> _sampleRatesMpeg25 = [11025, 12000, 8000];

  /// Parses the exact or high-precision estimated duration of a local MP3 file.
  /// Returns `null` if the file is invalid or not an MP3.
  static Duration? parse(File file) {
    try {
      if (!file.existsSync()) return null;
      final fileLength = file.lengthSync();
      if (fileLength < 128) return null;

      final raf = file.openSync(mode: FileMode.read);
      try {
        // Read the first 8 KB to resolve ID3v2 tags and the first MPEG audio frame
        final initialReadLen = fileLength < 8192 ? fileLength : 8192;
        final headerBytes = Uint8List(initialReadLen);
        raf.readIntoSync(headerBytes);

        int id3v2Size = 0;

        // 1. Detect and calculate ID3v2 tag size
        if (headerBytes.length >= 10 &&
            headerBytes[0] == 0x49 && // 'I'
            headerBytes[1] == 0x44 && // 'D'
            headerBytes[2] == 0x33) { // '3'
          final flags = headerBytes[5];
          final hasFooter = (flags & 0x10) != 0;
          // Synchsafe integer (7 bits per byte)
          final s0 = headerBytes[6] & 0x7F;
          final s1 = headerBytes[7] & 0x7F;
          final s2 = headerBytes[8] & 0x7F;
          final s3 = headerBytes[9] & 0x7F;
          final tagDataSize = (s0 << 21) | (s1 << 14) | (s2 << 7) | s3;
          id3v2Size = 10 + tagDataSize + (hasFooter ? 10 : 0);
        }

        // Prepare search buffer starting at the end of ID3v2 tag
        Uint8List searchBuffer;
        int searchBaseOffset;
        if (id3v2Size + 1024 > headerBytes.length && id3v2Size < fileLength) {
          raf.setPositionSync(id3v2Size);
          final remaining = fileLength - id3v2Size;
          final readLen = remaining < 4096 ? remaining : 4096;
          searchBuffer = Uint8List(readLen);
          raf.readIntoSync(searchBuffer);
          searchBaseOffset = 0;
        } else {
          searchBuffer = headerBytes;
          searchBaseOffset = id3v2Size;
        }

        // 2. Scan for first valid MPEG frame sync (11 sync bits: 0xFF + 0xE0)
        int frameStart = -1;
        int mpegVersion = 0;
        int bitrate = 0;
        int sampleRate = 0;
        int channelMode = 0;
        int samplesPerFrame = 1152;

        for (int i = searchBaseOffset; i < searchBuffer.length - 4; i++) {
          final b0 = searchBuffer[i];
          final b1 = searchBuffer[i + 1];
          if (b0 == 0xFF && (b1 & 0xE0) == 0xE0) {
            final verBits = (b1 >> 3) & 0x03;
            final layerBits = (b1 >> 1) & 0x03;
            if (verBits == 0x01 || layerBits == 0x00) continue; // Reserved

            final b2 = searchBuffer[i + 2];
            final bitrateIdx = (b2 >> 4) & 0x0F;
            final sampleRateIdx = (b2 >> 2) & 0x03;
            if (bitrateIdx == 0x00 || bitrateIdx == 0x0F || sampleRateIdx == 0x03) continue;

            channelMode = (searchBuffer[i + 3] >> 6) & 0x03;

            // Determine MPEG version
            if (verBits == 0x03) {
              mpegVersion = 1; // MPEG-1
              sampleRate = _sampleRatesMpeg1[sampleRateIdx];
              samplesPerFrame = layerBits == 0x03 ? 384 : 1152;
            } else if (verBits == 0x02) {
              mpegVersion = 2; // MPEG-2
              sampleRate = _sampleRatesMpeg2[sampleRateIdx];
              samplesPerFrame = layerBits == 0x01 ? 576 : 1152;
            } else {
              mpegVersion = 25; // MPEG-2.5
              sampleRate = _sampleRatesMpeg25[sampleRateIdx];
              samplesPerFrame = layerBits == 0x01 ? 576 : 1152;
            }

            final layer = layerBits == 0x03 ? 1 : (layerBits == 0x02 ? 2 : 3);
            if (layer == 3) {
              bitrate = mpegVersion == 1 ? _bitratesMpeg1L3[bitrateIdx] : _bitratesMpeg2L3[bitrateIdx];
            } else {
              continue; // Layer III (MP3)
            }

            if (bitrate > 0 && sampleRate > 0) {
              frameStart = i;
              break;
            }
          }
        }

        if (frameStart == -1 || bitrate == 0 || sampleRate == 0) {
          return null;
        }

        // 3. Inspect Xing / Info VBR Header
        final isMono = channelMode == 3;
        final xingOffset = frameStart + 4 + (mpegVersion == 1 ? (isMono ? 17 : 32) : (isMono ? 9 : 17));

        if (xingOffset + 12 <= searchBuffer.length) {
          final magic = String.fromCharCodes(searchBuffer.sublist(xingOffset, xingOffset + 4));
          if (magic == 'Xing' || magic == 'Info') {
            final xingFlags = (searchBuffer[xingOffset + 4] << 24) |
                              (searchBuffer[xingOffset + 5] << 16) |
                              (searchBuffer[xingOffset + 6] << 8) |
                              searchBuffer[xingOffset + 7];
            final hasFrames = (xingFlags & 0x0001) != 0;
            if (hasFrames) {
              final totalFrames = (searchBuffer[xingOffset + 8] << 24) |
                                  (searchBuffer[xingOffset + 9] << 16) |
                                  (searchBuffer[xingOffset + 10] << 8) |
                                  searchBuffer[xingOffset + 11];
              if (totalFrames > 0) {
                final durationSec = (totalFrames * samplesPerFrame) / sampleRate;
                return Duration(microseconds: (durationSec * 1000000).round());
              }
            }
          }
        }

        // 4. Inspect VBRI VBR Header
        final vbriOffset = frameStart + 4 + 32;
        if (vbriOffset + 18 <= searchBuffer.length) {
          final magic = String.fromCharCodes(searchBuffer.sublist(vbriOffset, vbriOffset + 4));
          if (magic == 'VBRI') {
            final totalFrames = (searchBuffer[vbriOffset + 14] << 24) |
                                (searchBuffer[vbriOffset + 15] << 16) |
                                (searchBuffer[vbriOffset + 16] << 8) |
                                searchBuffer[vbriOffset + 17];
            if (totalFrames > 0) {
              final durationSec = (totalFrames * samplesPerFrame) / sampleRate;
              return Duration(microseconds: (durationSec * 1000000).round());
            }
          }
        }

        // 5. CBR Fallback: Calculate duration from clean audio payload bytes and bitrate
        int id3v1Size = 0;
        if (fileLength >= 128) {
          raf.setPositionSync(fileLength - 128);
          final tail = Uint8List(3);
          raf.readIntoSync(tail);
          if (tail[0] == 0x54 && tail[1] == 0x41 && tail[2] == 0x47) { // 'TAG'
            id3v1Size = 128;
          }
        }

        final audioDataBytes = fileLength - id3v2Size - id3v1Size;
        if (audioDataBytes > 0 && bitrate > 0) {
          final durationSec = (audioDataBytes * 8) / (bitrate * 1000);
          return Duration(microseconds: (durationSec * 1000000).round());
        }
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
