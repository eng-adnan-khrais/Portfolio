import os
from pathlib import Path
from dotenv import load_dotenv
from cryptography.fernet import Fernet
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy.future import select
from models import Base, User

# --- Load or validate FERNET_KEY from .env ---
env_path = Path(".env")
if env_path.exists():
    load_dotenv(dotenv_path=env_path)

FERNET_KEY = os.environ.get("FERNET_KEY")
if FERNET_KEY is None:
    raise RuntimeError("❌ FERNET_KEY environment variable is not set.")
fernet = Fernet(FERNET_KEY.encode())

# --- Database setup ---
DATABASE_URL = "sqlite+aiosqlite:///./trading.db"
engine = create_async_engine(DATABASE_URL, echo=False, future=True)
AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

# --- Create tables if not exist ---
async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

# --- Load all existing users and decrypt API credentials ---
async def load_existing_users():
    async with AsyncSessionLocal() as session:
        result = await session.execute(select(User))
        users = result.scalars().all()

        user_data = {}

        for user in users:
            try:
                decrypted_api_key = fernet.decrypt(user.api_key.encode()).decode()
                decrypted_api_secret = fernet.decrypt(user.api_secret.encode()).decode()
            except Exception as e:
                raise ValueError(f"Decryption failed for user {user.user_id}: {e}")

            user_data[user.user_id] = {
                "api_key": decrypted_api_key,
                "api_secret": decrypted_api_secret,
                "account": user.account,
                "equity": user.equity or []
            }

        return user_data
