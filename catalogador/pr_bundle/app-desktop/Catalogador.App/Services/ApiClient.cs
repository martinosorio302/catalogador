using System;
using System.IO;
using System.Net.Http;
using System.Text.Json;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System.Threading;
using System.Threading.Tasks;
using Catalogador.App.Helpers;

namespace Catalogador.App.Services
{
    public class ApiClient
    {
        private readonly HttpClient _http;

        public ApiClient(string baseUrl)
        {
            _http = new HttpClient { BaseAddress = new Uri(baseUrl) };
            _http.Timeout = TimeSpan.FromSeconds(120);
        }

        public ApiClient() : this("http://127.0.0.1:8123/") { }

    public async Task<JObject?> AnalyzeAsync(string filePath, CancellationToken ct = default)
        {
            using var form = new MultipartFormDataContent();
            using var fs = File.OpenRead(filePath);
            using var sc = new StreamContent(fs);
            sc.Headers.Add("Content-Type", "application/octet-stream");
            form.Add(sc, "file", Path.GetFileName(filePath));
            try
            {
                using var resp = await _http.PostAsync("analyze", form, ct);
                resp.EnsureSuccessStatusCode();
                var text = await resp.Content.ReadAsStringAsync(ct);
                return JObject.Parse(text);
            }
            catch (Exception ex)
            {
                // Do not throw from the client directly; the UI callers handle null result
                SimpleLogger.Error("AnalyzeAsync error", ex);
                return null;
            }
        }

        public async Task<JObject> SaveInventoryAsync(object payload, CancellationToken ct = default)
        {
            var json = JsonConvert.SerializeObject(payload);
            using var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");
            using var resp = await _http.PostAsync("inventory", content, ct);
            var txt = await resp.Content.ReadAsStringAsync(ct);
            if (string.IsNullOrWhiteSpace(txt)) return new JObject {{"ok", false}};
            try
            {
                return JObject.Parse(txt);
            }
            catch (Exception ex)
            {
                SimpleLogger.Error("SaveInventory parse error", ex);
                // return raw text in a json field so callers can inspect the response
                return new JObject { ["ok"] = false, ["raw"] = txt };
            }
        }

        public async Task<JObject> GetInventoriesAsync(int page = 1, int limit = 20, string? q = null, CancellationToken ct = default)
        {
            var qs = $"inventory?page={page}&limit={limit}";
            if (!string.IsNullOrWhiteSpace(q)) qs += "&q=" + Uri.EscapeDataString(q);
            using var resp = await _http.GetAsync(qs, ct);
            resp.EnsureSuccessStatusCode();
            var txt = await resp.Content.ReadAsStringAsync(ct);
            if (string.IsNullOrWhiteSpace(txt)) return new JObject { ["ok"] = false };
            try { return JObject.Parse(txt); }
            catch (Exception ex)
            {
                SimpleLogger.Error("GetInventories parse error", ex);
                return new JObject { ["ok"] = false, ["raw"] = txt };
            }
        }

        public void Dispose() => _http?.Dispose();
    }
}
