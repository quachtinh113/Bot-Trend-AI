from typing import Tuple, Dict, Any
from core.schemas.trading import AccountState, OrderRequest
import structlog

logger = structlog.get_logger()

class ConstitutionalRiskEngine:
    def __init__(self, daily_dd_limit: float = 2.0, weekly_dd_limit: float = 5.0, hard_kill_dd_limit: float = 8.0):
        self.daily_dd_limit = daily_dd_limit
        self.weekly_dd_limit = weekly_dd_limit
        self.hard_kill_dd_limit = hard_kill_dd_limit
        
    def evaluate_account_safety(self, account: AccountState) -> Tuple[str, float]:
        """Calculates Survival Score (0-100) and returns current Risk State."""
        score = 100.0
        
        # 1. Weekly Drawdown
        weekly_dd = 0.0
        if account.weekly_starting_equity > 0:
            loss = account.weekly_starting_equity - account.equity
            if loss > 0:
                weekly_dd = (loss / account.weekly_starting_equity) * 100.0
                
        # 2. Daily Drawdown
        daily_dd = 0.0
        if account.daily_starting_equity > 0:
            loss = account.daily_starting_equity - account.equity
            if loss > 0:
                daily_dd = (loss / account.daily_starting_equity) * 100.0
                
        # Apply deductions based on weekly drawdown limits
        if weekly_dd >= self.hard_kill_dd_limit:
            score = 10.0
        elif weekly_dd >= self.weekly_dd_limit:
            score = 24.0
        elif weekly_dd >= 3.0:
            score = 39.0
        elif weekly_dd > 0.0:
            score = 95.0 - (weekly_dd / 3.0) * 55.0

        # Daily drawdown deductions
        if daily_dd >= self.daily_dd_limit:
            score -= 30.0
            
        # Margin level deductions
        if account.margin_level > 0.0:
            if account.margin_level <= 180.0:
                score = 5.0
            elif account.margin_level <= 250.0:
                score -= 40.0
            elif account.margin_level <= 300.0:
                score -= 15.0
            elif account.margin_level <= 500.0:
                score -= 5.0

        if score < 0.0:
            score = 0.0
        if score > 100.0:
            score = 100.0

        # State categorization
        if score < 15.0:
            return "HARD_KILL", score
        elif score < 25.0:
            return "HARD_BLOCK", score
        elif score < 40.0:
            return "SAFE_MODE", score
        elif score < 60.0:
            return "REDUCE_RISK", score
        return "NORMAL", score

    def evaluate_order(self, account: AccountState, order: OrderRequest) -> Tuple[bool, str, Dict[str, Any]]:
        """Evaluates whether an order request is approved or vetoed by the risk rules."""
        state, score = self.evaluate_account_safety(account)
        
        veto = False
        reason = "Order approved"
        adjustments = {
            "lot_scale": 1.0,
            "spacing_scale": 1.0
        }
        
        # Check absolute veto constraints
        if state == "HARD_KILL":
            veto = True
            reason = f"VETO: Account is in HARD_KILL status (Survival Score: {score:.1f})."
        elif state == "HARD_BLOCK":
            veto = True
            reason = f"VETO: Account is in HARD_BLOCK status (Survival Score: {score:.1f})."
        elif state == "SAFE_MODE":
            if not order.is_dca:
                veto = True
                reason = "VETO: SAFE_MODE blocks new basket orders. Only DCA recovery is allowed."
            else:
                adjustments["lot_scale"] = 0.40
                adjustments["spacing_scale"] = 2.00
        elif state == "REDUCE_RISK":
            adjustments["lot_scale"] = 0.60
            adjustments["spacing_scale"] = 1.50
            
        # Specific margin rules (Article 2)
        if account.margin_level > 0.0:
            if account.margin_level <= 300.0 and order.is_dca:
                veto = True
                reason = f"VETO: Margin level is dangerously low ({account.margin_level:.1f}%), blocking all DCA nhồi lệnh."
                
        # Specific lot size threshold
        if order.volume > 5.0:
            veto = True
            reason = f"VETO: Order volume ({order.volume:.1f} lots) exceeds sovereign unidirectional lot cap."

        # Audit logging
        logger.info(
            "order_risk_audit",
            symbol=order.symbol,
            order_type=order.order_type,
            volume=order.volume,
            is_dca=order.is_dca,
            veto=veto,
            reason=reason,
            survival_score=score,
            survival_state=state,
            margin_level=account.margin_level
        )
        
        return not veto, reason, adjustments
