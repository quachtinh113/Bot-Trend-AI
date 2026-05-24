from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class AccountState(BaseModel):
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    login: int
    server: str
    balance: float = Field(..., ge=0.0)
    equity: float = Field(..., ge=0.0)
    margin: float = Field(..., ge=0.0)
    margin_level: float = Field(..., ge=0.0)
    weekly_starting_equity: float = Field(..., ge=0.0)
    daily_starting_equity: float = Field(..., ge=0.0)

class OrderRequest(BaseModel):
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    symbol: str
    order_type: str = Field(..., pattern="^(BUY|SELL)$")
    volume: float = Field(..., gt=0.0)
    price: float = Field(..., gt=0.0)
    sl: Optional[float] = None
    tp: Optional[float] = None
    magic_number: int
    is_dca: bool = False
