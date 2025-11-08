using Catalogador.Api.Models;
using ClosedXML.Excel;
using System.Text;
using ICSharpCode.SharpZipLib.Zip;

namespace Catalogador.Api.Utils;

public static class InventoryExporter
{
    public static byte[] ToCsv(IEnumerable<DocumentoBase> items)
    {
        var sb = new StringBuilder();
        sb.AppendLine("ID,Unidad,Expediente,Serie,Subserie,Tipo,Asunto,Productor,FechaDoc,FechaIni,FechaFin,Folios,Soporte,Temporalidad,Plazo,Destino");
        foreach (var d in items)
        {
            sb.AppendLine(string.Join(',', new string[] {
                d.Id,
                d.TipoUnidad,
                d.CodigoExpediente ?? "",
                d.Serie,
                d.Subserie ?? "",
                d.TipoDocumental ?? "",
                Escape(d.TituloAsunto),
                Escape(d.Productor),
                d.FechaDoc.ToString("yyyy-MM-dd"),
                d.FechaIni?.ToString("yyyy-MM-dd") ?? "",
                d.FechaFin?.ToString("yyyy-MM-dd") ?? "",
                d.Folios.ToString(),
                d.Soporte,
                d.Temporalidad,
                d.PlazoConservacionAnios.ToString(),
                d.DestinoFinal
            }));
        }
        return Encoding.UTF8.GetBytes(sb.ToString());
    }

    public static byte[] ToXlsx(IEnumerable<DocumentoBase> items)
    {
        using var wb = new XLWorkbook();
        var ws = wb.Worksheets.Add("Inventario");
        var headers = new string[] {"ID","Unidad","Expediente","Serie","Subserie","Tipo","Asunto","Productor","FechaDoc","FechaIni","FechaFin","Folios","Soporte","Temporalidad","Plazo","Destino"};
        for (int i = 0; i < headers.Length; i++) ws.Cell(1, i + 1).Value = headers[i];
        int r = 2;
        foreach (var d in items)
        {
            ws.Cell(r,1).Value = d.Id;
            ws.Cell(r,2).Value = d.TipoUnidad;
            ws.Cell(r,3).Value = d.CodigoExpediente ?? "";
            ws.Cell(r,4).Value = d.Serie;
            ws.Cell(r,5).Value = d.Subserie ?? "";
            ws.Cell(r,6).Value = d.TipoDocumental ?? "";
            ws.Cell(r,7).Value = d.TituloAsunto;
            ws.Cell(r,8).Value = d.Productor;
            ws.Cell(r,9).Value = d.FechaDoc.ToString("yyyy-MM-dd");
            ws.Cell(r,10).Value = d.FechaIni?.ToString("yyyy-MM-dd") ?? "";
            ws.Cell(r,11).Value = d.FechaFin?.ToString("yyyy-MM-dd") ?? "";
            ws.Cell(r,12).Value = d.Folios;
            ws.Cell(r,13).Value = d.Soporte;
            ws.Cell(r,14).Value = d.Temporalidad;
            ws.Cell(r,15).Value = d.PlazoConservacionAnios;
            ws.Cell(r,16).Value = d.DestinoFinal;
            r++;
        }
        ws.Columns().AdjustToContents();
        using var ms = new MemoryStream();
        wb.SaveAs(ms);
        return ms.ToArray();
    }

    public static byte[] MakeBagItZip(IEnumerable<DocumentoBase> items)
    {
        using var ms = new MemoryStream();
        using var zip = new ZipOutputStream(ms);
        zip.SetLevel(3);
        void AddEntry(string path, string content)
        {
            var bytes = Encoding.UTF8.GetBytes(content);
            var entry = new ZipEntry(path) { DateTime = DateTime.Now };
            zip.PutNextEntry(entry);
            zip.Write(bytes, 0, bytes.Length);
            zip.CloseEntry();
        }

        AddEntry("bagit.txt", "BagIt-Version: 0.97\nTag-File-Character-Encoding: UTF-8\n");
        AddEntry("manifest-sha256.txt", "# simulado\n");
        AddEntry("metadata/inventario.csv", Encoding.UTF8.GetString(ToCsv(items)));
        AddEntry("logs/qa.txt", "QA: simulado\n");
        zip.Finish();
        return ms.ToArray();
    }

    private static string Escape(string s) => '"' + s.Replace("\"", "\"\"") + '"';
}
