import asyncio
import json
import logging
import os
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import uvicorn
from pathlib import Path

from points_engine import PointsEngine
from database import Database
from tiktok_listener import TikTokListener

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

# ── Global state ──────────────────────────────────────────────────────────────
db = Database()
engine = PointsEngine(db)
connected_clients: list[WebSocket] = []
listener: TikTokListener = None

async def broadcast(data: dict):
    """Send update to all connected OBS overlay clients."""
    msg = json.dumps(data)
    dead = []
    for ws in connected_clients:
        try:
            await ws.send_text(msg)
        except Exception:
            dead.append(ws)
    for ws in dead:
        connected_clients.remove(ws)

# ── Lifespan ──────────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    db.init()
    logger.info("✅ Database ready")
    yield
    logger.info("Server shutting down")

app = FastAPI(lifespan=lifespan)

# Allow all origins for Flutter app & Vercel control panel
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve frontend files (local PC use only — on Railway, Flutter/Vercel connects remotely)
frontend_path = Path(__file__).parent.parent / "frontend"
if frontend_path.exists():
    app.mount("/static", StaticFiles(directory=str(frontend_path)), name="static")

    @app.get("/")
    async def serve_control():
        return FileResponse(str(frontend_path / "control.html"))

    @app.get("/overlay")
    async def overlay():
        return FileResponse(str(frontend_path / "index.html"))
else:
    @app.get("/")
    async def root():
        return {"status": "Country Wars Backend Running ✅", "version": "2.0"}

# ── WebSocket endpoint ─────────────────────────────────────────────────────────
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    connected_clients.append(websocket)
    logger.info(f"Client connected. Total: {len(connected_clients)}")

    # Send full leaderboard on connect
    leaderboard = engine.get_leaderboard()
    await websocket.send_text(json.dumps({"type": "full_update", "leaderboard": leaderboard}))

    try:
        while True:
            await websocket.receive_text()  # keep alive
    except WebSocketDisconnect:
        if websocket in connected_clients:
            connected_clients.remove(websocket)
        logger.info("Client disconnected")

# ── REST endpoints ─────────────────────────────────────────────────────────────
@app.get("/leaderboard")
async def get_leaderboard():
    return {"leaderboard": engine.get_leaderboard()}

@app.get("/health")
async def health():
    return {"status": "ok", "connected_clients": len(connected_clients)}

@app.post("/battle/start")
async def start_battle(data: dict):
    result = engine.start_battle(data["country_a"], data["country_b"])
    await broadcast(result)
    return result

@app.post("/battle/end")
async def end_battle():
    result = engine.end_battle()
    if result:
        await broadcast(result)
    return result

@app.get("/stats")
async def get_stats():
    return {
        "total_countries": len(engine.get_leaderboard()),
        "total_viewers": db.get_total_viewers(),
        "total_gifts": db.get_total_gifts()
    }

# ── TikTok event handler ───────────────────────────────────────────────────────
async def handle_tiktok_event(event: dict):
    result = engine.process_event(event)
    if result:
        await broadcast(result)
        logger.info(f"[EVENT] {event.get('type')} → {result.get('country','?')} +{result.get('points_added',0)}pts")

# ── Mock Control endpoints ─────────────────────────────────────────────────────
@app.get("/mock/config")
async def get_mock_config():
    if listener:
        return {
            "mock_mode": listener.mock_mode,
            "auto_demo": getattr(listener, "auto_demo", True),
            "sim_speed": getattr(listener, "sim_speed", "medium")
        }
    return {
        "mock_mode": os.environ.get("MOCK_MODE", "false").lower() == "true",
        "auto_demo": True,
        "sim_speed": "medium"
    }

@app.post("/mock/toggle-auto")
async def toggle_auto(data: dict):
    if listener:
        listener.auto_demo = data.get("auto_demo", True)
        listener.sim_speed = data.get("sim_speed", "medium")
        return {"status": "success", "auto_demo": listener.auto_demo, "sim_speed": listener.sim_speed}
    return {"status": "error", "message": "Listener not initialized"}

@app.post("/mock/event")
async def trigger_mock_event(data: dict):
    etype = data.get("type")
    user = data.get("user", "mock_user")
    country = data.get("country")

    if etype == "register" and country:
        canonical = db.register_user(user, country)
        event = {"type": "register", "user": user, "country": canonical}
        await handle_tiktok_event(event)
        return {"status": "success", "event": event}

    event = {"type": etype, "user": user}
    if country:
        event["country"] = country
    if etype == "gift":
        event["gift_name"] = data.get("gift_name", "rose").lower()
        event["amount"] = int(data.get("amount", 1))

    await handle_tiktok_event(event)
    return {"status": "success", "event": event}

@app.post("/mock/reset")
async def reset_mock_db():
    try:
        c = db.conn.cursor()
        c.execute("DELETE FROM users")
        c.execute("DELETE FROM countries")
        c.execute("DELETE FROM battles")
        db.conn.commit()
        await broadcast({"type": "full_update", "leaderboard": []})
        return {"status": "success", "message": "Database reset successfully"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

# ── Start TikTok listener ──────────────────────────────────────────────────────
@app.on_event("startup")
async def start_tiktok():
    global listener
    listener = TikTokListener(handle_tiktok_event, engine)
    asyncio.create_task(listener.start())
    logger.info("🎮 TikTok listener started")

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 3000))
    uvicorn.run("app:app", host="0.0.0.0", port=port, reload=False)
