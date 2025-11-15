import os
import sys
from pathlib import Path

# Ensure pytest uses a writable temp directory inside the repository so
# Windows permission issues on the user's global Temp don't block tests.
repo_root = Path(__file__).resolve().parents[1]
_pytest_tmp = repo_root / ".pytest_tmp"
try:
    _pytest_tmp.mkdir(parents=True, exist_ok=True)
    # Quick writability test
    testf = _pytest_tmp / ".writable_test"
    with testf.open("w") as _f:
        _f.write("ok")
    testf.unlink()
except Exception:
    # Fallback to a different local temp dir if .pytest_tmp is not usable
    _pytest_tmp = repo_root / ".pytest_work"
    _pytest_tmp.mkdir(parents=True, exist_ok=True)

# Point common temp env vars to the repo-local tmp so tempfile.gettempdir()
# and pytest's tmpdir/tmp_path_factory pick a writable location.
os.environ.setdefault("TMP", str(_pytest_tmp))
os.environ.setdefault("TEMP", str(_pytest_tmp))
os.environ.setdefault("TMPDIR", str(_pytest_tmp))

# Make sure the repository root is first on sys.path so local packages
# (`tools`, `engine`, etc.) are resolved before any same-named site-packages.
sys.path.insert(0, str(repo_root))


def pytest_configure(config):
    # Also try to set pytest's basetemp option to the same path so pytest
    # creates its numbered directories there instead of under the system temp.
    try:
        config.option.basetemp = str(_pytest_tmp)
    except Exception:
        # If pytest internals change, this is best-effort only.
        pass
