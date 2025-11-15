"""
Test suite for GET /trd-info endpoint.

Tests the TRD information and statistics endpoint to ensure it returns
correct data structure and accurate statistics about the TRD table.
"""

import importlib
import sys

from fastapi.testclient import TestClient

sys.path.insert(
    0,
    str(importlib.util.find_spec("api").loader.path if importlib.util.find_spec("api") else "."),
)
from api.main import app
from engine import trd


def test_trd_info_returns_200():
    """Test that /trd-info endpoint returns 200 OK."""
    client = TestClient(app)
    response = client.get("/trd-info")
    assert response.status_code == 200


def test_trd_info_structure():
    """Test that /trd-info returns expected JSON structure."""
    client = TestClient(app)
    response = client.get("/trd-info")
    data = response.json()

    # Verify all required fields are present
    assert "total_entries" in data
    assert "total_codes" in data
    assert "sample_entries" in data
    assert "index_tokens" in data
    assert "inventory_descriptions" in data


def test_trd_info_data_types():
    """Test that /trd-info fields have correct data types."""
    client = TestClient(app)
    response = client.get("/trd-info")
    data = response.json()

    assert isinstance(data["total_entries"], int)
    assert isinstance(data["total_codes"], int)
    assert isinstance(data["sample_entries"], list)
    assert isinstance(data["index_tokens"], int)
    assert isinstance(data["inventory_descriptions"], int)


def test_trd_info_total_entries_matches_actual():
    """Test that total_entries matches actual TRD_TABLA length."""
    client = TestClient(app)
    response = client.get("/trd-info")
    data = response.json()

    expected_total = len(trd.TRD_TABLA)
    assert data["total_entries"] == expected_total


def test_trd_info_sample_entries_limit():
    """Test that sample_entries returns at most 5 entries."""
    client = TestClient(app)
    response = client.get("/trd-info")
    data = response.json()

    assert len(data["sample_entries"]) <= 5


def test_trd_info_sample_entries_structure():
    """Test that sample_entries have expected structure."""
    client = TestClient(app)
    response = client.get("/trd-info")
    data = response.json()

    if len(data["sample_entries"]) > 0:
        sample = data["sample_entries"][0]
        # Each sample entry should be a dict (TRD entry format)
        assert isinstance(sample, dict)


def test_trd_info_codes_count_validation():
    """Test that total_codes reflects unique codes in TRD_TABLA."""
    client = TestClient(app)
    response = client.get("/trd-info")
    data = response.json()

    # Count unique codes from actual TRD_TABLA
    unique_codes = {
        entry.get("code") for entry in trd.TRD_TABLA if entry.get("code")
    }
    expected_unique_count = len(unique_codes)

    assert data["total_codes"] == expected_unique_count


def test_trd_info_index_tokens_validation():
    """Test that index_tokens matches actual INDICE_TOKENS length."""
    client = TestClient(app)
    response = client.get("/trd-info")
    data = response.json()

    expected_index_tokens = len(trd.INDICE_TOKENS)
    assert data["index_tokens"] == expected_index_tokens


def test_trd_info_inventory_descriptions_validation():
    """Test that inventory_descriptions matches actual INVENTARIO_DESCRIPCION."""
    client = TestClient(app)
    response = client.get("/trd-info")
    data = response.json()

    expected_inventory_count = len(trd.INVENTARIO_DESCRIPCION)
    assert data["inventory_descriptions"] == expected_inventory_count


def test_trd_info_consistency_after_reload():
    """Test that /trd-info returns consistent data after data reload."""
    client = TestClient(app)

    # Get initial state
    response1 = client.get("/trd-info")
    data1 = response1.json()

    # Get state again (without actual reload, just verify idempotency)
    response2 = client.get("/trd-info")
    data2 = response2.json()

    # Should be identical
    assert data1 == data2


def test_trd_info_performance():
    """Test that /trd-info responds within acceptable time (< 500ms)."""
    import time

    client = TestClient(app)

    start = time.time()
    response = client.get("/trd-info")
    elapsed = time.time() - start

    assert response.status_code == 200
    # Should respond quickly (under 500ms)
    assert elapsed < 0.5, f"Response took {elapsed:.3f}s, expected < 0.5s"


def test_trd_info_no_auth_required():
    """Test that /trd-info does not require authentication."""
    client = TestClient(app)

    # Call without any headers
    response = client.get("/trd-info")

    # Should work without auth
    assert response.status_code == 200
