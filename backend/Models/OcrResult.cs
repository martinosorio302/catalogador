namespace Catalogador.Api.Models;

public class OcrResult
{
    public required string LoteNombre { get; set; }
    public required List<DocumentoBase> Unidades { get; set; }
}
