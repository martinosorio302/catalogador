"""Fail if there are test files inside the packaged package directory.

This prevents pytest import collisions where tests are both in the top-level
`tests/` directory and accidentally included inside the package, which causes
import-file-mismatch errors during test collection.

Exit code:
 - 0 if OK (no packaged tests)
 - 1 if packaged tests are found
"""
import os
import sys


def main() -> int:
    pkg_dir = os.path.join(os.path.dirname(__file__), os.pardir, "catalogador")
    pkg_dir = os.path.abspath(pkg_dir)
    if not os.path.isdir(pkg_dir):
        print(f"Package dir not found: {pkg_dir} — nothing to check.")
        return 0

    tests_path = os.path.join(pkg_dir, "tests")
    if os.path.exists(tests_path):
        print("ERROR: Found tests inside the package directory:")
        for root, dirs, files in os.walk(tests_path):
            for f in files:
                if f.endswith(".py"):
                    print(os.path.join(root, f))
        print("\nThis can cause pytest import collisions. Please keep tests/ at the repo root and out of the packaged package.")
        return 1

    print("OK: No packaged tests found.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
