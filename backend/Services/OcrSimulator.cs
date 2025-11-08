using Catalogador.Api.Models;

namespace Catalogador.Api.Services;

public class OcrSimulator
{
    private readonly TrdService _trd;
    public OcrSimulator(TrdService trd) => _trd = trd;

    public OcrResult Analyze(string fileName)
    {
        var unidades = new List<DocumentoBase>
        {
            new DocumentoBase {
                Id = "EXP-2025-001",
                TipoUnidad = "Expediente",
                CodigoExpediente = "EXP-2025-001",
                TituloAsunto = "Contratación de servicio de digitalización",
                Serie = "Gestión Administrativa",
                Subserie = "Contrataciones",
                TipoDocumental = "Expediente",
                Productor = "Oficina de Logística",
                FechaDoc = new DateOnly(2025, 6, 10),
                FechaIni = new DateOnly(2025, 5, 2),
                FechaFin = new DateOnly(2025, 6, 28),
                Folios = 134,
                Soporte = "Mixto",
            },
            new DocumentoBase {
                Id = "DOC-2025-017",
                TipoUnidad = "Documento",
                CodigoExpediente = "EXP-2025-001",
                TituloAsunto = "Carta N° 123-2025-LOG: Solicita cotización",
                Serie = "Correspondencia",
                Subserie = "Cartas",
                TipoDocumental = "Carta",
                Productor = "Oficina de Logística",
                FechaDoc = new DateOnly(2025, 5, 3),
                Folios = 1,
                Soporte = "Digital",
            },
            new DocumentoBase {
                Id = "DOC-2025-018",
                TipoUnidad = "Documento",
                CodigoExpediente = "EXP-2025-001",
                TituloAsunto = "Oficio N° 045-2025-LOG: Remite TDR",
                Serie = "Correspondencia",
                Subserie = "Oficios",
                TipoDocumental = "Oficio",
                Productor = "Oficina de Logística",
                FechaDoc = new DateOnly(2025, 5, 12),
                Folios = 2,
                Soporte = "Digital",
            },
            new DocumentoBase {
                Id = "DOC-2025-019",
                TipoUnidad = "Documento",
                CodigoExpediente = "EXP-2025-001",
                TituloAsunto = "Resolución Jefatural N° 123-2025: Aprueba contratación",
                Serie = "Gestión Administrativa",
                Subserie = "Resoluciones",
                TipoDocumental = "Resolución",
                Productor = "Oficina General",
                FechaDoc = new DateOnly(2025, 6, 10),
                Folios = 3,
                Soporte = "Papel",
            },
            new DocumentoBase {
                Id = "EXP-2024-055",
                TipoUnidad = "Expediente",
                CodigoExpediente = "EXP-2024-055",
                TituloAsunto = "Actas del Comité de Archivo 2024",
                Serie = "Patrimonio Documental",
                Subserie = "Actas",
                TipoDocumental = "Expediente",
                Productor = "Archivo Central",
                FechaDoc = new DateOnly(2024, 12, 20),
                FechaIni = new DateOnly(2024, 1, 15),
                FechaFin = new DateOnly(2024, 12, 20),
                Folios = 87,
                Soporte = "Papel",
            }
        };

        foreach (var u in unidades)
        {
            var (plazo, temporalidad, destino) = _trd.Apply(u.Serie, u.Subserie, u.TipoDocumental);
            u.PlazoConservacionAnios = plazo;
            u.Temporalidad = temporalidad;
            u.DestinoFinal = destino;
        }

        return new OcrResult { LoteNombre = fileName, Unidades = unidades };
    }
}
