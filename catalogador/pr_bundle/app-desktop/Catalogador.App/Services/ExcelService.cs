using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using Catalogador.App.Models;
using ClosedXML.Excel;

namespace Catalogador.App.Services
{
    public static class ExcelService
    {
        // Export simple flat inventory table (headers aligned with InventoryRecord)
        public static void ExportInventario(string path, IList<InventoryRecord> registros)
        {
            if (registros == null) throw new ArgumentNullException(nameof(registros));

            using var wb = new XLWorkbook();
            var ws = wb.Worksheets.Add("Inventario");

            var headers = new[]
            {
                "Fuente","Fondo Documental","Sección","Serie Documental","Subserie Documental","Fracción",
                "Es Expediente","Título","Asunto","Fecha Inicio","Fecha Fin","Folios","Soporte",
                "Ubicación Topográfica","Productor","Valor Adm.","Valor Legal","Valor Fiscal","Valor Histórico",
                "Temp. Gestor","Temp. Central","Disposición Final","PCDA","TRD","Confianza Serie",
                "Observaciones","Hash Doc.","Versión Reglas","Fecha Procesado","Estado","Error"
            };

            for (int i = 0; i < headers.Length; i++)
                ws.Cell(1, i + 1).Value = headers[i];

            ws.Row(1).Style.Font.Bold = true;

            int r = 2;
            foreach (var it in registros)
            {
                int c = 1;
                ws.Cell(r, c++).Value = it.SourceFile;
                ws.Cell(r, c++).Value = it.FondoDocumental;
                ws.Cell(r, c++).Value = it.Seccion;
                ws.Cell(r, c++).Value = it.SerieDocumental;
                ws.Cell(r, c++).Value = it.SubserieDocumental;
                ws.Cell(r, c++).Value = it.FraccionDocumental;
                ws.Cell(r, c++).Value = it.EsExpediente ? "Sí" : "No";
                ws.Cell(r, c++).Value = it.Titulo;
                ws.Cell(r, c++).Value = it.Asunto;
                ws.Cell(r, c++).Value = it.FechaInicio;
                ws.Cell(r, c++).Value = it.FechaFin;
                ws.Cell(r, c++).Value = it.CantFolios;
                ws.Cell(r, c++).Value = it.Soporte;
                ws.Cell(r, c++).Value = it.UbicacionTopografica;
                ws.Cell(r, c++).Value = it.Productor;
                ws.Cell(r, c++).Value = it.ValorAdm;
                ws.Cell(r, c++).Value = it.ValorLegal;
                ws.Cell(r, c++).Value = it.ValorFiscal;
                ws.Cell(r, c++).Value = it.ValorHistorico;
                ws.Cell(r, c++).Value = it.TempGestor;
                ws.Cell(r, c++).Value = it.TempCentral;
                ws.Cell(r, c++).Value = it.DisposicionFinal;
                ws.Cell(r, c++).Value = it.NormaPCDA;
                ws.Cell(r, c++).Value = it.TRDCodigo;
                ws.Cell(r, c++).Value = it.ConfianzaSerie;
                ws.Cell(r, c++).Value = it.Observaciones;
                ws.Cell(r, c++).Value = it.HashDocumento;
                ws.Cell(r, c++).Value = it.VersionReglas;
                ws.Cell(r, c++).Value = it.FechaProcesado?.ToString("yyyy-MM-dd HH:mm:ss");
                ws.Cell(r, c++).Value = it.Estado;
                ws.Cell(r, c++).Value = it.ErrorMessage;
                r++;
            }

            ws.Columns().AdjustToContents();
            var dir = Path.GetDirectoryName(path) ?? AppContext.BaseDirectory;
            if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
            wb.SaveAs(path);
        }

        // Richer AGN-style inventory export. Uses InventoryRecord and maps fields accordingly.
        public static void ExportInventarioAGN(IEnumerable<InventoryRecord> rows, string institucion, string fondoGeneral, string outputPath, bool copyToExports = true, bool openAfter = false)
        {
            if (string.IsNullOrWhiteSpace(outputPath))
                throw new ArgumentException("Ruta de salida inválida.", nameof(outputPath));

            var list = (rows ?? Enumerable.Empty<InventoryRecord>()).ToList();

            using var wb = new XLWorkbook();
            var ws = wb.Worksheets.Add("Inventario");

            // Header
            ws.Cell(1, 1).Value = "INSTITUCION";
            ws.Cell(1, 2).Value = institucion ?? string.Empty;
            ws.Cell(2, 1).Value = "FONDO DOCUMENTAL";
            ws.Cell(2, 2).Value = fondoGeneral ?? string.Empty;
            ws.Range(1, 1, 2, 2).Style.Font.Bold = true;
            ws.Range(1, 1, 2, 2).Style.Fill.BackgroundColor = XLColor.FromArgb(243, 244, 246);

            int headerRow = 4;
            int col = 1;
            ws.Cell(headerRow, col++).Value = "Nro";
            ws.Cell(headerRow, col++).Value = "Fondo Documental";
            ws.Cell(headerRow, col++).Value = "Seccion";
            ws.Cell(headerRow, col++).Value = "Serie Documental";
            ws.Cell(headerRow, col++).Value = "Subserie Documental";
            ws.Cell(headerRow, col++).Value = "Fraccion Documental";
            ws.Cell(headerRow, col++).Value = "Expediente";
            ws.Cell(headerRow, col++).Value = "Titulo Documental";
            ws.Cell(headerRow, col++).Value = "Asunto";
            ws.Cell(headerRow, col++).Value = "Fecha Inicio";
            ws.Cell(headerRow, col++).Value = "Fecha Fin";
            ws.Cell(headerRow, col++).Value = "Folios";
            ws.Cell(headerRow, col++).Value = "Soporte";
            ws.Cell(headerRow, col++).Value = "Ubicacion Topografica";
            ws.Cell(headerRow, col++).Value = "Productor";
            ws.Cell(headerRow, col++).Value = "Val. Adm.";
            ws.Cell(headerRow, col++).Value = "Val. Legal";
            ws.Cell(headerRow, col++).Value = "Val. Fiscal";
            ws.Cell(headerRow, col++).Value = "Val. Hist.";
            ws.Cell(headerRow, col++).Value = "Temp. Gestor";
            ws.Cell(headerRow, col++).Value = "Temp. Central";
            ws.Cell(headerRow, col++).Value = "Disposicion Final";
            ws.Cell(headerRow, col++).Value = "Norma PCDA";
            ws.Cell(headerRow, col++).Value = "Norma TRD";
            ws.Cell(headerRow, col++).Value = "Confianza Serie";
            ws.Cell(headerRow, col++).Value = "Observaciones";

            int current = headerRow + 1;
            int idx = 1;
            foreach (var r in list)
            {
                col = 1;
                ws.Cell(current, col++).Value = idx++;
                ws.Cell(current, col++).Value = r.FondoDocumental;
                ws.Cell(current, col++).Value = r.Seccion;
                ws.Cell(current, col++).Value = r.SerieDocumental;
                ws.Cell(current, col++).Value = r.SubserieDocumental;
                ws.Cell(current, col++).Value = r.FraccionDocumental;
                ws.Cell(current, col++).Value = r.EsExpediente ? "SI" : "NO";
                ws.Cell(current, col++).Value = r.Titulo;
                ws.Cell(current, col++).Value = r.Asunto;
                ws.Cell(current, col++).Value = r.FechaInicio;
                ws.Cell(current, col++).Value = r.FechaFin;
                ws.Cell(current, col++).Value = r.CantFolios;
                ws.Cell(current, col++).Value = r.Soporte;
                ws.Cell(current, col++).Value = r.UbicacionTopografica;
                ws.Cell(current, col++).Value = r.Productor;
                ws.Cell(current, col++).Value = r.ValorAdm;
                ws.Cell(current, col++).Value = r.ValorLegal;
                ws.Cell(current, col++).Value = r.ValorFiscal;
                ws.Cell(current, col++).Value = r.ValorHistorico;
                ws.Cell(current, col++).Value = r.TempGestor;
                ws.Cell(current, col++).Value = r.TempCentral;
                ws.Cell(current, col++).Value = r.DisposicionFinal;
                ws.Cell(current, col++).Value = r.NormaPCDA;
                ws.Cell(current, col++).Value = r.TRDCodigo;
                ws.Cell(current, col++).Value = r.ConfianzaSerie;
                ws.Cell(current, col++).Value = r.Observaciones;
                current++;
            }

            // Styles
            var headerRange = ws.Range(headerRow, 1, headerRow, col - 1);
            headerRange.Style.Font.Bold = true;
            headerRange.Style.Fill.BackgroundColor = XLColor.FromArgb(229, 231, 235);
            headerRange.Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
            headerRange.Style.Border.InsideBorder = XLBorderStyleValues.Thin;

            var dataRange = ws.Range(headerRow + 1, 1, Math.Max(headerRow + 1, current - 1), col - 1);
            dataRange.Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
            dataRange.Style.Border.InsideBorder = XLBorderStyleValues.Dotted;

            ws.Range(headerRow, 1, Math.Max(headerRow + 1, current - 1), col - 1).SetAutoFilter();
            ws.Columns().AdjustToContents();
            ws.Column(12).Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center; // Folios
            ws.Column(Math.Min(25, col - 1)).Style.NumberFormat.Format = "0.00"; // Confianza Serie (if present)
            ws.SheetView.FreezeRows(headerRow);

            var dirOut = Path.GetDirectoryName(outputPath) ?? AppContext.BaseDirectory;
            if (!Directory.Exists(dirOut)) Directory.CreateDirectory(dirOut);
            wb.SaveAs(outputPath);

            // Simple verification: ensure basic headers exist
            try
            {
                using var verifyWb = new XLWorkbook(outputPath);
                var verifyWs = verifyWb.Worksheet("Inventario");
                var headersList = new List<string>();
                for (int c = 1; c < col; c++)
                {
                    var h = verifyWs.Cell(headerRow, c).GetString().Trim();
                    if (!string.IsNullOrEmpty(h)) headersList.Add(h);
                }

                string Normalize(string s)
                {
                    if (string.IsNullOrEmpty(s)) return "";
                    var formD = s.Normalize(NormalizationForm.FormD);
                    var sb = new StringBuilder();
                    foreach (var ch in formD)
                    {
                        var uc = CharUnicodeInfo.GetUnicodeCategory(ch);
                        if (uc != UnicodeCategory.NonSpacingMark) sb.Append(ch);
                    }
                    var recomposed = sb.ToString().Normalize(NormalizationForm.FormC);
                    var cleaned = new StringBuilder();
                    foreach (var ch in recomposed)
                    {
                        if (char.IsLetterOrDigit(ch)) cleaned.Append(ch);
                    }
                    return cleaned.ToString().ToLowerInvariant();
                }

                var normHeaders = headersList.Select(Normalize).ToList();
                var requiredKeywords = new[] { "fondo", "titulo", "asunto", "fecha", "folios", "soporte", "productor" };
                var missing = requiredKeywords.Where(kw => !normHeaders.Any(nh => nh.Contains(kw))).ToList();
                if (missing.Any())
                {
                    throw new InvalidDataException($"El archivo generado carece de columnas esperadas: {string.Join(",", missing)}");
                }
            }
            catch (Exception ex)
            {
                throw new Exception("Validación del archivo Excel falló: " + ex.Message, ex);
            }

            if (copyToExports)
            {
                try
                {
                    DirectoryInfo? candidate = new DirectoryInfo(AppContext.BaseDirectory);
                    DirectoryInfo? workspaceRoot = null;
                    while (candidate != null)
                    {
                        if (string.Equals(candidate.Name, "Catalogador", StringComparison.OrdinalIgnoreCase))
                        {
                            workspaceRoot = candidate;
                            break;
                        }
                        candidate = candidate.Parent;
                    }

                    string exportsDir = workspaceRoot != null ? Path.Combine(workspaceRoot.FullName, "exports") : Path.Combine(dirOut, "exports");
                    if (!Directory.Exists(exportsDir)) Directory.CreateDirectory(exportsDir);
                    var dest = Path.Combine(exportsDir, Path.GetFileName(outputPath));
                    File.Copy(outputPath, dest, true);
                    if (openAfter)
                    {
                        Process.Start(new ProcessStartInfo(dest) { UseShellExecute = true });
                    }
                }
                catch (Exception ex)
                {
                    Catalogador.App.Helpers.SimpleLogger.Warn("Warning: failed to copy export to exports folder: " + ex.Message);
                }
            }
        }
    }
}
