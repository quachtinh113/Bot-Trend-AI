from abc import ABC, abstractmethod
from typing import Dict, Any
from core.dto.signals import SignalProposal

class StrategyContract(ABC):
    @abstractmethod
    def generate_signal(self, context: Dict[str, Any]) -> SignalProposal:
        """Generates a raw SignalProposal based on market context.
        
        Must not execute trades, access the live broker, or modify risk limits.
        """
        pass
