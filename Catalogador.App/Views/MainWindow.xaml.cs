using Microsoft.Win32;
using System;
using System.IO;
using System.Net.Http;
using System.Windows;
using System.Windows.Media;
using Catalogador.App.Services;

namespace CatalogadorEsSalud.Views
{
    public partial class MainWindow : Window
    {
        private string? _selectedFilePath;
        private readonly Services.ApiClient _apiClient;
        private readonly InventarioService _inventarioService;

        public MainWindow()
        {
            InitializeComponent();
            _apiClient = Services.ApiClient.Instance;
            _inventarioService = new InventarioService();
            
            // Check API and Inventory service status on startup
            _ = CheckServicesStatusAsync();
        }

        private async Task CheckServicesStatusAsync()
        {
            try
            {
                // Check main API
                var isApiHealthy = await _apiClient.CheckHealthAsync();
                
                // Check Inventory service
                var isInventoryHealthy = false;
                try
                {
                    isInventoryHealthy = await _inventarioService.VerificarEstado();
                }
                catch
                {
                    isInventoryHealthy = false;
                }
                
                Dispatcher.Invoke(() =>
                {
                    if (isApiHealthy && isInventoryHealthy)
                    {
                        statusIndicator.Fill = new SolidColorBrush(Colors.Green);
                        txtApiStatus.Text = "✓ Servicios: Operativos";
                        txtStatus.Text = "✓ Listo - Backend en puerto 8001";
                    }
                    else if (isApiHealthy && !isInventoryHealthy)
                    {
                        statusIndicator.Fill = new SolidColorBrush(Colors.Orange);
                        txtApiStatus.Text = "⚠ API OK - Inventario no disponible";
                        txtStatus.Text = "⚠ Servicio de inventario no responde";
                        MessageBox.Show(
                            "SERVICIO DE INVENTARIO NO DISPONIBLE\\n\\n" +
                            "El backend principal está activo pero el módulo de inventario\\n" +
                            "no responde en http://127.0.0.1:8001/api/inventario/health\\n\\n" +
                            "Funcionalidad afectada:\\n" +
                            "- Generación de inventarios Excel\\n" +
                            "- Análisis TRD de documentos\\n\\n" +
                            "Solución:\\n" +
                            "1. Reinicie el backend: tools\\\\run_engine.ps1\\n" +
                            "2. Verifique logs en logs/\\n" +
                            "3. Compruebe TRD cargado correctamente",
                            "⚠ Advertencia",
                            MessageBoxButton.OK,
                            MessageBoxImage.Warning
                        );
                    }
                    else
                    {
                        statusIndicator.Fill = new SolidColorBrush(Colors.Red);
                        txtApiStatus.Text = "✗ Servicios: No disponibles";
                        txtStatus.Text = "✗ Backend no conectado";
                        MessageBox.Show(
                            "BACKEND NO DISPONIBLE\\n\\n" +
                            "No se puede conectar al servidor en:\\n" +
                            "http://127.0.0.1:8001\\n\\n" +
                            "Pasos para solucionar:\\n" +
                            "1. Abra PowerShell en la carpeta del proyecto\\n" +
                            "2. Ejecute: .\\\\tools\\\\run_engine.ps1\\n" +
                            "3. Espere mensaje 'Uvicorn running on http://127.0.0.1:8001'\\n" +
                            "4. Reinicie esta aplicación\\n\\n" +
                            "Verifique también:\\n" +
                            "- Puerto 8001 no está en uso\\n" +
                            "- Firewall permite conexiones locales\\n" +
                            "- Python y dependencias instaladas",
                            "✗ Error Crítico",
                            MessageBoxButton.OK,
                            MessageBoxImage.Error
                        );
                    }
                });
            }
            catch (Exception ex)
            {
                Helpers.SimpleLogger.Instance.Error($"Services health check error: {ex.Message}");
                Dispatcher.Invoke(() =>
                {
                    statusIndicator.Fill = new SolidColorBrush(Colors.Red);
                    txtApiStatus.Text = "✗ Error de conexión";
                    txtStatus.Text = $"✗ {ex.Message}";
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
                txtExportStatus.Text = "Exportando inventario con análisis TRD...";
                txtStatus.Text = "Generando Excel con 4 hojas...";

                // Verificar que el servicio de inventario esté disponible
                var serviceAvailable = await _inventarioService.VerificarEstado();
                if (!serviceAvailable)
                {
                    txtExportStatus.Text = "✗ Servicio de inventario no disponible";
                    txtStatus.Text = "Error: Backend no responde";
                    MessageBox.Show(
                        "El servicio de inventario no está disponible.\n\n" +
                        "Asegúrese de que el backend esté ejecutándose:\n" +
                        "START_BACKEND.bat",
                        "Error de Conexión",
                        MessageBoxButton.OK,
                        MessageBoxImage.Warning
                    );
                    return;
                }

                // Obtener documentos procesados (simulación - reemplazar con tu BD)
                var documentos = await ObtenerDocumentosParaInventario();
                
                if (documentos == null || documentos.Count == 0)
                {
                    txtExportStatus.Text = "No hay documentos procesados para exportar";
                    txtStatus.Text = "Sin datos";
                    MessageBox.Show(
                        "No hay documentos procesados.\n\n" +
                        "Por favor, suba y procese algunos documentos primero.",
                        "Sin Datos",
                        MessageBoxButton.OK,
                        MessageBoxImage.Information
                    );
                    return;
                }

                txtStatus.Text = $"Generando inventario con {documentos.Count} documentos...";
                
                // Generar inventario Excel con análisis TRD
                var nombreArchivo = await _inventarioService.GenerarInventarioExcel(documentos);
                
                txtStatus.Text = "Descargando archivo Excel...";
                
                // Descargar Excel generado
                var excelData = await _inventarioService.DescargarExcel(nombreArchivo);
                
                // Guardar localmente
                var saveFileDialog = new SaveFileDialog
                {
                    Filter = "Excel Files (*.xlsx)|*.xlsx",
                    FileName = nombreArchivo,
                    Title = "Guardar Inventario TRD"
                };

                if (saveFileDialog.ShowDialog() == true)
                {
                    await File.WriteAllBytesAsync(saveFileDialog.FileName, excelData);
                    txtExportStatus.Text = $"✓ Inventario TRD exportado:\n{Path.GetFileName(saveFileDialog.FileName)}\n\n" +
                                          $"📊 Total documentos: {documentos.Count}\n" +
                                          $"📑 4 hojas generadas (Inventario General, Por Serie, Control, TRD)";
                    txtStatus.Text = "Exportación completada exitosamente";
                    
                    var result = MessageBox.Show(
                        $"Inventario exportado correctamente con {documentos.Count} documentos.\n\n" +
                        "¿Desea abrir el archivo Excel ahora?",
                        "Éxito",
                        MessageBoxButton.YesNo,
                        MessageBoxImage.Information
                    );
                    
                    if (result == MessageBoxResult.Yes)
                    {
                        System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                        {
                            FileName = saveFileDialog.FileName,
                            UseShellExecute = true
                        });
                    }
                }
            }
            catch (HttpRequestException ex)
            {
                Helpers.SimpleLogger.Instance.Error($"API error: {ex.Message}");
                txtExportStatus.Text = $"✗ Error de conexión con el servidor\n\n" +
                                      $"Mensaje: {ex.Message}\n\n" +
                                      "Verifique:\n" +
                                      "1. Backend corriendo en http://127.0.0.1:8001\n" +
                                      "2. No hay firewall bloqueando\n" +
                                      "3. Puerto 8001 disponible";
                txtStatus.Text = "⚠ Servicio no disponible";
                MessageBox.Show(
                    "SERVICIO DE INVENTARIO NO DISPONIBLE\n\n" +
                    $"Error: {ex.Message}\n\n" +
                    "Soluciones:\n" +
                    "1. Inicie el backend: tools\\run_engine.ps1\n" +
                    "2. Verifique puerto 8001 disponible\n" +
                    "3. Compruebe firewall/antivirus\n\n" +
                    "El backend debe estar ejecutándose en:\n" +
                    "http://127.0.0.1:8001",
                    "⚠ Servicio No Disponible",
                    MessageBoxButton.OK,
                    MessageBoxImage.Warning
                );
            }
            catch (TaskCanceledException)
            {
                Helpers.SimpleLogger.Instance.Error("Export timeout");
                txtExportStatus.Text = "✗ Tiempo de espera agotado\n\n" +
                                      "La generación del inventario tardó demasiado.\n" +
                                      "Intente con menos documentos.";
                txtStatus.Text = "⏱ Timeout";
                MessageBox.Show(
                    "TIEMPO DE ESPERA AGOTADO\n\n" +
                    "La generación del inventario tardó más de 5 minutos.\n\n" +
                    "Recomendaciones:\n" +
                    "- Reduzca la cantidad de documentos\n" +
                    "- Divida en múltiples inventarios\n" +
                    "- Verifique rendimiento del servidor",
                    "⏱ Timeout",
                    MessageBoxButton.OK,
                    MessageBoxImage.Warning
                );
            }
            catch (Exception ex)
            {
                Helpers.SimpleLogger.Instance.Error($"Export error: {ex.Message}");
                txtExportStatus.Text = $"✗ Error al exportar inventario:\n\n{ex.Message}";
                txtStatus.Text = "❌ Error en exportación";
                MessageBox.Show(
                    $"ERROR AL GENERAR INVENTARIO\n\n{ex.Message}\n\n" +
                    "Verifique:\n" +
                    "- Datos de los documentos son válidos\n" +
                    "- Hay espacio en disco\n" +
                    "- Permisos de escritura en carpeta exports/",
                    "❌ Error",
                    MessageBoxButton.OK,
                    MessageBoxImage.Error
                );
            }
            finally
            {
                btnExport.IsEnabled = true;
            }
        }
        
        /// <summary>
        /// Obtiene documentos para el inventario (ejemplo con datos simulados)
        /// TODO: Reemplazar con tu lógica real de base de datos
        /// </summary>
        private async Task<List<DocumentoInventario>> ObtenerDocumentosParaInventario()
        {
            // Simular obtención de BD
            await Task.Delay(100);
            
            // TODO: Reemplazar con tu código real:
            // return await _databaseService.ObtenerDocumentosProcesados();
            
            // Ejemplo con datos simulados:
            var documentos = new List<DocumentoInventario>();
            
            // Si hay un archivo seleccionado, crear documento de ejemplo
            if (!string.IsNullOrEmpty(_selectedFilePath) && File.Exists(_selectedFilePath))
            {
                var fileName = Path.GetFileName(_selectedFilePath);
                documentos.Add(new DocumentoInventario
                {
                    numero_orden = 1,
                    codigo_referencia = $"DOC-{DateTime.Now:yyyy}-001",
                    nombre_archivo = fileName,
                    serie_documental = "Memorandos", // Esto vendría del análisis TRD
                    codigo_trd = "COR-001",
                    fecha_documento = DateTime.Now.ToString("yyyy-MM-dd"),
                    numero_folios = 5,
                    soporte = "Digital",
                    ubicacion_fisica = "Servidor Principal - /uploads",
                    plazo_gestion = 2,
                    plazo_central = 5,
                    disposicion_final = "Eliminación",
                    observaciones = "Documento procesado automáticamente"
                });
            }
            
            return documentos;
        }

        private void BtnVerTrdCompleto_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                Helpers.SimpleLogger.Instance.Info("Abriendo visor TRD completo");
                var trdViewer = new TrdViewerWindow();
                trdViewer.Show();
            }
            catch (Exception ex)
            {
                Helpers.SimpleLogger.Instance.Error($"Error al abrir visor TRD: {ex.Message}");
                MessageBox.Show(
                    $"Error al abrir el visor TRD:\n{ex.Message}",
                    "Error",
                    MessageBoxButton.OK,
                    MessageBoxImage.Error
                );
            }
        }
    }
}
