# ⚔️ Country Wars — TikTok LIVE Overlay

A real-time interactive TikTok LIVE game where countries compete for points through gifts, likes, follows, and more.

---

## 🚀 Quick Start (Windows)

1. **Install Python 3.11+** from [python.org](https://python.org) if you haven't already.

2. **Edit your TikTok username** in `START.bat`:
   ```
   set TIKTOK_USERNAME=@your_actual_tiktok_username
   ```

3. **Double-click `START.bat`** — it installs everything and starts the server.

4. **In OBS**, add a Browser Source:
   - URL: `http://localhost:3000/overlay`
   - Width: `420`
   - Height: `700`
   - ✅ Check "Shutdown source when not visible"

5. **Go LIVE on TikTok** — viewers type `!country Philippines` to register.

---

## 📋 Viewer Commands

| Command | Action |
|---------|--------|
| `!country Philippines` | Register as Philippines |
| `!country PH` | Also works (country code) |
| `!country JP` | Register as Japan |

**Country codes supported:** PH, JP, US, KR, ID, TH, MY, VN, BR, MX, IN, CN, UK, AU, CA, FR, DE, ES, IT, NG, SA, AE, PK, BD, EG, TR, AR, CO, SG

---

## 🎯 Point System

| Event | Points |
|-------|--------|
| Like | 1 pt |
| Comment | 2 pts |
| Follow | 20 pts |
| Share | 30 pts |
| Rose gift | 10 pts |
| Ice Cream Cone | 50 pts |
| Fireworks | 100 pts |
| Concert | 200 pts |
| Drama Queen | 500 pts |
| Lion | 1,000 pts |
| Galaxy | 5,000 pts |
| TikTok Universe | 10,000 pts |

---

## 👑 Levels

| Level | Points Required | Title |
|-------|----------------|-------|
| 1 | 0 | 🌱 Seedling |
| 2 | 1,000 | ⚡ Rising |
| 3 | 5,000 | 🔥 Blazing |
| 4 | 10,000 | 💎 Diamond |
| 5 | 50,000 | 👑 Legendary |

---

## ⚔️ Battle System

Battles give 1.5× points to both competing countries. Start/end via the API:

```
# Start battle between Philippines and Japan
POST http://localhost:3000/battle/start
Body: {"country_a": "Philippines", "country_b": "Japan"}

# End the battle (auto picks winner, gives +1000 bonus pts)
POST http://localhost:3000/battle/end
```

Or call from Python:
```python
import requests
requests.post("http://localhost:3000/battle/start", 
              json={"country_a": "Philippines", "country_b": "Japan"})
```

---

## 🛠️ Folder Structure

```
countrywars/
├── START.bat              ← Double-click to run
├── requirements.txt
├── backend/
│   ├── app.py             ← FastAPI server
│   ├── points_engine.py   ← Point logic & levels
│   ├── database.py        ← SQLite storage
│   └── tiktok_listener.py ← TikTok event handler
├── frontend/
│   └── index.html         ← OBS overlay (all-in-one)
└── database/
    └── countrywars.db     ← Auto-created
```

---

## ⚠️ Notes

- **TikTokLive** is an unofficial library. TikTok may block it occasionally — the system auto-reconnects every 15 seconds.
- If TikTok connection fails, the system runs in **DEMO MODE** with simulated events so you can test the overlay.
- The database persists between sessions — points carry over if you restart.
- To **reset all points**, delete `database/countrywars.db`.

---

## 🔧 Troubleshooting

**OBS shows blank:** Make sure the server is running first, then refresh the browser source.

**TikTok not connecting:** Make sure you're actually LIVE on TikTok, and your username is correct (with or without @).

**Port already in use:** Change port 3000 to another number in `backend/app.py` and `START.bat`.
