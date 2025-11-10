using System;
using System.Diagnostics;
using System.IO;

namespace Catalogador.App.Helpers
{
    public static class SimpleLogger
    {
        private static readonly object _lock = new object();
    private static readonly string? _logPath;

        static SimpleLogger()
        {
            try
            {
                var baseDir = AppContext.BaseDirectory ?? Directory.GetCurrentDirectory();
                var logsDir = Path.Combine(baseDir, "logs");
                if (!Directory.Exists(logsDir)) Directory.CreateDirectory(logsDir);
                _logPath = Path.Combine(logsDir, "app.log");
            }
            catch
            {
                _logPath = null;
            }
        }

        public static void Info(string msg)
        {
            Write("INFO", msg);
        }

        public static void Warn(string msg)
        {
            Write("WARN", msg);
        }

        public static void Error(string msg)
        {
            Write("ERROR", msg);
        }

        public static void Error(string msg, Exception ex)
        {
            Write("ERROR", msg + " | " + ex?.ToString());
        }

        private static void Write(string level, string msg)
        {
            try
            {
                var line = $"{DateTime.UtcNow:yyyy-MM-dd HH:mm:ss.fff} [{level}] {msg}";
                Debug.WriteLine(line);
                if (!string.IsNullOrEmpty(_logPath))
                {
                    lock (_lock)
                    {
                        try { File.AppendAllText(_logPath, line + Environment.NewLine); } catch { }
                    }
                }
            }
            catch
            {
                // best-effort logger; swallow
            }
        }
    }
}
