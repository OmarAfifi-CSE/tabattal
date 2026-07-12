<div align="center">

# 📖 تبتّل | Tabattal

**The Purest, Most Precise Digital Mushaf Experience**

[![Flutter](https://img.shields.io/badge/Made_with-Flutter-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-brightgreen)]()
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20Architecture-orange)]()
[![State Management](https://img.shields.io/badge/State_Management-BLoC-blue)]()

*« وَاذْكُرِ اسْمَ رَبِّكَ وَتَبَتَّلْ إِلَيْهِ تَبْتِيلًا »*

</div>

---

## 🌟 The Vision (Why Tabattal?)

The digital Quran app market is saturated, yet it suffers from two major compromises:
1. **The "Image-Based" Compromise:** Apps use scanned images of the physical Mushaf. This results in massive app sizes, slow loading, and pixelated text when zooming in.
2. **The "System Text" Compromise:** Apps render the Quran using standard system text. While lightweight, this completely destroys the sacred, standardized layout (line breaks and page dimensions) of the physical Madani Mushaf.

**Tabattal solves this.** By utilizing an advanced **Vector-based rendering engine** paired with the official KFGQPC fonts, Tabattal dynamically draws every word to perfectly match the exact line breaks and pagination of the physical Madani Mushaf. 

Infinite zoom without losing quality, minimal app size, and absolute visual precision. No compromises.

---

## ✨ Unique Features & Advantages

### 🖌️ Pixel-Perfect Vector Pagination
Not a single image is used to render the Quran text. Everything is rendered via highly optimized vector text, maintaining 100% adherence to the physical Mushaf layout (15 lines per page) with crystal clear rendering on all screen sizes and densities.

### 🧘‍♂️ Zero Distractions (Pure Quran)
Tabattal is built for reading and listening. No intrusive ads, no cluttered menus, no "social" feeds. Just you and the Quran.

### 🎨 Premium Visual Customization
Ditch the standard "White or Black" options. Tabattal offers carefully curated, aesthetically pleasing themes:
- **Creamy (كريمي):** Classic physical paper feel.
- **Mint (نعناعي):** Soothing for long reading sessions.
- **Ice Blue (أزرق ثلجي):** Modern, cold, and crisp.
- **True Dark Mode (وضع داكن):** Perfectly balanced contrast for night reading, preserving the coloring of Ayah markers and Surah headers.
- **Scroll Direction:** Choose between classic Horizontal (book-like) or modern Vertical scrolling.

### 🎧 Seamless Audio Experience
- **Smart Highlighting:** Words or Ayahs highlight in real-time syncing perfectly with the reciter.
- **Robust Offline Support:** Download individual Surahs or entire Playlists seamlessly.
- **Flawless Background Play:** Stable background execution, free from race conditions or playback overlaps.

### 📚 Integrated Tafsir & Translation
Instantly access reliable Tafsirs and precise translations without leaving the page, fully available offline.

---

## 🛠️ Technical Stack & Architecture

This project is built with production-ready standards, focusing on performance, scalability, and clean code principles:

- **Framework:** Flutter (Mobile & Web Support).
- **State Management:** BLoC / Cubit (Predictable and reactive state streams).
- **Architecture:** Uncle Bob's Clean Architecture (Domain, Data, and Presentation layers strictly decoupled).
- **Audio Engine:** `just_audio` & `audio_service` for robust background media control.
- **Local Storage:** `shared_preferences` & optimized local JSON caching.
- **Responsive UI:** ScreenUtil for screen-relative, pixel-perfect dimensions across all form factors.

---

## 📱 Download Now

*(Coming Soon on Google Play & App Store)*

<a href="#">
  <img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" height="60" alt="Get it on Google Play">
</a>

---

## ☕ Support The Project

Tabattal is an ad-free, open-source passion project built to provide the purest Quran reading experience. If this app helped you in your daily reading or provided you with a seamless listening experience without distractions, consider buying me a coffee! It keeps the development going and the updates coming.

<a href="https://ko-fi.com/omarafifi" target="_blank"><img src="https://cdn.ko-fi.com/cdn/kofi3.png?v=3" height="50" alt="Buy Me a Coffee at ko-fi.com" /></a>

---

<div align="center">
  <i>Made with ❤️ and dedication to the Book of Allah.</i>
</div>
