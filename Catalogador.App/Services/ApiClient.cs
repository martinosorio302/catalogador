using System;
using System.IO;
using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;
using Newtonsoft.Json;

namespace CatalogadorEsSalud.Services
{
    /// <summary>
    /// HTTP client for communicating with the Python FastAPI backend
    /// </summary>
    public class ApiClient
    {
        private static readonly Lazy<ApiClient> _instance = new(() => new ApiClient());
        public static ApiClient Instance => _instance.Value;

    private readonly HttpClient _httpClient;
    public string BaseUrl { get; }

        private ApiClient()
        {
            // Determine backend URL from environment or runtime/backend_port.txt (fallback to 8000)
            var port = FindBackendPort() ?? "8000";
            BaseUrl = $"http://127.0.0.1:{port}";

            _httpClient = new HttpClient
            {
                BaseAddress = new Uri(BaseUrl),
                Timeout = TimeSpan.FromSeconds(30)
            };

            Helpers.SimpleLogger.Instance.Info($"ApiClient initialized with base URL: {BaseUrl}");
        }

        private string? FindBackendPort()
        {
            // 1. Environment variables (explicit override)
            var env = Environment.GetEnvironmentVariable("CATALOGADOR_BACKEND_PORT")
                      ?? Environment.GetEnvironmentVariable("UVICORN_PORT");
            if (!string.IsNullOrWhiteSpace(env)) return env.Trim();

            // 2. Look for runtime/backend_port.txt walking up from a few likely roots
            string[] roots = new[] { AppDomain.CurrentDomain.BaseDirectory, Directory.GetCurrentDirectory() };
            foreach (var root in roots)
            {
                var dir = new DirectoryInfo(root);
                for (int depth = 0; depth < 5 && dir != null; depth++)
                {
                    var candidate = Path.Combine(dir.FullName, "runtime", "backend_port.txt");
                    try
                    {
                        if (File.Exists(candidate))
                        {
                            var read = File.ReadAllText(candidate).Trim();
                            if (!string.IsNullOrWhiteSpace(read)) return read;
                        }
                    }
                    catch (Exception ex)
                    {
                        // ignore read errors but log
                        Helpers.SimpleLogger.Instance.Warn($"Could not read backend_port at {candidate}: {ex.Message}");
                    }

                    dir = dir.Parent;
                }
            }

            return null;
        }

        /// <summary>
        /// Check if the API backend is healthy and responding
        /// </summary>
        public async Task<bool> CheckHealthAsync()
        {
            try
            {
                var response = await _httpClient.GetAsync("/health");
                return response.IsSuccessStatusCode;
            }
            catch (Exception ex)
            {
                Helpers.SimpleLogger.Instance.Error($"Health check failed: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// Upload a file for processing
        /// </summary>
        public async Task<string> UploadFileAsync(string filePath)
        {
            try
            {
                using var fileStream = System.IO.File.OpenRead(filePath);
                using var content = new MultipartFormDataContent();
                using var streamContent = new StreamContent(fileStream);
                
                streamContent.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue("application/octet-stream");
                content.Add(streamContent, "file", System.IO.Path.GetFileName(filePath));

                var response = await _httpClient.PostAsync("/upload", content);
                response.EnsureSuccessStatusCode();

                var result = await response.Content.ReadAsStringAsync();
                return result;
            }
            catch (Exception ex)
            {
                Helpers.SimpleLogger.Instance.Error($"Upload failed: {ex.Message}");
                throw;
            }
        }

        /// <summary>
        /// Classify a document
        /// </summary>
        public async Task<Models.ClassificationResult?> ClassifyDocumentAsync(string documentId)
        {
            try
            {
                var response = await _httpClient.PostAsync($"/classify?document_id={documentId}", null);
                response.EnsureSuccessStatusCode();

                var result = await response.Content.ReadFromJsonAsync<Models.ClassificationResult>();
                return result;
            }
            catch (Exception ex)
            {
                Helpers.SimpleLogger.Instance.Error($"Classification failed: {ex.Message}");
                return null;
            }
        }

        /// <summary>
        /// Get TRD information
        /// </summary>
        public async Task<string> GetTrdInfoAsync()
        {
            try
            {
                var response = await _httpClient.GetAsync("/trd");
                response.EnsureSuccessStatusCode();

                var result = await response.Content.ReadAsStringAsync();
                return result;
            }
            catch (Exception ex)
            {
                Helpers.SimpleLogger.Instance.Error($"TRD info retrieval failed: {ex.Message}");
                throw;
            }
        }

        /// <summary>
        /// Export inventory to Excel
        /// </summary>
        public async Task<byte[]?> ExportInventoryAsync()
        {
            try
            {
                var response = await _httpClient.GetAsync("/export/inventory");
                response.EnsureSuccessStatusCode();

                return await response.Content.ReadAsByteArrayAsync();
            }
            catch (Exception ex)
            {
                Helpers.SimpleLogger.Instance.Error($"Inventory export failed: {ex.Message}");
                return null;
            }
        }
    }
}
