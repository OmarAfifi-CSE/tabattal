import requests
import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'assets', 'data', 'quran.db')

def fetch_translation_for_chapter(chapter_id, resource_id):
    url = f"https://api.quran.com/api/v4/quran/translations/{resource_id}?chapter_number={chapter_id}"
    # Wait, the v4 API for by_chapter translation is:
    # GET /api/v4/translations/{resource_id}/by_chapter/{chapter_id}
    # Let's use that instead, as we confirmed it works.
    pass

def main():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    
    # Let's clear the old ones to avoid duplicates or messy states
    c.execute("DELETE FROM translation WHERE resource_id = ?", (20,))
    c.execute("DELETE FROM tafsir WHERE resource_id IN (14, 16, 91)")
    
    total_translations = 0
    total_tafsirs = {14: 0, 16: 0, 91: 0}
    
    for chapter_id in range(1, 115):
        print(f"Fetching Chapter {chapter_id}...")
        
        # 1. Fetch Translation (Resource 20)
        url_trans = f"https://api.quran.com/api/v4/translations/20/by_chapter/{chapter_id}?per_page=300"
        res_trans = requests.get(url_trans)
        if res_trans.status_code == 200:
            data = res_trans.json().get('translations', [])
            for i, item in enumerate(data):
                verse_key = f"{chapter_id}:{i+1}"
                text = item.get('text', '')
                c.execute("INSERT INTO translation (verse_key, resource_id, text) VALUES (?, ?, ?)",
                          (verse_key, 20, text))
                total_translations += 1
        
        # 2. Fetch Tafsirs (Resources 14, 16, 91)
        for tafsir_id in [14, 16, 91]:
            url_tafsir = f"https://api.quran.com/api/v4/tafsirs/{tafsir_id}/by_chapter/{chapter_id}?per_page=300"
            res_tafsir = requests.get(url_tafsir)
            if res_tafsir.status_code == 200:
                data = res_tafsir.json().get('tafsirs', [])
                for item in data:
                    verse_key = item.get('verse_key')
                    text = item.get('text', '')
                    if verse_key and text:
                        c.execute("INSERT INTO tafsir (verse_key, resource_id, text) VALUES (?, ?, ?)",
                                  (verse_key, tafsir_id, text))
                        total_tafsirs[tafsir_id] += 1
                        
        conn.commit()
    
    print(f"Successfully inserted {total_translations} translations.")
    for tid, count in total_tafsirs.items():
        print(f"Inserted {count} tafsirs for resource {tid}.")
    
    print("Running VACUUM to reclaim space...")
    c.execute("VACUUM")
    conn.commit()
    print("Vacuum completed!")
    conn.close()

if __name__ == "__main__":
    main()
