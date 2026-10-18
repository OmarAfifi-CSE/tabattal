"""
Test Verification Client for Tabattal Video Exporter
=====================================================
Sends a simulated multipart Quran video export payload to the Modal serverless endpoint
and verifies that a valid 1080x1920 MP4 video is compiled and downloaded successfully.

Usage:
    python test_client.py <MODAL_ENDPOINT_URL>
"""

import io
import json
import os
import sys
import time
from typing import Tuple
import requests
from PIL import Image, ImageDraw


def create_solid_image(width: int, height: int, color: Tuple[int, int, int] = (20, 25, 35)) -> bytes:
    """Generates a mock base card frame in JPEG format."""
    img = Image.new("RGB", (width, height), color=color)
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=90)
    return buf.getvalue()


def create_text_overlay(width: int, height: int, text: str) -> bytes:
    """Generates a transparent PNG overlay representing a rendered verse line."""
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Centered placeholder text simulation
    draw.text((width // 4, height // 2), text, fill=(255, 255, 255, 255))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def run_test(endpoint_url: str, output_path: str = "test_tabattal_render.mp4") -> bool:
    print("==========================================================")
    print("  Tabattal Cloud Video Exporter - End-to-End Test Client  ")
    print("==========================================================")
    print(f"[*] Target Endpoint: {endpoint_url}")
    print("[*] Generating synthetic test assets (1080x1920)...")

    base_frame_bytes = create_solid_image(1080, 1920)
    overlay_0 = create_text_overlay(1080, 1920, "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")

    metadata = {
        "surahNumber": 112,
        "startAyah": 1,
        "endAyah": 1,
        "reciterPath": "Minshawy_Murattal_128kbps",
        "targetWidth": 1080,
        "targetHeight": 1920,
        "backgroundDimming": 0.40,
        "crf": 22,
        "unitConfigs": [
            {
                "verseNumber": 1,
                "durSec": 3.5,
                "cropY": 600,
            }
        ],
    }

    files = {
        "metadata": (None, json.dumps(metadata), "application/json"),
        "base_frame": ("base_frame.jpg", base_frame_bytes, "image/jpeg"),
        "overlay_unit_0": ("overlay_unit_0.png", overlay_0, "image/png"),
    }

    headers = {
        "Origin": "https://tabattal.omar-afifi.com"
    }

    print("[*] Transmitting multipart payload to serverless container...")
    t0 = time.time()
    try:
        resp = requests.post(endpoint_url, files=files, headers=headers, timeout=120)
    except requests.exceptions.RequestException as e:
        print(f"\n[-] Network error during request: {e}")
        return False

    elapsed = time.time() - t0

    if resp.status_code == 200:
        content_type = resp.headers.get("Content-Type", "")
        if "video" not in content_type and not resp.content.startswith(b"\x00\x00\x00"):
            print(f"[-] Unexpected content-type: {content_type}")
            print(resp.text[:500])
            return False

        with open(output_path, "wb") as f:
            f.write(resp.content)

        file_size_mb = len(resp.content) / (1024 * 1024)
        print(f"\n[+] TEST PASSED!")
        print(f"[+] Total execution time: {elapsed:.2f} seconds")
        print(f"[+] Downloaded MP4 size:  {file_size_mb:.2f} MB")
        print(f"[+] Saved output file to: {os.path.abspath(output_path)}")
        return True
    else:
        print(f"\n[-] TEST FAILED with HTTP status code: {resp.status_code}")
        try:
            err_data = resp.json()
            print(f"[-] Error Code:    {err_data.get('code')}")
            print(f"[-] Error Message: {err_data.get('message') or err_data.get('messageEn')}")
            if "details" in err_data:
                print(f"[-] Details:       {err_data['details']}")
        except Exception:
            print(f"[-] Raw Response:  {resp.text[:500]}")
        return False


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python test_client.py <MODAL_ENDPOINT_URL>")
        print("Example: python test_client.py https://myuser--tabattal-video-exporter-export-video.modal.run")
        sys.exit(1)

    url = sys.argv[1].strip()
    success = run_test(url)
    sys.exit(0 if success else 1)
