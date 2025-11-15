from tools import import_retencion
import tempfile


def test_write_multiple_atomic_partial_failure(monkeypatch, tmp_path):
    records = [{"a": 1}]
    d1 = tmp_path / "a" / "out.json"
    d2 = tmp_path / "b" / "out.json"
    calls = {"n": 0}
    real_mkstemp = tempfile.mkstemp

    def fake_mkstemp(*args, **kwargs):
        calls["n"] += 1
        if calls["n"] == 2:
            raise RuntimeError("simulated write failure")
        return real_mkstemp(*args, **kwargs)

    monkeypatch.setattr(tempfile, "mkstemp", fake_mkstemp)
    try:
        try:
            import_retencion.write_multiple_atomic(records, [d1, d2])
            assert False, "should have failed"
        except RuntimeError:
            pass
        # confirm no partial destination files exist
        assert not d1.exists()
        assert not d2.exists()
    finally:
        # restore monkeypatch in case
        monkeypatch.setattr(tempfile, "mkstemp", real_mkstemp)
