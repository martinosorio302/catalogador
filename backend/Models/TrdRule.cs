namespace Catalogador.Api.Models;

public class TrdRule
{
    public required string Serie { get; set; }
    public string? Subserie { get; set; }
    public string? Tipo { get; set; }
    public int Plazo { get; set; }
    public required string Temporalidad { get; set; } // Temporal | Permanente
    public required string Destino { get; set; } // Eliminación | Transferencia al Archivo Central | Conservación Permanente
}
