from engine import trd


def classify_document_text(
    text: str,
    asuntoUnidad: str | None = None,  # noqa: N803
    titulo: str | None = None,
    productor: str | None = None,
):
    """Classify document text using TRD rules.

    Args:
        text: Document text content
        asuntoUnidad: Subject/organizational unit (camelCase per EsSalud spec)
        titulo: Document title
        productor: Document producer/creator

    Returns:
        Classification result dictionary
    """
    payload = {
        "asuntoUnidad": asuntoUnidad,
        "titulo": titulo,
        "productor": productor,
        "serie": None,
    }
    return trd.aplicar_reglas_trd(payload)
