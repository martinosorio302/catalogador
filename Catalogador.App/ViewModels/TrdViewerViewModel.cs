using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;
using Catalogador.App.Models;
using Catalogador.App.Services;
using ClosedXML.Excel;
using Microsoft.Win32;

namespace Catalogador.App.ViewModels
{
    public class TrdViewerViewModel : INotifyPropertyChanged
    {
        private readonly CatalogadorEsSalud.Services.ApiClient _apiClient;
        private List<SerieTrd> _seriesCompletas;
        private ObservableCollection<SerieTrd> _seriesFiltradas;
        private ObservableCollection<SerieTrd> _seriesPaginadas;
        private string _filtroTexto;
        private string _filtroValor = "Todos";
        private int _paginaActual = 1;
        private int _totalPaginas;
        private const int ITEMS_POR_PAGINA = 50;
        private bool _isLoading;
        private bool _isExporting;
        private string _versionTrd;
        private int _totalSeries;

        public TrdViewerViewModel(CatalogadorEsSalud.Services.ApiClient apiClient)
        {
            _apiClient = apiClient ?? throw new ArgumentNullException(nameof(apiClient));
            
            SeriesFiltradas = new ObservableCollection<SerieTrd>();
            SeriesPaginadas = new ObservableCollection<SerieTrd>();
            
            // Comandos
            BuscarCommand = new RelayCommand(AplicarFiltros);
            PaginaSiguienteCommand = new RelayCommand(() => CambiarPagina(PaginaActual + 1), () => PaginaActual < TotalPaginas);
            PaginaAnteriorCommand = new RelayCommand(() => CambiarPagina(PaginaActual - 1), () => PaginaActual > 1);
            IrPrimeraPaginaCommand = new RelayCommand(() => CambiarPagina(1), () => PaginaActual > 1);
            IrUltimaPaginaCommand = new RelayCommand(() => CambiarPagina(TotalPaginas), () => PaginaActual < TotalPaginas);
            ExportarCommand = new RelayCommand(async () => await ExportarAsync(), () => SeriesFiltradas?.Count > 0);
            RecargarCommand = new RelayCommand(async () => await CargarSeriesAsync());
        }

        #region Propiedades

        public ObservableCollection<SerieTrd> SeriesFiltradas
        {
            get => _seriesFiltradas;
            set { _seriesFiltradas = value; OnPropertyChanged(); }
        }

        public ObservableCollection<SerieTrd> SeriesPaginadas
        {
            get => _seriesPaginadas;
            set { _seriesPaginadas = value; OnPropertyChanged(); }
        }

        public string FiltroTexto
        {
            get => _filtroTexto;
            set
            {
                _filtroTexto = value;
                OnPropertyChanged();
                AplicarFiltros();
            }
        }

        public string FiltroValor
        {
            get => _filtroValor;
            set
            {
                _filtroValor = value;
                OnPropertyChanged();
                AplicarFiltros();
            }
        }

        public int PaginaActual
        {
            get => _paginaActual;
            set
            {
                _paginaActual = value;
                OnPropertyChanged();
                OnPropertyChanged(nameof(TextoPaginacion));
            }
        }

        public int TotalPaginas
        {
            get => _totalPaginas;
            set
            {
                _totalPaginas = value;
                OnPropertyChanged();
                OnPropertyChanged(nameof(TextoPaginacion));
            }
        }

        public string TextoPaginacion => $"Página {PaginaActual} de {TotalPaginas} - Mostrando {(PaginaActual - 1) * ITEMS_POR_PAGINA + 1}-{Math.Min(PaginaActual * ITEMS_POR_PAGINA, SeriesFiltradas?.Count ?? 0)} de {SeriesFiltradas?.Count ?? 0} series";

        public bool IsLoading
        {
            get => _isLoading;
            set { _isLoading = value; OnPropertyChanged(); }
        }

        public bool IsExporting
        {
            get => _isExporting;
            set { _isExporting = value; OnPropertyChanged(); }
        }

        public string VersionTrd
        {
            get => _versionTrd;
            set { _versionTrd = value; OnPropertyChanged(); }
        }

        public int TotalSeries
        {
            get => _totalSeries;
            set { _totalSeries = value; OnPropertyChanged(); }
        }

        public List<string> OpcionesFiltroValor => new List<string> { "Todos", "Permanente", "Temporal" };

        #endregion

        #region Comandos

        public ICommand BuscarCommand { get; }
        public ICommand PaginaSiguienteCommand { get; }
        public ICommand PaginaAnteriorCommand { get; }
        public ICommand IrPrimeraPaginaCommand { get; }
        public ICommand IrUltimaPaginaCommand { get; }
        public ICommand ExportarCommand { get; }
        public ICommand RecargarCommand { get; }

        #endregion

        #region Métodos

        public async Task InicializarAsync()
        {
            await CargarSeriesAsync();
        }

        private async Task CargarSeriesAsync()
        {
            IsLoading = true;
            try
            {
                var response = await _apiClient.ObtenerSeriesTrdAsync();
                
                _seriesCompletas = response.Series.ToList();
                TotalSeries = response.TotalSeries;
                VersionTrd = response.VersionTrd;

                AplicarFiltros();

                MessageBox.Show(
                    $"TRD cargado exitosamente:\n\n" +
                    $"Total series: {TotalSeries}\n" +
                    $"Versión TRD: {VersionTrd}",
                    "Carga Exitosa",
                    MessageBoxButton.OK,
                    MessageBoxImage.Information
                );
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    $"Error al cargar series TRD:\n\n{ex.Message}\n\n" +
                    $"Verifique que el backend esté corriendo en http://localhost:8001",
                    "Error de Conexión",
                    MessageBoxButton.OK,
                    MessageBoxImage.Error
                );
            }
            finally
            {
                IsLoading = false;
            }
        }

        private void AplicarFiltros()
        {
            if (_seriesCompletas == null || _seriesCompletas.Count == 0)
                return;

            var query = _seriesCompletas.AsEnumerable();

            // Filtro por texto
            if (!string.IsNullOrWhiteSpace(FiltroTexto))
            {
                var filtro = FiltroTexto.ToUpper();
                query = query.Where(s =>
                    (s.Codigo?.ToUpper().Contains(filtro) ?? false) ||
                    (s.TituloSerie?.ToUpper().Contains(filtro) ?? false) ||
                    (s.Asunto?.ToUpper().Contains(filtro) ?? false)
                );
            }

            // Filtro por valor
            if (FiltroValor != "Todos")
            {
                if (FiltroValor == "Permanente")
                {
                    query = query.Where(s => s.EsPermanente);
                }
                else if (FiltroValor == "Temporal")
                {
                    query = query.Where(s => !s.EsPermanente);
                }
            }

            SeriesFiltradas = new ObservableCollection<SerieTrd>(query.ToList());
            PaginaActual = 1;
            ActualizarPaginacion();
        }

        private void CambiarPagina(int nuevaPagina)
        {
            if (nuevaPagina < 1 || nuevaPagina > TotalPaginas)
                return;

            PaginaActual = nuevaPagina;
            ActualizarPaginacion();
        }

        private void ActualizarPaginacion()
        {
            if (SeriesFiltradas == null || SeriesFiltradas.Count == 0)
            {
                SeriesPaginadas = new ObservableCollection<SerieTrd>();
                TotalPaginas = 0;
                return;
            }

            var skip = (PaginaActual - 1) * ITEMS_POR_PAGINA;
            var take = ITEMS_POR_PAGINA;

            SeriesPaginadas = new ObservableCollection<SerieTrd>(
                SeriesFiltradas.Skip(skip).Take(take).ToList()
            );

            TotalPaginas = (int)Math.Ceiling((double)SeriesFiltradas.Count / ITEMS_POR_PAGINA);
        }

        private async Task ExportarAsync()
        {
            var saveDialog = new SaveFileDialog
            {
                Filter = "Excel Files (*.xlsx)|*.xlsx",
                FileName = $"TRD_EsSalud_{DateTime.Now:yyyyMMdd_HHmmss}.xlsx",
                Title = "Exportar TRD a Excel"
            };

            if (saveDialog.ShowDialog() != true)
                return;

            IsExporting = true;
            try
            {
                await Task.Run(() =>
                {
                    using var workbook = new XLWorkbook();
                    var worksheet = workbook.Worksheets.Add("TRD EsSalud");

                    // Headers
                    worksheet.Cell(1, 1).Value = "Código";
                    worksheet.Cell(1, 2).Value = "Título Serie";
                    worksheet.Cell(1, 3).Value = "Asunto";
                    worksheet.Cell(1, 4).Value = "AG (años)";
                    worksheet.Cell(1, 5).Value = "AP (años)";
                    worksheet.Cell(1, 6).Value = "AC (años)";
                    worksheet.Cell(1, 7).Value = "Total (años)";
                    worksheet.Cell(1, 8).Value = "Destino";

                    // Estilo headers
                    var headerRange = worksheet.Range(1, 1, 1, 8);
                    headerRange.Style.Font.Bold = true;
                    headerRange.Style.Fill.BackgroundColor = XLColor.FromHtml("#4472C4");
                    headerRange.Style.Font.FontColor = XLColor.White;
                    headerRange.Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;

                    // Data
                    int row = 2;
                    foreach (var serie in SeriesFiltradas)
                    {
                        worksheet.Cell(row, 1).Value = serie.Codigo;
                        worksheet.Cell(row, 2).Value = serie.TituloSerie;
                        worksheet.Cell(row, 3).Value = serie.Asunto;
                        worksheet.Cell(row, 4).Value = serie.PlazoAG;
                        worksheet.Cell(row, 5).Value = serie.PlazoAP;
                        worksheet.Cell(row, 6).Value = serie.PlazoOAA;
                        worksheet.Cell(row, 7).Value = serie.TotalAnios;
                        worksheet.Cell(row, 8).Value = serie.Destino;

                        // Colorear según destino
                        if (serie.EsPermanente)
                        {
                            worksheet.Row(row).Style.Fill.BackgroundColor = XLColor.FromHtml("#E8F5E9");
                        }

                        row++;
                    }

                    // Ajustar columnas
                    worksheet.Columns().AdjustToContents();

                    // Congelar primera fila
                    worksheet.SheetView.FreezeRows(1);

                    workbook.SaveAs(saveDialog.FileName);
                });

                MessageBox.Show(
                    $"TRD exportado exitosamente:\n\n{saveDialog.FileName}\n\n" +
                    $"Total series exportadas: {SeriesFiltradas.Count}",
                    "Exportación Exitosa",
                    MessageBoxButton.OK,
                    MessageBoxImage.Information
                );
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    $"Error al exportar TRD:\n\n{ex.Message}",
                    "Error de Exportación",
                    MessageBoxButton.OK,
                    MessageBoxImage.Error
                );
            }
            finally
            {
                IsExporting = false;
            }
        }

        #endregion

        #region INotifyPropertyChanged

        public event PropertyChangedEventHandler PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }

        #endregion
    }

    /// <summary>
    /// Implementación simple de ICommand
    /// </summary>
    public class RelayCommand : ICommand
    {
        private readonly Action _execute;
        private readonly Func<bool> _canExecute;

        public RelayCommand(Action execute, Func<bool> canExecute = null)
        {
            _execute = execute ?? throw new ArgumentNullException(nameof(execute));
            _canExecute = canExecute;
        }

        public event EventHandler CanExecuteChanged
        {
            add { CommandManager.RequerySuggested += value; }
            remove { CommandManager.RequerySuggested -= value; }
        }

        public bool CanExecute(object parameter) => _canExecute?.Invoke() ?? true;

        public void Execute(object parameter) => _execute();
    }
}
