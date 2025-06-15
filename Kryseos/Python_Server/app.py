import os
import threading
import logging
from pathlib import Path
from fastapi import FastAPI
from cryptography.fernet import Fernet
from dotenv import load_dotenv

# --- 🔐 Ensure Fernet key exists and load it from .env ---
env_path = Path(".env")
if not env_path.exists():
    generated_key = Fernet.generate_key().decode()
    env_path.write_text(f"FERNET_KEY={generated_key}\n")
    print("🔐 .env created with new FERNET_KEY.")
else:
    print("📄 .env found. Loading FERNET_KEY...")

load_dotenv()

FERNET_KEY = os.getenv("FERNET_KEY")
if not FERNET_KEY:
    raise ValueError("❌ FERNET_KEY not found in environment.")

# Optional: if you want a global Fernet object available
fernet = Fernet(FERNET_KEY)

# ----------------------------------------------------------

from routes import router as routes_router
from database import init_db, load_existing_users
from services import (
    user_credentials,
    user_feedback,
    user_locks,
    user_configs,
    user_sockets,
    user_threads,
    user_running_flags,
    user_thread_function
)

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create FastAPI app and attach routes
app = FastAPI()
app.include_router(routes_router)

@app.on_event("startup")
async def startup_event():
    logger.info("🔄 Initializing database...")
    await init_db()

    logger.info("📥 Loading users from DB...")
    users_data = await load_existing_users()

    for user_id, user_info in users_data.items():
        print(f"🔁 Restoring user session: {user_id}")

        user_credentials[user_id] = {
            "api_key": user_info["api_key"],
            "api_secret": user_info["api_secret"],
            "account": user_info["account"]
        }

        user_feedback[user_id] = {}
        user_locks[user_id] = threading.Lock()
        user_configs[user_id] = None
        user_running_flags[user_id] = [False]
        user_sockets[user_id] = set()

        thread = threading.Thread(
            target=user_thread_function,
            args=(user_id,),
            daemon=True
        )
        thread.start()
        user_threads[user_id] = thread

        logger.info(f"✅ Thread started for user: {user_id}")

@app.get("/")
async def root():
    print("📡 Root endpoint called")
    return {"message": "🟢 Trading server is running."}
