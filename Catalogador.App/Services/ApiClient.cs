using System;
using System.IO;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;

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

        private string DetectBackendUrl()
        {
            // Try common URLs in order of preference
            var candidateUrls = new[]
            {
                "http://127.0.0.1:8000",
                "http://localhost:8000",
                "http://0.0.0.0:8000"
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

            // Default to localhost if detection fails
            return "http://127.0.0.1:8000";
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
    }
}
