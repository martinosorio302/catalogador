using System.Text.Json.Serialization;

namespace CatalogadorEsSalud.Models
{
    public class BackendConfig
    {
        [JsonPropertyName("version")]
        public string Version { get; set; } = "1.0.0";

        [JsonPropertyName("backend")]
        public BackendSettings Backend { get; set; } = new();

        [JsonPropertyName("service")]
        public ServiceSettings Service { get; set; } = new();

        [JsonPropertyName("deployment")]
        public DeploymentSettings Deployment { get; set; } = new();

        [JsonPropertyName("features")]
        public FeatureSettings Features { get; set; } = new();
    }

    public class BackendSettings
    {
        [JsonPropertyName("host")]
        public string Host { get; set; } = "127.0.0.1";

        [JsonPropertyName("port")]
        public int Port { get; set; } = 8001;

        [JsonPropertyName("protocol")]
        public string Protocol { get; set; } = "http";

        [JsonPropertyName("timeout_seconds")]
        public int TimeoutSeconds { get; set; } = 300;

        [JsonPropertyName("healthcheck_endpoint")]
        public string HealthcheckEndpoint { get; set; } = "/health";

        [JsonPropertyName("healthcheck_timeout_seconds")]
        public int HealthcheckTimeoutSeconds { get; set; } = 5;
    }

    public class ServiceSettings
    {
        [JsonPropertyName("name")]
        public string Name { get; set; } = "Catalogador-PythonAPI";

        [JsonPropertyName("display_name")]
        public string DisplayName { get; set; } = "Catalogador EsSalud API";

        [JsonPropertyName("description")]
        public string Description { get; set; } = string.Empty;

        [JsonPropertyName("startup_type")]
        public string StartupType { get; set; } = "SERVICE_AUTO_START";

        [JsonPropertyName("restart_delay_ms")]
        public int RestartDelayMs { get; set; } = 5000;
    }

    public class DeploymentSettings
    {
        [JsonPropertyName("production_root")]
        public string ProductionRoot { get; set; } = @"C:\ProgramData\Catalogador\python_api";

        [JsonPropertyName("venv_path")]
        public string VenvPath { get; set; } = "venv";

        [JsonPropertyName("python_module")]
        public string PythonModule { get; set; } = "api.main:app";

        [JsonPropertyName("log_directory")]
        public string LogDirectory { get; set; } = "logs";

        [JsonPropertyName("backup_retention_days")]
        public int BackupRetentionDays { get; set; } = 7;
    }

    public class FeatureSettings
    {
        [JsonPropertyName("auto_reload_dev")]
        public bool AutoReloadDev { get; set; } = false;

        [JsonPropertyName("cors_enabled")]
        public bool CorsEnabled { get; set; } = true;

        [JsonPropertyName("swagger_ui")]
        public bool SwaggerUi { get; set; } = true;

        [JsonPropertyName("admin_token_required")]
        public bool AdminTokenRequired { get; set; } = true;
    }
}
