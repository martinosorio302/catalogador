using System;
using System.IO;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;
using Catalogador.App.Models;
using CatalogadorEsSalud.Models;

namespace CatalogadorEsSalud.Services
{
    public class ApiClient
    {
        private static ApiClient? _instance;
        private static readonly object _lock = new object();
        
        private readonly HttpClient _httpClient;
        public string? BaseUrl { get; private set; }

        private ApiClient()
        {
            _httpClient = new HttpClient
            {
                Timeout = TimeSpan.FromMinutes(5)
            };
            
            // Try to detect backend URL
            BaseUrl = DetectBackendUrl();
            _httpClient.BaseAddress = new Uri(BaseUrl);
        }

        public static ApiClient Instance
        {
            get
            {
                if (_instance == null)
                {
                    lock (_lock)
                    {
                        if (_instance == null)
                        {
                            _instance = new ApiClient();
                        }
                    }
                }
                return _instance;
            }
        }

        private string LoadBackendUrlFromConfig()
        {
            // Try to load from centralized config/backend.config.json
            // Priority order:
            // 1. Environment variable CATALOGADOR_BACKEND_PORT
            // 2. config/backend.config.json
            // 3. Hardcoded fallback
            
            // Check environment variable first
            var envPort = Environment.GetEnvironmentVariable("CATALOGADOR_BACKEND_PORT");
            if (!string.IsNullOrEmpty(envPort) && int.TryParse(envPort, out var port))
            {
                Helpers.SimpleLogger.Instance.Info($"Using backend port from environment: {port}");
                return $"http://127.0.0.1:{port}";
            }
            
            // Try to load from config file
            try
            {
                var baseDir = AppDomain.CurrentDomain.BaseDirectory;
                var configPath = Path.Combine(baseDir, "..", "..", "config", "backend.config.json");
                
                // Try alternative path if first doesn't exist
                if (!File.Exists(configPath))
                {
                    configPath = Path.Combine(baseDir, "..", "config", "backend.config.json");
                }
                
                if (File.Exists(configPath))
                {
                    var configJson = File.ReadAllText(configPath);
                    var config = JsonSerializer.Deserialize<BackendConfig>(configJson, new JsonSerializerOptions
                    {
                        PropertyNameCaseInsensitive = true
                    });
                    
                    if (config?.Backend != null)
                    {
                        var configUrl = $"{config.Backend.Protocol}://{config.Backend.Host}:{config.Backend.Port}";
                        Helpers.SimpleLogger.Instance.Info($"Loaded backend URL from config: {configUrl}");
                        return configUrl;
                    }
                }
            }
            catch (Exception ex)
            {
                Helpers.SimpleLogger.Instance.Info($"Failed to load config file: {ex.Message}");
            }
            
            // Fallback to default
            Helpers.SimpleLogger.Instance.Info("Using default backend URL: http://127.0.0.1:8001");
            return "http://127.0.0.1:8001";
        }

        private string DetectBackendUrl()
        {
            // Step 1: Get candidate URL from config
            var configUrl = LoadBackendUrlFromConfig();
            
            // Step 2: Try to connect to config URL first
            var candidateUrls = new[]
            {
                configUrl,
                "http://127.0.0.1:8001",  // Current Catalogador port (FastAPI)
                "http://localhost:8001",
                "http://127.0.0.1:8000",  // Legacy standard port
                "http://localhost:8000",
                "http://127.0.0.1:8002",  // Alternative port
                "http://localhost:8002",
                "http://127.0.0.1:8006"   // Legacy fallback (deprecated)
            };

            foreach (var url in candidateUrls)
            {
                try
                {
                    using var testClient = new HttpClient { Timeout = TimeSpan.FromSeconds(2) };
                    var response = testClient.GetAsync($"{url}/health").Result;
                    if (response.IsSuccessStatusCode)
                    {
                        Helpers.SimpleLogger.Instance.Info($"Backend detected at {url}");
                        return url;
                    }
                }
                catch
                {
                    // Continue to next URL
                }
            }

            // Default to config URL even if health check failed (service might start later)
            Helpers.SimpleLogger.Instance.Info($"Backend health check failed, using config URL: {configUrl}");
            return configUrl;
        }

        public async Task<bool> CheckHealthAsync()
        {
            try
            {
                var response = await _httpClient.GetAsync("/health");
                if (response.IsSuccessStatusCode)
                {
                    var content = await response.Content.ReadAsStringAsync();
                    var healthData = JsonSerializer.Deserialize<JsonElement>(content);
                    return healthData.TryGetProperty("ok", out var okValue) && okValue.GetBoolean();
                }
                return false;
            }
            catch (Exception ex)
            {
                Helpers.SimpleLogger.Instance.Error($"Health check failed: {ex.Message}");
                return false;
            }
        }

        public async Task<string> UploadFileAsync(string filePath)
        {
            if (!File.Exists(filePath))
            {
                throw new FileNotFoundException($"Archivo no encontrado: {filePath}");
            }

            try
            {
                using var content = new MultipartFormDataContent();
                var fileBytes = await File.ReadAllBytesAsync(filePath);
                var fileContent = new ByteArrayContent(fileBytes);
                fileContent.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue("application/pdf");
                
                content.Add(fileContent, "file", Path.GetFileName(filePath));

                var response = await _httpClient.PostAsync("/upload", content);
                
                if (!response.IsSuccessStatusCode)
                {
                    var errorContent = await response.Content.ReadAsStringAsync();
                    throw new HttpRequestException($"Error al subir archivo: {response.StatusCode}\n{errorContent}");
                }

                var result = await response.Content.ReadAsStringAsync();
                
                // Try to parse and format the response
                try
                {
                    var jsonData = JsonSerializer.Deserialize<JsonElement>(result);
                    return JsonSerializer.Serialize(jsonData, new JsonSerializerOptions 
                    { 
                        WriteIndented = true 
                    });
                }
                catch
                {
                    return result;
                }
            }
            catch (Exception ex)
            {
                Helpers.SimpleLogger.Instance.Error($"Upload failed for {filePath}: {ex.Message}");
                throw;
            }
        }

        public async Task<string> GetTrdInfoAsync()
        {
            try
            {
                var response = await _httpClient.GetAsync("/trd-info");
                
                if (!response.IsSuccessStatusCode)
                {
                    var errorContent = await response.Content.ReadAsStringAsync();
                    throw new HttpRequestException($"Error al obtener TRD: {response.StatusCode}\n{errorContent}");
                }

                var result = await response.Content.ReadAsStringAsync();
                
                // Try to parse and format the response
                try
                {
                    var jsonData = JsonSerializer.Deserialize<JsonElement>(result);
                    return JsonSerializer.Serialize(jsonData, new JsonSerializerOptions 
                    { 
                        WriteIndented = true 
                    });
                }
                catch
                {
                    return result;
                }
            }
            catch (Exception ex)
            {
                Helpers.SimpleLogger.Instance.Error($"TRD info request failed: {ex.Message}");
                throw;
            }
        }

        public async Task<byte[]?> ExportInventoryAsync()
        {
            try
            {
                var response = await _httpClient.GetAsync("/export/inventory");
                
                if (!response.IsSuccessStatusCode)
                {
                    var errorContent = await response.Content.ReadAsStringAsync();
                    throw new HttpRequestException($"Error al exportar inventario: {response.StatusCode}\n{errorContent}");
                }

                return await response.Content.ReadAsByteArrayAsync();
            }
            catch (Exception ex)
            {
                Helpers.SimpleLogger.Instance.Error($"Inventory export failed: {ex.Message}");
                throw;
            }
        }

        /// <summary>
        /// Obtiene todas las series documentales del TRD de EsSalud
        /// </summary>
        public async Task<ResponseSeriesTrd> ObtenerSeriesTrdAsync()
        {
            try
            {
                Helpers.SimpleLogger.Instance.Info("Obteniendo series TRD del backend...");
                
                var response = await _httpClient.GetAsync("/api/inventario/trd/series");
                response.EnsureSuccessStatusCode();

                var content = await response.Content.ReadAsStringAsync();
                var result = JsonSerializer.Deserialize<ResponseSeriesTrd>(content, new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                });

                Helpers.SimpleLogger.Instance.Info($"Series TRD obtenidas exitosamente: {result?.TotalSeries ?? 0} series");
                return result ?? new ResponseSeriesTrd { Series = Array.Empty<SerieTrd>() };
            }
            catch (Exception ex)
            {
                Helpers.SimpleLogger.Instance.Error($"Error obteniendo series TRD: {ex.Message}");
                throw;
            }
        }
    }
}
