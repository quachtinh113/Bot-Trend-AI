from core.contracts.execution import ExecutionGateway, ExecutionResult
from core.schemas.trading import OrderRequest
from datetime import datetime
import structlog
import random

logger = structlog.get_logger()

class MockExecutionGateway(ExecutionGateway):
    def __init__(self):
        self._ticket_counter = 10000000

    def submit_order(self, order_request: OrderRequest, approved_by_risk: bool) -> ExecutionResult:
        """Simulates pure mechanical order placement.
        
        Requires approved_by_risk = True, otherwise rejects automatically.
        """
        if not approved_by_risk:
            reason = "REJECTED: Vetoed by sovereign Sentinel Risk Engine."
            logger.warn(
                "order_execution_failed",
                symbol=order_request.symbol,
                volume=order_request.volume,
                reason=reason
            )
            return ExecutionResult(
                symbol=order_request.symbol,
                volume=order_request.volume,
                status="REJECTED",
                reason=reason,
                timestamp=datetime.utcnow()
            )

        # Approved by risk: simulate successful mechanical execution
        self._ticket_counter += 1
        ticket = self._ticket_counter
        reason = "ACCEPTED: Order filled successfully by mock exchange liquidity."
        
        logger.info(
            "order_execution_success",
            symbol=order_request.symbol,
            volume=order_request.volume,
            ticket=ticket,
            reason=reason
        )
        
        return ExecutionResult(
            ticket=ticket,
            symbol=order_request.symbol,
            volume=order_request.volume,
            status="ACCEPTED",
            reason=reason,
            timestamp=datetime.utcnow()
        )
