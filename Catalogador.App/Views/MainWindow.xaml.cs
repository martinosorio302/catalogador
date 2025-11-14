using Microsoft.Win32;
using System;
using System.IO;
using System.Windows;
using System.Windows.Media;

namespace CatalogadorEsSalud.Views
{
    public partial class MainWindow : Window
    {
        private string? _selectedFilePath;
        private readonly Services.ApiClient _apiClient;

        public MainWindow()
        {
            InitializeComponent();
            _apiClient = Services.ApiClient.Instance;
            
            // Check API status on startup
            _ = CheckApiStatusAsync();
        }

        private async Task CheckApiStatusAsync()
        {
            try
            {
                var isHealthy = await _apiClient.CheckHealthAsync();
                
                Dispatcher.Invoke(() =>
                {
                    if (isHealthy)
                    {
                        statusIndicator.Fill = new SolidColorBrush(Colors.Green);
                        txtApiStatus.Text = "API: Conectado";
                        txtStatus.Text = "Listo para procesar documentos";
                    }
                    else
                    {
                        statusIndicator.Fill = new SolidColorBrush(Colors.Red);
                        txtApiStatus.Text = "API: No disponible";
                        txtStatus.Text = "Error: No se puede conectar al servidor API";
                        // Use dynamic base URL detected by ApiClient
                        var backendUrl = Services.ApiClient.Instance.BaseUrl ?? "http://127.0.0.1:8000";
                        MessageBox.Show(
                            $"No se puede conectar al servidor API en {backendUrl}\n\n" +
                            "Por favor, asegúrese de que el servicio de backend esté ejecutándose.",
                            "Error de Conexión",
                            MessageBoxButton.OK,
                            MessageBoxImage.Warning
                        );
                    }
                });
            }
            catch (Exception ex)
            {
                Helpers.SimpleLogger.Instance.Error($"API health check error: {ex.Message}");
                Dispatcher.Invoke(() =>
                {
                    statusIndicator.Fill = new SolidColorBrush(Colors.Red);
                    txtApiStatus.Text = "API: Error";
                });
            }
        }

        private void BtnSelectFile_Click(object sender, RoutedEventArgs e)
        {
            var openFileDialog = new OpenFileDialog
            {
                Filter = "PDF Files (*.pdf)|*.pdf|All Files (*.*)|*.*",
                Title = "Seleccionar Documento"
            };

            if (openFileDialog.ShowDialog() == true)
            {
                _selectedFilePath = openFileDialog.FileName;
                txtSelectedFile.Text = $"Archivo: {Path.GetFileName(_selectedFilePath)}";
                btnUpload.IsEnabled = true;
                Helpers.SimpleLogger.Instance.Info($"File selected: {_selectedFilePath}");
            }
        }

        private async void BtnUpload_Click(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrEmpty(_selectedFilePath))
            {
                MessageBox.Show("Por favor, seleccione un archivo primero.", "Error", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            try
            {
                btnUpload.IsEnabled = false;
                txtStatus.Text = "Procesando documento...";
                txtResults.Text = "Subiendo archivo y procesando...\n";

                Helpers.SimpleLogger.Instance.Info($"Uploading file: {_selectedFilePath}");
                var result = await _apiClient.UploadFileAsync(_selectedFilePath);

                txtResults.Text += $"\n✓ Documento procesado exitosamente\n\n{result}";
                txtStatus.Text = "Documento procesado correctamente";
                
                MessageBox.Show("Documento procesado correctamente", "Éxito", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            catch (Exception ex)
            {
                Helpers.SimpleLogger.Instance.Error($"Upload error: {ex.Message}");
                txtResults.Text += $"\n✗ Error al procesar documento: {ex.Message}";
                txtStatus.Text = "Error al procesar documento";
                MessageBox.Show($"Error al procesar documento:\n{ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
            finally
            {
                btnUpload.IsEnabled = true;
            }
        }

        private async void BtnLoadTrd_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                txtStatus.Text = "Cargando información TRD...";
                btnLoadTrd.IsEnabled = false;

                var trdInfo = await _apiClient.GetTrdInfoAsync();
                txtTrdInfo.Text = trdInfo;
                txtStatus.Text = "Información TRD cargada";
            }
            catch (Exception ex)
            {
                Helpers.SimpleLogger.Instance.Error($"TRD load error: {ex.Message}");
                txtTrdInfo.Text = $"Error al cargar TRD: {ex.Message}";
                txtStatus.Text = "Error al cargar TRD";
                MessageBox.Show($"Error al cargar TRD:\n{ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
            finally
            {
                btnLoadTrd.IsEnabled = true;
            }
        }

        private async void BtnExport_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                btnExport.IsEnabled = false;
                txtExportStatus.Text = "Exportando inventario...";
                txtStatus.Text = "Generando archivo Excel...";

                var excelData = await _apiClient.ExportInventoryAsync();
                
                if (excelData != null && excelData.Length > 0)
                {
                    var saveFileDialog = new SaveFileDialog
                    {
                        Filter = "Excel Files (*.xlsx)|*.xlsx",
                        FileName = $"Inventario_{DateTime.Now:yyyyMMdd_HHmmss}.xlsx",
                        Title = "Guardar Inventario"
                    };

                    if (saveFileDialog.ShowDialog() == true)
                    {
                        await File.WriteAllBytesAsync(saveFileDialog.FileName, excelData);
                        txtExportStatus.Text = $"✓ Inventario exportado correctamente:\n{saveFileDialog.FileName}";
                        txtStatus.Text = "Exportación completada";
                        MessageBox.Show("Inventario exportado correctamente", "Éxito", MessageBoxButton.OK, MessageBoxImage.Information);
                    }
                }
                else
                {
                    txtExportStatus.Text = "No hay datos para exportar";
                    txtStatus.Text = "Sin datos para exportar";
                }
            }
            catch (Exception ex)
            {
                Helpers.SimpleLogger.Instance.Error($"Export error: {ex.Message}");
                txtExportStatus.Text = $"✗ Error al exportar: {ex.Message}";
                txtStatus.Text = "Error en exportación";
                MessageBox.Show($"Error al exportar inventario:\n{ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
            finally
            {
                btnExport.IsEnabled = true;
            }
        }
    }
}
