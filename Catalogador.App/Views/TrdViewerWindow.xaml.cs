using System;
using System.Windows;
using CatalogadorEsSalud.Services;
using Catalogador.App.ViewModels;

namespace CatalogadorEsSalud.Views
{
    public partial class TrdViewerWindow : Window
    {
        private readonly TrdViewerViewModel _viewModel;

        public TrdViewerWindow()
        {
            InitializeComponent();
            
            _viewModel = new TrdViewerViewModel(ApiClient.Instance);
            DataContext = _viewModel;
            
            Loaded += async (s, e) => await _viewModel.InicializarAsync();
        }
    }
}
