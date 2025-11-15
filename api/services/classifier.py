import logging

from engine import trd

logger = logging.getLogger(__name__)


def classify_document_text(
    text: str,
    asuntoUnidad: str | None = None,  # noqa: N803
    titulo: str | None = None,
    productor: str | None = None,
):
    """Classify document text using TRD rules.

    Args:
        text: Document text content (currently not used directly,
              but available for future enhancements)
        asuntoUnidad: Subject/organizational unit (camelCase per EsSalud spec)
        titulo: Document title
        productor: Document producer/creator

    Returns:
        Classification result dictionary with code, title, retention period
    """
    payload = {
        "asuntoUnidad": asuntoUnidad or "",
        "titulo": titulo or text[:500] if text else "",  # Fallback to text excerpt
        "productor": productor or "",
        "serie": None,
    }

    try:
        result = trd.aplicar_reglas_trd(payload)
        logger.debug(
            "Classification result for asunto=%s: code=%s",
            asuntoUnidad,
            result.get("code"),
        )
        return result
    except Exception as e:
        logger.exception("Classification failed for payload %s", payload)
        # Return safe fallback
        return {
            "code": None,
            "tituloSerie": "Error de clasificación",
            "plazoConservacionAnios": 0,
            "temporalidad": "Unknown",
            "destino": "Requiere revisión manual",
            "error": str(e),
        }
