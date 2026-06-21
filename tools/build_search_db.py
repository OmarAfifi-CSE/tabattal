import sqlite3
import re

def remove_diacritics(text):
    # Arabic diacritics range
    text = re.sub(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E8\u06EA-\u06ED]', '', text)
    # Normalize Alefs
    text = re.sub(r'[أإآٱ]', 'ا', text)
    # Normalize Ta Marbuta to Ha
    text = re.sub(r'ة', 'ه', text)
    # Normalize Ya
    text = re.sub(r'ى', 'ي', text)
    text = re.sub(r'ئ', 'ي', text)
    text = re.sub(r'ؤ', 'و', text)
    return text

def main():
    conn = sqlite3.connect('assets/data/quran.db')
    c = conn.cursor()

    print("Dropping existing quran_search table if exists...")
    c.execute('DROP TABLE IF EXISTS quran_search')
    
    print("Creating quran_search table...")
    c.execute('''
        CREATE TABLE quran_search (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            verse_key TEXT,
            surah INTEGER,
            ayah INTEGER,
            page INTEGER,
            text_clean TEXT,
            text_uthmani TEXT
        )
    ''')

    print("Fetching words from quran_words...")
    c.execute("SELECT verse_key, text_uthmani, char_type_name, page FROM quran_words ORDER BY id ASC")
    rows = c.fetchall()

    verses = {}
    for row in rows:
        verse_key, text_uthmani, char_type, page = row
        if verse_key not in verses:
            verses[verse_key] = {'words': [], 'page': page}
        
        if char_type == 'word':
            verses[verse_key]['words'].append(text_uthmani)

    print(f"Processing {len(verses)} verses...")
    for verse_key, data in verses.items():
        surah, ayah = map(int, verse_key.split(':'))
        text_uthmani = ' '.join(data['words'])
        text_clean = remove_diacritics(text_uthmani)
        page = data['page']
        
        c.execute('''
            INSERT INTO quran_search (verse_key, surah, ayah, page, text_clean, text_uthmani)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (verse_key, surah, ayah, page, text_clean, text_uthmani))

    print("Committing changes...")
    conn.commit()
    conn.close()
    print("Search database built successfully.")

if __name__ == '__main__':
    main()
