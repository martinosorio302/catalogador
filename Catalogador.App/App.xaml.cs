using System.Windows;

namespace CatalogadorEsSalud
{
    /// <summary>
    /// Interaction logic for App.xaml
    /// </summary>
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);
            
            // Initialize logging
            var logger = Helpers.SimpleLogger.Instance;
            logger.Info("Application starting...");
            
            // Check if API is available
            var apiClient = Services.ApiClient.Instance;
            _ = apiClient.CheckHealthAsync(); // Fire and forget initial health check
        }
    }
}
