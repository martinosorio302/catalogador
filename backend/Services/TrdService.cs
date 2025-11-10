using Catalogador.Api.Models;

namespace Catalogador.Api.Services;

public class TrdService
{
    private readonly List<TrdRule> _rules = new()
    {
        new TrdRule { Serie = "Correspondencia", Subserie = "Cartas", Tipo = "Carta", Plazo = 5, Temporalidad = "Temporal", Destino = "Eliminación" },
        new TrdRule { Serie = "Correspondencia", Subserie = "Oficios", Tipo = "Oficio", Plazo = 5, Temporalidad = "Temporal", Destino = "Eliminación" },
        new TrdRule { Serie = "Gestión Administrativa", Subserie = "Resoluciones", Tipo = "Resolución", Plazo = 10, Temporalidad = "Temporal", Destino = "Transferencia al Archivo Central" },
        new TrdRule { Serie = "Gestión Clínica", Subserie = "Historias Clínicas", Tipo = "Historia Clínica", Plazo = 20, Temporalidad = "Temporal", Destino = "Transferencia al Archivo Central" },
        new TrdRule { Serie = "Patrimonio Documental", Subserie = "Actas", Tipo = "Acta", Plazo = 0, Temporalidad = "Permanente", Destino = "Conservación Permanente" }
    };

    public (int plazo, string temporalidad, string destino) Apply(string serie, string? subserie, string? tipo)
    {
        var rule = _rules.FirstOrDefault(r => r.Serie == serie &&
                   (r.Subserie == null || r.Subserie == subserie) &&
                   (r.Tipo == null || r.Tipo == tipo));
        if (rule is null) return (5, "Temporal", "Eliminación");
        return (rule.Plazo, rule.Temporalidad, rule.Destino);
    }

    public IEnumerable<TrdRule> GetAll() => _rules;
}
