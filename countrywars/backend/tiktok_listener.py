import asyncio
import logging
import os
import re
from typing import Callable

logger = logging.getLogger(__name__)

# TikTok username — set via env var or hardcode here
TIKTOK_USERNAME = os.environ.get("TIKTOK_USERNAME", "")
if TIKTOK_USERNAME.startswith("@"):
    TIKTOK_USERNAME = TIKTOK_USERNAME[1:]

# Country registration pattern — matches:
#   !country PH
#   !country Philippines
#   !country 🇵🇭  (flag emoji)
REGISTER_PATTERN = re.compile(
    r"^!country\s+(.+)$", re.IGNORECASE
)

# Standalone flag emoji pattern (two regional indicator symbols)
FLAG_EMOJI_PATTERN = re.compile(
    r"^[\U0001F1E0-\U0001F1FF]{2}$"
)


class TikTokListener:
    def __init__(self, event_handler: Callable, engine):
        self.handler = event_handler
        self.engine = engine
        self.mock_mode = os.environ.get("MOCK_MODE", "false").lower() == "true"
        self.auto_demo = True
        self.sim_speed = "medium"

    async def start(self):
        if self.mock_mode:
            logger.info("🎮 Running in MOCK MODE (Bypassing real TikTok Live)")
            await self._demo_mode()
            return

        try:
            from TikTokLive import TikTokLiveClient
            from TikTokLive.events import (
                ConnectEvent, DisconnectEvent,
                CommentEvent, GiftEvent, LikeEvent,
                FollowEvent, ShareEvent
            )
        except ImportError:
            logger.warning("TikTokLive not installed. Running in DEMO mode.")
            await self._demo_mode()
            return

        client = TikTokLiveClient(unique_id=TIKTOK_USERNAME)

        @client.on(ConnectEvent)
        async def on_connect(event):
            logger.info(f"✅ Connected to TikTok LIVE: {TIKTOK_USERNAME}")

        @client.on(DisconnectEvent)
        async def on_disconnect(event):
            logger.warning("❌ Disconnected from TikTok LIVE")

        @client.on(CommentEvent)
        async def on_comment(event):
            user = event.user.unique_id
            text = event.comment.strip()

            # ── Registration via !country <name|code|flag> ──
            m = REGISTER_PATTERN.match(text)
            if m:
                country_raw = m.group(1).strip()
                self.engine.db.register_user(user, country_raw)
                country = self.engine.db.get_user_country(user)
                logger.info(f"📋 Registered {user} → {country}")
                await self.handler({
                    "type": "register",
                    "user": user,
                    "country": country
                })
                return

            # ── Registration via bare flag emoji (e.g. 🇵🇭) ──
            if FLAG_EMOJI_PATTERN.match(text):
                self.engine.db.register_user(user, text)
                country = self.engine.db.get_user_country(user)
                if country:
                    logger.info(f"🏳️ Flag-registered {user} → {country}")
                    await self.handler({
                        "type": "register",
                        "user": user,
                        "country": country
                    })
                return

            # ── Registration via bare country name/code (e.g. "PH", "Philippines") ──
            if self.engine.db.is_known_country(text):
                self.engine.db.register_user(user, text)
                country = self.engine.db.get_user_country(user)
                if country:
                    logger.info(f"🏷️ Name-registered {user} → {country}")
                    await self.handler({
                        "type": "register",
                        "user": user,
                        "country": country
                    })
                return

            # ── Regular comment → 2 points ──
            await self.handler({"type": "comment", "user": user})

        @client.on(GiftEvent)
        async def on_gift(event):
            user = event.user.unique_id
            gift_name = event.gift.name
            amount = event.gift.count or 1
            await self.handler({
                "type": "gift",
                "user": user,
                "gift_name": gift_name.lower(),
                "amount": amount
            })

        @client.on(LikeEvent)
        async def on_like(event):
            user = event.user.unique_id
            count = getattr(event, "like_count", 1) or 1
            for _ in range(min(count, 50)):   # cap per burst
                await self.handler({"type": "like", "user": user})

        @client.on(FollowEvent)
        async def on_follow(event):
            user = event.user.unique_id
            await self.handler({"type": "follow", "user": user})

        @client.on(ShareEvent)
        async def on_share(event):
            user = event.user.unique_id
            await self.handler({"type": "share", "user": user})

        # Reconnect loop
        while True:
            try:
                await client.start()
            except Exception as e:
                logger.error(f"TikTok connection error: {e}")
                logger.info("Retrying in 15 seconds...")
                await asyncio.sleep(15)

    # ── Demo mode — simulates events when TikTok is not connected ─────────────
    async def _demo_mode(self):
        import random
        logger.info("🎮 DEMO MODE: Simulating TikTok events in background when active")

        demo_countries = ["Philippines", "Japan", "USA", "South Korea", "Indonesia", "Thailand"]
        demo_users = {
            "alex_ph": "Philippines", "sakura99": "Japan", "mike_usa": "USA",
            "kimchi_fan": "South Korea", "budi_id": "Indonesia", "thai_lover": "Thailand"
        }

        # Pre-register demo users
        for user, country in demo_users.items():
            self.engine.db.register_user(user, country)

        events_pool = [
            {"type": "like"},
            {"type": "like"},
            {"type": "like"},
            {"type": "follow"},
            {"type": "share"},
            {"type": "gift", "gift_name": "rose", "amount": 1},
            {"type": "gift", "gift_name": "ice cream cone", "amount": 3},
            {"type": "gift", "gift_name": "fireworks", "amount": 1},
            {"type": "gift", "gift_name": "lion", "amount": 1},
            {"type": "comment"},
        ]

        while True:
            if getattr(self, "auto_demo", True):
                user = random.choice(list(demo_users.keys()))
                base_event = random.choice(events_pool).copy()
                base_event["user"] = user

                # Battle event steering (70% focus on battle countries)
                battle = self.engine.db.get_active_battle()
                if battle and random.random() < 0.7:
                    target_country = random.choice([battle["country_a"], battle["country_b"]])
                    battle_users = [u for u, c in demo_users.items() if c == target_country]
                    if battle_users:
                        base_event["user"] = random.choice(battle_users)
                    else:
                        temp_user = f"battler_{target_country.lower()[:3]}_{random.randint(10,99)}"
                        demo_users[temp_user] = target_country
                        self.engine.db.register_user(temp_user, target_country)
                        base_event["user"] = temp_user

                await self.handler(base_event)

                speed = getattr(self, "sim_speed", "medium")
                if speed == "fast":
                    await asyncio.sleep(random.uniform(0.1, 0.5))
                elif speed == "slow":
                    await asyncio.sleep(random.uniform(3.0, 6.0))
                else:  # medium
                    await asyncio.sleep(random.uniform(1.0, 2.5))
            else:
                await asyncio.sleep(0.5)
