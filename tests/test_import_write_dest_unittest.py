import json
import unittest
from pathlib import Path

from tools import import_retencion as ir


class TestImportWriteDest(unittest.TestCase):
    def test_write_dest_atomic(self):
        # Use actual behavior; exercise write_dest
        records = [{
            "fondo": "A",
            "codigo": "X/01",
            "titulo": "Test",
            "valor": "TEMPORAL",
            "retencion": {"gestion": 1, "periferico": 0, "central": 0, "total": 1}
        }]
        tmpdir = Path.cwd() / 'tmp_test_write_dest'
        tmpdir.mkdir(parents=True, exist_ok=True)
        dest = tmpdir / 'out.json'
        try:
            ir.write_dest(records, dest)
            self.assertTrue(dest.exists())
            with dest.open('r', encoding='utf-8') as f:
                data = json.load(f)
            self.assertEqual(data, records)

            # overwrite
            records2 = [{
                "fondo": "B",
                "codigo": "Y/02",
                "titulo": "Test2",
                "valor": "PERMANENTE",
                "retencion": {"gestion": 2, "periferico": 1, "central": 0, "total": 3}
            }]
            ir.write_dest(records2, dest)
            with dest.open('r', encoding='utf-8') as f:
                data2 = json.load(f)
            self.assertEqual(data2, records2)
        finally:
            try:
                for p in tmpdir.iterdir():
                    p.unlink()
                tmpdir.rmdir()
            except Exception:
                pass


if __name__ == '__main__':
    unittest.main()
