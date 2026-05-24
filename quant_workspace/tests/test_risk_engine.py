import pytest
from core.schemas.trading import AccountState, OrderRequest
from risk.risk_engine import ConstitutionalRiskEngine

@pytest.fixture
def risk_engine():
    return ConstitutionalRiskEngine(daily_dd_limit=2.0, weekly_dd_limit=5.0, hard_kill_dd_limit=8.0)

def test_safe_order_approval(risk_engine):
    account = AccountState(
        login=12345,
        server="TestServer",
        balance=10000.0,
        equity=10000.0,
        margin=0.0,
        margin_level=9999.0,
        weekly_starting_equity=10000.0,
        daily_starting_equity=10000.0
    )
    order = OrderRequest(
        symbol="XAUUSDm",
        order_type="BUY",
        volume=0.1,
        price=2000.0,
        magic_number=99999
    )
    approved, reason, adjustments = risk_engine.evaluate_order(account, order)
    assert approved is True
    assert reason == "Order approved"
    assert adjustments["lot_scale"] == 1.0

def test_hard_kill_drawdown_veto(risk_engine):
    account = AccountState(
        login=12345,
        server="TestServer",
        balance=10000.0,
        equity=9100.0,  # 9% weekly drawdown (> 8.0%)
        margin=1000.0,
        margin_level=910.0,
        weekly_starting_equity=10000.0,
        daily_starting_equity=10000.0
    )
    order = OrderRequest(
        symbol="XAUUSDm",
        order_type="BUY",
        volume=0.1,
        price=2000.0,
        magic_number=99999
    )
    approved, reason, adjustments = risk_engine.evaluate_order(account, order)
    assert approved is False
    assert "HARD_KILL" in reason

def test_safe_mode_basket_veto_and_dca_approval(risk_engine):
    account = AccountState(
        login=12345,
        server="TestServer",
        balance=10000.0,
        equity=9600.0,  # 4% weekly drawdown (SAFE_MODE state)
        margin=1000.0,
        margin_level=940.0,
        weekly_starting_equity=10000.0,
        daily_starting_equity=9650.0  # daily drawdown 50/9650 = 0.52% (< 2.0%)
    )
    
    # New base basket order should be VETOED in SAFE_MODE
    order_base = OrderRequest(
        symbol="XAUUSDm",
        order_type="BUY",
        volume=0.1,
        price=2000.0,
        magic_number=99999,
        is_dca=False
    )
    approved_base, reason_base, _ = risk_engine.evaluate_order(account, order_base)
    assert approved_base is False
    assert "SAFE_MODE blocks new basket orders" in reason_base
    
    # DCA recovery order should be APPROVED but scaled
    order_dca = OrderRequest(
        symbol="XAUUSDm",
        order_type="BUY",
        volume=0.1,
        price=2000.0,
        magic_number=99999,
        is_dca=True
    )
    approved_dca, reason_dca, adjustments = risk_engine.evaluate_order(account, order_dca)
    assert approved_dca is True
    assert adjustments["lot_scale"] == 0.40
    assert adjustments["spacing_scale"] == 2.00

def test_low_margin_dca_veto(risk_engine):
    account = AccountState(
        login=12345,
        server="TestServer",
        balance=10000.0,
        equity=10000.0,
        margin=4000.0,
        margin_level=250.0,  # <= 300% Margin Level
        weekly_starting_equity=10000.0,
        daily_starting_equity=10000.0
    )
    order_dca = OrderRequest(
        symbol="XAUUSDm",
        order_type="BUY",
        volume=0.1,
        price=2000.0,
        magic_number=99999,
        is_dca=True
    )
    approved, reason, _ = risk_engine.evaluate_order(account, order_dca)
    assert approved is False
    assert "Margin level is dangerously low" in reason

def test_lot_size_veto(risk_engine):
    account = AccountState(
        login=12345,
        server="TestServer",
        balance=10000.0,
        equity=10000.0,
        margin=0.0,
        margin_level=9999.0,
        weekly_starting_equity=10000.0,
        daily_starting_equity=10000.0
    )
    order = OrderRequest(
        symbol="XAUUSDm",
        order_type="BUY",
        volume=6.0,  # Exceeds 5.0 lots cap
        price=2000.0,
        magic_number=99999
    )
    approved, reason, _ = risk_engine.evaluate_order(account, order)
    assert approved is False
    assert "exceeds sovereign unidirectional lot cap" in reason
