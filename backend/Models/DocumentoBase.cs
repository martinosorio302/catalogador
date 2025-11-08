namespace Catalogador.Api.Models;

public class DocumentoBase
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string TipoUnidad { get; set; } = "Documento"; // "Expediente" | "Documento"
    public string? CodigoExpediente { get; set; }
    public string TituloAsunto { get; set; } = string.Empty;
    public string Serie { get; set; } = string.Empty;
    public string? Subserie { get; set; }
    public string? TipoDocumental { get; set; }
    public string Productor { get; set; } = string.Empty;
    public DateOnly FechaDoc { get; set; } = DateOnly.FromDateTime(DateTime.UtcNow);
    public DateOnly? FechaIni { get; set; }
    public DateOnly? FechaFin { get; set; }
    public int Folios { get; set; }
    public string Soporte { get; set; } = "Digital"; // Papel | Digital | Mixto
    public bool Confidencial { get; set; } = false;
    public string? UbicacionFisica { get; set; }
    public string ValorPrimario { get; set; } = "Administrativo";
    public string ValorSecundario { get; set; } = "Ninguno";
    public string Temporalidad { get; set; } = "Temporal"; // Temporal | Permanente
    public int PlazoConservacionAnios { get; set; } = 5;
    public string DestinoFinal { get; set; } = "Eliminación";
    public bool Validado { get; set; } = false;
    public string CreadoPor { get; set; } = "API";
    public DateTime CreadoEl { get; set; } = DateTime.UtcNow;
    public string? RevisadoPor { get; set; }
    public DateTime? RevisadoEl { get; set; }
}
