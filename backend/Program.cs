using Catalogador.Api.Services;
using Catalogador.Api.Utils;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<TrdService>();
builder.Services.AddSingleton<OcrSimulator>();

var corsOrigins = builder.Configuration.GetSection("Cors:Origins").Get<string[]>() ?? new[] { "http://localhost:5173" };
builder.Services.AddCors(options =>
{
    options.AddPolicy("app", p => p.WithOrigins(corsOrigins).AllowAnyHeader().AllowAnyMethod().AllowCredentials());
});

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c => c.SwaggerDoc("v1", new OpenApiInfo { Title = "Catalogador API", Version = "v1" }));

var app = builder.Build();
app.UseCors("app");
app.UseSwagger();
app.UseSwaggerUI();

app.MapGet("/api/trd", (TrdService trd) => Results.Ok(trd.GetAll()));

app.MapPost("/api/analyze", async (HttpRequest req, OcrSimulator ocr) => Results.Ok(ocr.Analyze("lote.pdf")));

app.MapPost("/api/validate/{id}", (string id, OcrSimulator ocr) =>
{
    var result = ocr.Analyze("lote.pdf");
    var d = result.Unidades.FirstOrDefault(x => x.Id == id);
    if (d is null) return Results.NotFound();
    d.Validado = true;
    d.RevisadoPor = "Archivista";
    d.RevisadoEl = DateTime.UtcNow;
    return Results.Ok(d);
});

app.MapPost("/api/export/csv", (OcrSimulator ocr) => Results.File(InventoryExporter.ToCsv(ocr.Analyze("lote.pdf").Unidades), "text/csv", "inventario.csv"));
app.MapPost("/api/export/xlsx", (OcrSimulator ocr) => Results.File(InventoryExporter.ToXlsx(ocr.Analyze("lote.pdf").Unidades), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "inventario.xlsx"));
app.MapPost("/api/export/bagit", (OcrSimulator ocr) => Results.File(InventoryExporter.MakeBagItZip(ocr.Analyze("lote.pdf").Unidades), "application/zip", "transferencia_bagit.zip"));

app.Run();
