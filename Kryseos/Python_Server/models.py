from sqlalchemy import Column, String, JSON
from sqlalchemy.ext.mutable import MutableList
from sqlalchemy.orm import declarative_base

Base = declarative_base()

class User(Base):
    __tablename__ = "users"

    user_id = Column(String, primary_key=True, index=True)
    api_key = Column(String, nullable=False)     # 🔐 Encrypted API key
    api_secret = Column(String, nullable=False)  # 🔐 Encrypted API secret
    account = Column(String, nullable=False)
    equity = Column(MutableList.as_mutable(JSON), default=list)  # ✅ Equity history
