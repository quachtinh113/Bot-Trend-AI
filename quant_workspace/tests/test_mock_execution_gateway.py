import pytest
from core.schemas.trading import OrderRequest
from execution.mock_gateway import MockExecutionGateway

@pytest.fixture
def mock_gateway():
    return MockExecutionGateway()

def test_approved_order_is_accepted(mock_gateway):
    order = OrderRequest(
        symbol="XAUUSDm",
        order_type="BUY",
        volume=0.1,
        price=2000.0,
        magic_number=99999
    )
    result = mock_gateway.submit_order(order, approved_by_risk=True)
    assert result.status == "ACCEPTED"
    assert result.ticket is not None
    assert "filled successfully" in result.reason

def test_vetoed_order_is_rejected(mock_gateway):
    order = OrderRequest(
        symbol="XAUUSDm",
        order_type="BUY",
        volume=0.1,
        price=2000.0,
        magic_number=99999
    )
    result = mock_gateway.submit_order(order, approved_by_risk=False)
    assert result.status == "REJECTED"
    assert result.ticket is None
    assert "Vetoed by sovereign Sentinel" in result.reason
