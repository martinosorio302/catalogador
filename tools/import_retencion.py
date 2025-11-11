#!/usr/bin/env python3
"""Thin wrapper for the canonical import_retencion implementation.

This file delegates to `catalogador.tools.import_retencion` so we maintain a
single authoritative implementation while keeping `tools/import_retencion.py`
as a runnable script entrypoint for local development.
"""

from importlib import import_module


def main():
    mod = import_module("catalogador.tools.import_retencion")
    # Re-expose the module's main entrypoint
    if hasattr(mod, "main"):
        mod.main()
    else:
        raise RuntimeError("catalogador.tools.import_retencion has no main()")


if __name__ == "__main__":
    main()
        else:
            raw = []

    print(f"Loaded {len(raw)} records from {src}")

    normalized = [normalize_record(r) for r in raw]

    dest = Path(args.dest)
    dests = [dest]
    data_dir_env = os.getenv("DATA_DIR")
    if data_dir_env:
        data_dir_path = Path(data_dir_env) / dest.name
        dests.append(data_dir_path)
    repo_root_data = Path(__file__).resolve().parents[1] / "data" / dest.name
    dests.append(repo_root_data)

    try:
        write_multiple_atomic(normalized, dests)
        print("Wrote destinations:", ", ".join(str(d) for d in dests))
    except Exception as e:
        print("Failed to write destination files atomically:", e, file=sys.stderr)
        sys.exit(3)

    if not args.no_reload:
        ok = try_reload(host=args.reload_host, port=args.reload_port)
        if not ok:
            print(
                f"Reload to {args.reload_host}:{args.reload_port} failed; you can retry manually."
            )


if __name__ == "__main__":
    main()
