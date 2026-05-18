import time
from database import Database

# ── Point values per event ─────────────────────────────────────────────────────
POINT_MAP = {
    "like":     1,
    "follow":   20,
    "share":    30,
    "comment":  2,
    # Gifts — by TikTok gift name (lowercase)
    "rose":           10,
    "tiktok universe":10000,
    "galaxy":        5000,
    "lion":          1000,
    "drama queen":    500,
    "concert":        200,
    "fireworks":      100,
    "ice cream cone":  50,
    "sunglasses":      20,
}

# ── Level thresholds ───────────────────────────────────────────────────────────
LEVELS = [
    (0,     1, "🌱 Seedling"),
    (1000,  2, "⚡ Rising"),
    (5000,  3, "🔥 Blazing"),
    (10000, 4, "💎 Diamond"),
    (50000, 5, "👑 Legendary"),
]

def get_level(points: int) -> tuple[int, str, int, int]:
    """Returns (level_num, label, current_threshold, next_threshold)."""
    level_num, label, threshold, next_thresh = 1, LEVELS[0][2], 0, LEVELS[1][0]
    for i, (req, num, lbl) in enumerate(LEVELS):
        if points >= req:
            level_num = num
            label = lbl
            threshold = req
            next_thresh = LEVELS[i + 1][0] if i + 1 < len(LEVELS) else req
    return level_num, label, threshold, next_thresh


class PointsEngine:
    def __init__(self, db: Database):
        self.db = db
        self._spam_cooldown: dict[str, float] = {}   # user → last_comment_time
        self._country_cache: dict[str, dict] = {}     # country → {points, level}

    # ── Process incoming event ─────────────────────────────────────────────────
    def process_event(self, event: dict) -> dict | None:
        etype = event.get("type")
        user = event.get("user", "unknown")
        country = event.get("country")

        # --- Country registration ---
        if etype == "register":
            self.db.register_user(user, country)
            return {"type": "register", "user": user, "country": country}

        # Resolve country if not provided
        if not country:
            country = self.db.get_user_country(user)
        if not country:
            return None  # Viewer not registered

        # --- Anti-spam for comments ---
        if etype == "comment":
            last = self._spam_cooldown.get(user, 0)
            if time.time() - last < 3:
                return None
            self._spam_cooldown[user] = time.time()

        # --- Calculate points ---
        points = self._calc_points(event)
        if points == 0:
            return None

        # --- Apply multiplier for active battle ---
        battle = self.db.get_active_battle()
        multiplier = 1.0
        if battle and country in (battle["country_a"], battle["country_b"]):
            multiplier = 1.5

        total_points = int(points * multiplier)

        # --- Update DB ---
        old_level = self.db.get_country_level(country)
        self.db.add_points(country, total_points, etype)
        new_data = self.db.get_country_data(country)
        new_level_num, new_label, threshold, next_thresh = get_level(new_data["points"])

        # --- Detect level up ---
        leveled_up = new_level_num > old_level

        if leveled_up:
            self.db.set_country_level(country, new_level_num)

        leaderboard = self.get_leaderboard()

        return {
            "type": "points_update",
            "country": country,
            "user": user,
            "event_type": etype,
            "points_added": total_points,
            "multiplier": multiplier,
            "gift_name": event.get("gift_name"),
            "new_total": new_data["points"],
            "level": new_level_num,
            "level_label": new_label,
            "level_threshold": threshold,
            "next_threshold": next_thresh,
            "leveled_up": leveled_up,
            "leaderboard": leaderboard,
            "battle": battle,
        }

    # ── Gift point lookup ──────────────────────────────────────────────────────
    def _calc_points(self, event: dict) -> int:
        etype = event.get("type")
        if etype in POINT_MAP:
            return POINT_MAP[etype]
        if etype == "gift":
            gift_name = event.get("gift_name", "").lower()
            amount = event.get("amount", 1)
            base = POINT_MAP.get(gift_name, 5)
            return base * amount
        return 0

    # ── Leaderboard ────────────────────────────────────────────────────────────
    def get_leaderboard(self) -> list[dict]:
        rows = self.db.get_all_countries()
        result = []
        for row in rows:
            pts = row["points"]
            lv, lbl, thresh, nxt = get_level(pts)
            progress = 0
            if nxt > thresh:
                progress = min(100, int((pts - thresh) / (nxt - thresh) * 100))
            
            # Use .get() for columns that might have just been added by ALTER TABLE and might return None
            # or aren't in older rows if somehow skipped, though SQLite dict cursor normally has them.
            likes = dict(row).get("total_likes", 0) or 0
            gifts = dict(row).get("total_gifts", 0) or 0
            comments = dict(row).get("total_comments", 0) or 0
            follows = dict(row).get("total_follows", 0) or 0
            shares = dict(row).get("total_shares", 0) or 0

            result.append({
                "country": row["country"],
                "flag": row["flag"],
                "points": pts,
                "level": lv,
                "level_label": lbl,
                "progress": progress,
                "next_threshold": nxt,
                "rank": 0,
                "stats": {
                    "likes": likes,
                    "gifts": gifts,
                    "comments": comments,
                    "follows": follows,
                    "shares": shares
                }
            })
        result.sort(key=lambda x: x["points"], reverse=True)
        for i, r in enumerate(result):
            r["rank"] = i + 1
        return result[:10]

    # ── Battle system ──────────────────────────────────────────────────────────
    def start_battle(self, country_a: str, country_b: str) -> dict:
        self.db.create_battle(country_a, country_b)
        return {"type": "battle_start", "country_a": country_a, "country_b": country_b}

    def end_battle(self) -> dict:
        battle = self.db.get_active_battle()
        if not battle:
            return {}
        data_a = self.db.get_country_data(battle["country_a"])
        data_b = self.db.get_country_data(battle["country_b"])
        winner = battle["country_a"] if data_a["points"] >= data_b["points"] else battle["country_b"]
        self.db.end_battle(winner)
        # Bonus to winner
        self.db.add_points(winner, 1000, "battle_win")
        return {"type": "battle_end", "winner": winner, "leaderboard": self.get_leaderboard()}
