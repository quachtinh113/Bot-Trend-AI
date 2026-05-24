from abc import ABC, abstractmethod
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from core.schemas.trading import OrderRequest

class ExecutionResult(BaseModel):
    ticket: Optional[int] = None
    symbol: str
    volume: float
    status: str = Field(..., pattern="^(ACCEPTED|REJECTED)$")
    reason: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)

class ExecutionGateway(ABC):
    @abstractmethod
    def submit_order(self, order_request: OrderRequest, approved_by_risk: bool) -> ExecutionResult:
        """Submits an order for execution.
        
        Must require approved_by_risk = True to proceed, and reject otherwise.
        """
        pass
