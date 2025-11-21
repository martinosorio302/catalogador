using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace Catalogador.App.Services
{
    /// <summary>
    /// Servicio para generar y descargar inventarios Excel con análisis TRD/PCD
    /// </summary>
    public class InventarioService
    {
        private readonly HttpClient _client;
        private const string BASE_URL = "http://127.0.0.1:8001";
        
        public InventarioService()
        {
            _client = new HttpClient();
            _client.Timeout = TimeSpan.FromMinutes(5);
        }
        
        /// <summary>
        /// Genera un inventario Excel con 4 hojas según normativa EsSalud
        /// </summary>
        public async Task<string> GenerarInventarioExcel(List<DocumentoInventario> documentos, MetadataInventario? metadata = null)
        {
            if (metadata == null)
            {
                metadata = new MetadataInventario
                {
                    Entidad = "ESSALUD - Red Asistencial Sabogal",
                    Anio = DateTime.Now.Year.ToString(),
                    Responsable = Environment.UserName,
                    AreaProductora = "Dirección de Administración",
                    AreaDestino = "Archivo Central"
                };
            }
            
            var solicitud = new
            {
                documentos = documentos,
                metadata = new
                {
                    entidad = metadata.Entidad,
                    anio = metadata.Anio,
                    responsable = metadata.Responsable,
                    area_productora = metadata.AreaProductora,
                    area_destino = metadata.AreaDestino
                }
            };
            
            var json = JsonSerializer.Serialize(solicitud, new JsonSerializerOptions 
            { 
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase 
            });
            
            var content = new StringContent(json, Encoding.UTF8, "application/json");
            
            try
            {
                var response = await _client.PostAsync(
                    $"{BASE_URL}/api/inventario/generar-inventario", 
                    content
                );
                
                if (!response.IsSuccessStatusCode)
                {
                    var error = await response.Content.ReadAsStringAsync();
                    throw new HttpRequestException($"Error del servidor: {response.StatusCode} - {error}");
                }
                
                var resultado = await response.Content.ReadAsStringAsync();
                var doc = JsonDocument.Parse(resultado);
                
                if (doc.RootElement.TryGetProperty("file_path", out var filePathProp))
                {
                    var fullPath = filePathProp.GetString() ?? string.Empty;
                    return System.IO.Path.GetFileName(fullPath);
                }
                
                throw new Exception("Respuesta del servidor no contiene el nombre del archivo");
            }
            catch (HttpRequestException ex)
            {
                throw new Exception($"Servicio de inventario no disponible. Verifique que el backend esté corriendo en {BASE_URL}.", ex);
            }
            catch (TaskCanceledException)
            {
                throw new Exception("Tiempo de espera agotado generando el inventario. El archivo puede ser muy grande.");
            }
        }
        
        /// <summary>
        /// Descarga el archivo Excel generado
        /// </summary>
        public async Task<byte[]> DescargarExcel(string nombreArchivo)
        {
            try
            {
                var response = await _client.GetAsync(
                    $"{BASE_URL}/api/inventario/descargar-inventario/{nombreArchivo}"
                );
                
                if (!response.IsSuccessStatusCode)
                {
                    if (response.StatusCode == System.Net.HttpStatusCode.NotFound)
                    {
                        throw new Exception($"Archivo '{nombreArchivo}' no encontrado en el servidor");
                    }
                    var error = await response.Content.ReadAsStringAsync();
                    throw new HttpRequestException($"Error descargando archivo: {response.StatusCode} - {error}");
                }
                
                return await response.Content.ReadAsByteArrayAsync();
            }
            catch (HttpRequestException ex)
            {
                throw new Exception($"No se pudo conectar con el servicio de inventario en {BASE_URL}.", ex);
            }
            catch (TaskCanceledException)
            {
                throw new Exception("Tiempo de espera agotado descargando el archivo.");
            }
        }
        
        /// <summary>
        /// Analiza un documento y devuelve su clasificación TRD
        /// </summary>
        public async Task<ClasificacionTRD> AnalizarDocumento(string textoDocumento)
        {
            var payload = new { texto_documento = textoDocumento };
            var json = JsonSerializer.Serialize(payload);
            var content = new StringContent(json, Encoding.UTF8, "application/json");
            
            var response = await _client.PostAsync(
                $"{BASE_URL}/api/inventario/analizar-documento",
                content
            );
            
            response.EnsureSuccessStatusCode();
            var resultado = await response.Content.ReadAsStringAsync();
            return JsonSerializer.Deserialize<ClasificacionTRD>(resultado, new JsonSerializerOptions 
            { 
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase 
            }) ?? new ClasificacionTRD();
        }
        
        /// <summary>
        /// Obtiene todas las series TRD disponibles
        /// </summary>
        public async Task<List<SerieTRD>> ObtenerSeriesTRD()
        {
            var response = await _client.GetAsync($"{BASE_URL}/api/inventario/trd/series");
            response.EnsureSuccessStatusCode();
            
            var resultado = await response.Content.ReadAsStringAsync();
            return JsonSerializer.Deserialize<List<SerieTRD>>(resultado, new JsonSerializerOptions 
            { 
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase 
            }) ?? new List<SerieTRD>();
        }
        
        /// <summary>
        /// Verifica el estado del servicio de inventario
        /// </summary>
        public async Task<bool> VerificarEstado()
        {
            try
            {
                var response = await _client.GetAsync($"{BASE_URL}/api/inventario/health");
                return response.IsSuccessStatusCode;
            }
            catch
            {
                return false;
            }
        }
    }
    
    /// <summary>
    /// Modelo de documento para inventario
    /// </summary>
    public class DocumentoInventario
    {
        public int numero_orden { get; set; }
        public string codigo_referencia { get; set; } = string.Empty;
        public string nombre_archivo { get; set; } = string.Empty;
        public string serie_documental { get; set; } = string.Empty;
        public string codigo_trd { get; set; } = string.Empty;
        public string fecha_documento { get; set; } = string.Empty;
        public int numero_folios { get; set; }
        public string soporte { get; set; } = string.Empty;
        public string ubicacion_fisica { get; set; } = string.Empty;
        public int plazo_gestion { get; set; }
        public int plazo_central { get; set; }
        public string disposicion_final { get; set; } = string.Empty;
        public string observaciones { get; set; } = string.Empty;
    }
    
    /// <summary>
    /// Metadata del inventario
    /// </summary>
    public class MetadataInventario
    {
        public string Entidad { get; set; } = string.Empty;
        public string Anio { get; set; } = string.Empty;
        public string Responsable { get; set; } = string.Empty;
        public string AreaProductora { get; set; } = string.Empty;
        public string AreaDestino { get; set; } = string.Empty;
    }
    
    /// <summary>
    /// Clasificación TRD de un documento
    /// </summary>
    public class ClasificacionTRD
    {
        public string CodigoTrd { get; set; } = string.Empty;
        public string TituloSerie { get; set; } = string.Empty;
        public string Subserie { get; set; } = string.Empty;
        public string Asunto { get; set; } = string.Empty;
        public double Confianza { get; set; }
        public int PlazoGestion { get; set; }
        public int PlazoCentral { get; set; }
        public string DisposicionFinal { get; set; } = string.Empty;
        public List<string>? KeywordsDetectadas { get; set; }
        public string? FragmentoRelevante { get; set; }
    }
    
    /// <summary>
    /// Serie TRD
    /// </summary>
    public class SerieTRD
    {
        public string Codigo { get; set; } = string.Empty;
        public string TituloSerie { get; set; } = string.Empty;
        public string Asunto { get; set; } = string.Empty;
        public int PlazoAg { get; set; }
        public int PlazoAp { get; set; }
        public int PlazoOaa { get; set; }
        public string Temporalidad { get; set; } = string.Empty;
        public string Destino { get; set; } = string.Empty;
    }
}
