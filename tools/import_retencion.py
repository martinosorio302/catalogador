#!/usr/bin/env python3
"""Small wrapper that delegates to the canonical implementation under
`catalogador.tools.import_retencion` to avoid duplication.
"""

from catalogador.tools.import_retencion import main


if __name__ == "__main__":
    main()
