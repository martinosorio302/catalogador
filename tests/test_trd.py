import unittest
from engine import trd


class TestTRD(unittest.TestCase):
    def test_sample_match(self):
        inp = {
            "asuntoUnidad": "CONSEJO DIRECTIVO",
            "titulo": "Actas de sesiones",
            "serie": "Actas",
        }
        out = trd.aplicar_reglas_trd(inp)
        self.assertEqual(out["code"], "CODI/01")
        self.assertEqual(out["temporalidad"], "Permanente")

    def test_fallback(self):
        inp = {
            "asuntoUnidad": "UNIDAD DESCONOCIDA",
            "titulo": "Carta",
            "serie": "Correspondencia",
        }
        out = trd.aplicar_reglas_trd(inp)
        self.assertIsNone(out["code"])
        self.assertEqual(out["temporalidad"], "Temporal")


if __name__ == "__main__":
    unittest.main()
