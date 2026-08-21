<div align="center">

# 📖 تَبَتَّلْ | Tabattal

**The Purest, Most Precise Digital Mushaf Experience**

[![Flutter](https://img.shields.io/badge/Made_with-Flutter-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-brightgreen)]()
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20Architecture-orange)]()
[![State Management](https://img.shields.io/badge/State_Management-BLoC-blue)]()
[![Engine](https://img.shields.io/badge/Font_Engine-QCF%20V2%20Vector-D4AF37)]()
[![License](https://img.shields.io/badge/License-MIT-purple)]()

*« وَاذْكُرِ اسْمَ رَبِّكَ وَتَبَتَّلْ إِلَيْهِ تَبْتِيلًا »*

</div>

---

## 🌟 The Vision (Why Tabattal?)

The digital Quran app landscape is saturated, yet it frequently suffers from two fundamental compromises:
1. **The "Scanned-Image" Compromise:** Apps rely on static page images of the physical Mushaf. This causes massive app bundles, slow initial loading, and pixelated text when zooming or reading on high-density displays.
2. **The "Generic System Text" Compromise:** Apps render the Quran as standard unformatted body text. While lightweight, this completely destroys the sacred, standardized 15-line pagination and line breaks of the authentic Madani Mushaf.

**Tabattal bridges both worlds without compromise.** Powered by a custom **Vector-based rendering engine** utilizing official King Fahd Complex **QCF V2 glyph fonts**, Tabattal dynamically draws every word with mathematical precision to match the exact line breaks and pagination of the physical Madani Mushaf.

Infinite sharpness at any resolution, responsive page transitions, lightweight storage footprint, and zero visual compromises.

---

## ✨ Key Features & Capabilities

### 🖌️ Pixel-Perfect QCF V2 Vector Pagination & Single-Viewport Engine
* **100% Authentic Madani Mushaf Layout:** Exactly 15 lines per page, matching the physical printed copy with genuine Quranic glyphs and stop signs.
* **Single-Viewport Zero-Jank Architecture:** Custom physics-driven bidirectional page flip locked at 120 FPS with 0ms page switching and zero frame drops.
* **Instant Native Typography:** All 604 page fonts declared natively and pre-warmed directly in RAM, eliminating background zip extraction and runtime layout overhead.

### 🎨 Verse Card Generator & Full-Page Export
* **Custom Verse Sharing Cards:** Create stunning, high-resolution aesthetic cards for individual verses or selected verse ranges (up to 25 ayahs).
* **Granular Content Controls:** Independently include or exclude authentic Tafsir and English translation in shared cards.
* **Full-Page Snapshot Export:** Export the entire active Mushaf page framed with Islamic borders and theme styling.
* **11 Curated Card Themes:** Perfectly matched color palettes with instantaneous gallery synchronization and Android media store indexing.

### 🔍 Thematic & Deep Text Search
* **Quran Topics Catalog:** Explore the Holy Quran categorized by themes (Aqeedah, Acts of Worship, Ethics, Stories of the Prophets, and Social Conduct).
* **Intelligent Keyword Engine:** Instant search with prefix/suffix normalization, surah name matching, and direct in-page verse highlighting with gentle breathing animations.

### 🎧 Comprehensive Audio & Offline Manager
* **Extensive Reciter Catalog:** High-fidelity recitations across multiple categories: Murattal, Mujawwad, Warsh narration, Teacher mode, and English translations.
* **Play-Once Mode:** Listen to a single verse and pause automatically for focused memorization, reflection, and manual repetition.
* **Smart Sleep Timer:** Integrated timer with custom durations for relaxing bedtime listening.
* **Robust Offline Download Manager:** Download entire Surahs for offline listening with real-time progress indicators and instant cancellation tokens.
* **Background Media Service:** Continuous playback with system lockscreen controls, notification actions, and resilient network recovery.

### 📚 Grouped Tafsir, Translation & Quran Vocabulary
* **Offline Quran Vocabulary (Ghareeb Al-Quran):** Instant offline lookup for the meanings of unfamiliar and difficult Quranic words directly per verse.
* **Grouped Tafsir Context:** Smart detection and display of multi-verse commentary spans, showing continuation context across grouped passages.
* **Smart Tafsir Selector:** Fast, offline-accessible commentaries with upward-opening selectors and live progress feedback.
* **Authentic English Translations:** Clear, dignified English translations displayed alongside Arabic text.

### 🧠 Interactive Memorization Test Mode (Hifz Tool)
* **Word-by-Word & Ayah Masking:** Conceal words or full verses directly on the Mushaf page with pixel-stable visual spacing and zero text shifting.
* **Tap-to-Reveal & Seamless Actions:** Reveal hidden words and verses on tap, with full access to verse options and translations once revealed.

### 🎨 11 Handcrafted Mushaf Color Themes & Adaptive UI
* **Curated Color Palettes:** Creamy, Parchment, Rose Gold, Mint, Olive, Ice Blue, Slate, Emerald, Burgundy, Pure White, and OLED Dark.
* **Dedicated OLED Dark Mode:** True black backgrounds designed specifically for night reading and Qiyam, minimizing eye strain and preserving battery life.
* **Luminance-Adaptive System Chrome:** Dynamic status bar and navigation bar contrast adapting automatically to the active theme.
* **Custom Reading Flow:** Switch effortlessly between traditional horizontal book paging and modern vertical continuous scroll.

### 🔒 100% Free, Private & Ad-Free (Sadaqa Jariya)
* **Zero Advertisements & Zero Tracking:** No user tracking, no analytics telemetry, and no third-party ad SDKs.
* **Offline-First:** All essential reading, search, and tafsir features work fully offline once downloaded.

---

## 🛠️ Technical Stack & Architecture

Tabattal is crafted according to strict architectural guidelines, modern performance standards, and Uncle Bob's Clean Architecture:

* **Core Framework:** [Flutter](https://flutter.dev) (Targeting Android).
* **State Management:** [BLoC / Cubit](https://bloclibrary.dev) (Predictable, testable, and reactive state streams).
* **Architecture Pattern:** Clean Architecture (Strictly decoupled Domain, Data, and Presentation layers).
* **Audio Pipeline:** `just_audio` & `audio_service` with Android MediaSession background capabilities.
* **Database & Caching:** SQLite via `sqflite` with indexed word-level spatial lookup tables and in-memory page cache.
* **Typography:** 604 King Fahd Complex QCF V2 vector font families declared natively and managed directly by the Flutter Engine.
* **Static Analysis:** Strict zero-lint policy with optimized frame rendering and clean architectural hygiene.

---

## 📱 Download Now

<a href="https://play.google.com/store/apps/details?id=com.omarafifi.tabattal" target="_blank">
  <img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" height="60" alt="Get it on Google Play">
</a>

---

## ☕ Support The Project

Tabattal is an ad-free, open-source passion project built as a **Sadaqa Jariya** to provide the purest Quran reading experience. If this app benefits your daily recitation and study, consider supporting ongoing development:

<a href="https://ko-fi.com/omarafifi" target="_blank"><img src="https://cdn.ko-fi.com/cdn/kofi3.png?v=3" height="50" alt="Buy Me a Coffee at ko-fi.com" /></a>

---

<div align="center">
  <i>Made with dedication to the Book of Allah.</i>
</div>
