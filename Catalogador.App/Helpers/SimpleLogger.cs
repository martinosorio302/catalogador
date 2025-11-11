using System;
using System.IO;

namespace CatalogadorEsSalud.Helpers
{
    /// <summary>
    /// Simple logger for application events
    /// </summary>
    public class SimpleLogger
    {
        private static readonly Lazy<SimpleLogger> _instance = new(() => new SimpleLogger());
        public static SimpleLogger Instance => _instance.Value;

        private readonly string _logFilePath;
        private readonly object _lockObject = new();

        private SimpleLogger()
        {
            var logDirectory = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "CatalogadorEsSalud",
                "logs"
            );

            Directory.CreateDirectory(logDirectory);
            _logFilePath = Path.Combine(logDirectory, $"app_{DateTime.Now:yyyyMMdd}.log");
        }

        private void Log(string level, string message)
        {
            lock (_lockObject)
            {
                try
                {
                    var logEntry = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] [{level}] {message}";
                    File.AppendAllText(_logFilePath, logEntry + Environment.NewLine);
                    
                    // Also output to debug console
                    System.Diagnostics.Debug.WriteLine(logEntry);
                }
                catch
                {
                    // Silently fail if logging fails
                }
            }
        }

        public void Info(string message) => Log("INFO", message);
        public void Warning(string message) => Log("WARN", message);
        public void Error(string message) => Log("ERROR", message);
        public void Debug(string message) => Log("DEBUG", message);
    }
}
