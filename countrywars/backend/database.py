import sqlite3
import json
from pathlib import Path

DB_PATH = Path(__file__).parent.parent / "database" / "countrywars.db"

# Country → flag emoji map (expandable)
FLAG_MAP = {
    "Philippines": "🇵🇭", "PH": "🇵🇭",
    "Japan": "🇯🇵", "JP": "🇯🇵",
    "USA": "🇺🇸", "United States": "🇺🇸", "US": "🇺🇸",
    "South Korea": "🇰🇷", "Korea": "🇰🇷", "KR": "🇰🇷",
    "Indonesia": "🇮🇩", "ID": "🇮🇩",
    "Thailand": "🇹🇭", "TH": "🇹🇭",
    "Malaysia": "🇲🇾", "MY": "🇲🇾",
    "Vietnam": "🇻🇳", "VN": "🇻🇳",
    "Brazil": "🇧🇷", "BR": "🇧🇷",
    "Mexico": "🇲🇽", "MX": "🇲🇽",
    "India": "🇮🇳", "IN": "🇮🇳",
    "China": "🇨🇳", "CN": "🇨🇳",
    "United Kingdom": "🇬🇧", "UK": "🇬🇧", "GB": "🇬🇧",
    "Australia": "🇦🇺", "AU": "🇦🇺",
    "Canada": "🇨🇦", "CA": "🇨🇦",
    "France": "🇫🇷", "FR": "🇫🇷",
    "Germany": "🇩🇪", "DE": "🇩🇪",
    "Spain": "🇪🇸", "ES": "🇪🇸",
    "Italy": "🇮🇹", "IT": "🇮🇹",
    "Nigeria": "🇳🇬", "NG": "🇳🇬",
    "Saudi Arabia": "🇸🇦", "SA": "🇸🇦",
    "UAE": "🇦🇪", "AE": "🇦🇪",
    "Pakistan": "🇵🇰", "PK": "🇵🇰",
    "Bangladesh": "🇧🇩", "BD": "🇧🇩",
    "Egypt": "🇪🇬", "EG": "🇪🇬",
    "Turkey": "🇹🇷", "TR": "🇹🇷",
    "Argentina": "🇦🇷", "AR": "🇦🇷",
    "Colombia": "🇨🇴", "CO": "🇨🇴",
    "Singapore": "🇸🇬", "SG": "🇸🇬",
}

COUNTRY_ALIASES = {
    "PH": "Philippines", "JP": "Japan", "US": "USA", "KR": "South Korea",
    "ID": "Indonesia", "TH": "Thailand", "MY": "Malaysia", "VN": "Vietnam",
    "BR": "Brazil", "MX": "Mexico", "IN": "India", "CN": "China",
    "UK": "United Kingdom", "GB": "United Kingdom", "AU": "Australia",
    "CA": "Canada", "FR": "France", "DE": "Germany", "ES": "Spain",
    "IT": "Italy", "NG": "Nigeria", "SA": "Saudi Arabia", "AE": "UAE",
    "PK": "Pakistan", "BD": "Bangladesh", "EG": "Egypt", "TR": "Turkey",
    "AR": "Argentina", "CO": "Colombia", "SG": "Singapore",
}


# Reverse map: flag emoji → canonical country name
FLAG_EMOJI_TO_COUNTRY = {v: k for k, v in FLAG_MAP.items() if len(k) > 2}
# Also add short-code keys explicitly
FLAG_EMOJI_TO_COUNTRY.update({
    "🇵🇭": "Philippines", "🇯🇵": "Japan", "🇺🇸": "USA",
    "🇰🇷": "South Korea", "🇮🇩": "Indonesia", "🇹🇭": "Thailand",
    "🇲🇾": "Malaysia", "🇻🇳": "Vietnam", "🇧🇷": "Brazil",
    "🇲🇽": "Mexico", "🇮🇳": "India", "🇨🇳": "China",
    "🇬🇧": "United Kingdom", "🇦🇺": "Australia", "🇨🇦": "Canada",
    "🇫🇷": "France", "🇩🇪": "Germany", "🇪🇸": "Spain",
    "🇮🇹": "Italy", "🇳🇬": "Nigeria", "🇸🇦": "Saudi Arabia",
    "🇦🇪": "UAE", "🇵🇰": "Pakistan", "🇧🇩": "Bangladesh",
    "🇪🇬": "Egypt", "🇹🇷": "Turkey", "🇦🇷": "Argentina",
    "🇨🇴": "Colombia", "🇸🇬": "Singapore",
})


def resolve_country(raw: str) -> tuple[str, str]:
    """Returns (canonical_name, flag_emoji). Accepts full names, codes, or flag emojis."""
    raw = raw.strip()
    # Check if it's a flag emoji first
    if raw in FLAG_EMOJI_TO_COUNTRY:
        canonical = FLAG_EMOJI_TO_COUNTRY[raw]
        flag = FLAG_MAP.get(canonical, "🏳️")
        return canonical, flag
    upper = raw.upper()
    # Try alias (short code) first
    canonical = COUNTRY_ALIASES.get(upper, raw.title())
    flag = FLAG_MAP.get(canonical) or FLAG_MAP.get(upper) or "🏳️"
    return canonical, flag


class Database:
    def __init__(self):
        DB_PATH.parent.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(str(DB_PATH), check_same_thread=False)
        self.conn.row_factory = sqlite3.Row

    def is_known_country(self, raw: str) -> bool:
        """Checks if a string is a registered country name, alias, or flag emoji."""
        raw = raw.strip()
        if raw in FLAG_EMOJI_TO_COUNTRY:
            return True
        upper = raw.upper()
        if upper in COUNTRY_ALIASES:
            return True
        title = raw.title()
        if title in FLAG_MAP or upper in FLAG_MAP:
            return True
        return False

    def init(self):
        c = self.conn.cursor()
        c.executescript("""
            CREATE TABLE IF NOT EXISTS users (
                username TEXT PRIMARY KEY,
                country TEXT NOT NULL,
                registered_at REAL DEFAULT (unixepoch())
            );

            CREATE TABLE IF NOT EXISTS countries (
                country TEXT PRIMARY KEY,
                flag TEXT NOT NULL,
                points INTEGER DEFAULT 0,
                level INTEGER DEFAULT 1,
                total_gifts INTEGER DEFAULT 0,
                total_likes INTEGER DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS battles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                country_a TEXT,
                country_b TEXT,
                winner TEXT,
                started_at REAL DEFAULT (unixepoch()),
                ended_at REAL,
                active INTEGER DEFAULT 1
            );
        """)
        
        # Add new columns if they don't exist (for backward compatibility)
        try:
            c.execute("ALTER TABLE countries ADD COLUMN total_comments INTEGER DEFAULT 0")
            c.execute("ALTER TABLE countries ADD COLUMN total_follows INTEGER DEFAULT 0")
            c.execute("ALTER TABLE countries ADD COLUMN total_shares INTEGER DEFAULT 0")
        except sqlite3.OperationalError:
            pass
            
        self.conn.commit()

    # ── Users ──────────────────────────────────────────────────────────────────
    def register_user(self, username: str, raw_country: str):
        canonical, flag = resolve_country(raw_country)
        c = self.conn.cursor()
        # Only register once (ignore duplicates)
        c.execute("INSERT OR IGNORE INTO users (username, country) VALUES (?, ?)",
                  (username, canonical))
        # Ensure country row exists
        c.execute("INSERT OR IGNORE INTO countries (country, flag) VALUES (?, ?)",
                  (canonical, flag))
        self.conn.commit()
        return canonical

    def get_user_country(self, username: str) -> str | None:
        c = self.conn.cursor()
        row = c.execute("SELECT country FROM users WHERE username=?", (username,)).fetchone()
        return row["country"] if row else None

    def get_total_viewers(self) -> int:
        c = self.conn.cursor()
        return c.execute("SELECT COUNT(*) FROM users").fetchone()[0]

    def get_total_gifts(self) -> int:
        c = self.conn.cursor()
        return c.execute("SELECT SUM(total_gifts) FROM countries").fetchone()[0] or 0

    # ── Countries ──────────────────────────────────────────────────────────────
    def add_points(self, country: str, points: int, event_type: str):
        c = self.conn.cursor()
        gift_inc = 1 if event_type == "gift" else 0
        like_inc = 1 if event_type == "like" else 0
        comment_inc = 1 if event_type == "comment" else 0
        follow_inc = 1 if event_type == "follow" else 0
        share_inc = 1 if event_type == "share" else 0
        
        c.execute("""
            UPDATE countries
            SET points = points + ?,
                total_gifts = total_gifts + ?,
                total_likes = total_likes + ?,
                total_comments = total_comments + ?,
                total_follows = total_follows + ?,
                total_shares = total_shares + ?
            WHERE country = ?
        """, (points, gift_inc, like_inc, comment_inc, follow_inc, share_inc, country))
        self.conn.commit()

    def get_country_data(self, country: str) -> dict:
        c = self.conn.cursor()
        row = c.execute("SELECT * FROM countries WHERE country=?", (country,)).fetchone()
        return dict(row) if row else {"points": 0, "level": 1}

    def get_country_level(self, country: str) -> int:
        data = self.get_country_data(country)
        return data.get("level", 1)

    def set_country_level(self, country: str, level: int):
        self.conn.execute("UPDATE countries SET level=? WHERE country=?", (level, country))
        self.conn.commit()

    def get_all_countries(self) -> list[dict]:
        c = self.conn.cursor()
        rows = c.execute("SELECT * FROM countries ORDER BY points DESC").fetchall()
        return [dict(r) for r in rows]

    # ── Battles ────────────────────────────────────────────────────────────────
    def create_battle(self, country_a: str, country_b: str):
        self.conn.execute("UPDATE battles SET active=0 WHERE active=1")
        self.conn.execute(
            "INSERT INTO battles (country_a, country_b) VALUES (?, ?)",
            (country_a, country_b)
        )
        self.conn.commit()

    def get_active_battle(self) -> dict | None:
        c = self.conn.cursor()
        row = c.execute("SELECT * FROM battles WHERE active=1").fetchone()
        return dict(row) if row else None

    def end_battle(self, winner: str):
        self.conn.execute(
            "UPDATE battles SET active=0, winner=?, ended_at=unixepoch() WHERE active=1",
            (winner,)
        )
        self.conn.commit()
