from pydantic import BaseModel, Field
from datetime import datetime

class SignalProposal(BaseModel):
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    symbol: str
    direction: str = Field(..., pattern="^(BUY|SELL)$")
    suggested_volume: float = Field(..., gt=0.0)
    market_regime: str = Field(..., pattern="^(TRENDING|RANGING|TRANSITION)$")
    trigger_reason: str
