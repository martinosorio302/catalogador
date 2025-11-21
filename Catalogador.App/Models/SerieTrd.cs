using System;

namespace Catalogador.App.Models
{
    /// <summary>
    /// Modelo para una serie documental del TRD de EsSalud
    /// </summary>
    public class SerieTrd
    {
        /// <summary>
        /// Código de la serie (ej: CODI/01)
        /// </summary>
        public string Codigo { get; set; }

        /// <summary>
        /// Título de la serie documental
        /// </summary>
        public string TituloSerie { get; set; }

        /// <summary>
        /// Asunto o contexto de la serie
        /// </summary>
        public string Asunto { get; set; }

        /// <summary>
        /// Plazo de retención en Archivo de Gestión (años)
        /// </summary>
        public int PlazoAG { get; set; }

        /// <summary>
        /// Plazo de retención en Archivo Periférico (años)
        /// </summary>
        public int PlazoAP { get; set; }

        /// <summary>
        /// Plazo de retención en Archivo Central (años)
        /// </summary>
        public int PlazoOAA { get; set; }

        /// <summary>
        /// Temporalidad total (ej: "30 años")
        /// </summary>
        public string Temporalidad { get; set; }

        /// <summary>
        /// Destino final del documento
        /// </summary>
        public string Destino { get; set; }

        /// <summary>
        /// Indica si es de conservación permanente
        /// </summary>
        public bool EsPermanente => Destino?.Contains("Conservación Total", StringComparison.OrdinalIgnoreCase) ?? false;

        /// <summary>
        /// Total de años de retención
        /// </summary>
        public int TotalAnios
        {
            get
            {
                if (string.IsNullOrEmpty(Temporalidad))
                    return 0;

                var parts = Temporalidad.Split(' ');
                if (parts.Length > 0 && int.TryParse(parts[0], out int anios))
                    return anios;

                return 0;
            }
        }
    }

    /// <summary>
    /// Respuesta del endpoint /api/inventario/trd/series
    /// </summary>
    public class ResponseSeriesTrd
    {
        public bool Success { get; set; }
        public int TotalSeries { get; set; }
        public string VersionTrd { get; set; }
        public SerieTrd[] Series { get; set; }
    }
}
