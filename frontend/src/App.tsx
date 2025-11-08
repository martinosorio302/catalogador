import React, { useEffect, useMemo, useState } from 'react'
import { analyzePDF, exportBagIt, exportCSV, exportXLSX, fetchTRD, validateDoc } from './api'
import type { DocumentoBase } from './types'
import { Button, Card, Input, Label, Tabs, TabsContent, TabsList, TabsTrigger, Badge, Progress } from './ui'

export default function App() {
  const [cargando, setCargando] = useState(false)
  const [datos, setDatos] = useState<DocumentoBase[]>([])
  const [filtro, setFiltro] = useState('')
  const [trd, setTrd] = useState<any[]>([])

  useEffect(() => { fetchTRD().then(setTrd); handleAnalyze() }, [])

  async function handleAnalyze(file?: File) {
    setCargando(true)
    const res = await analyzePDF(file)
    setDatos(res.unidades.map((u: any) => ({
      ...u,
      fechaDoc: toIso(u.fechaDoc),
      fechaIni: u.fechaIni ? toIso(u.fechaIni) : undefined,
      fechaFin: u.fechaFin ? toIso(u.fechaFin) : undefined,
      confidencial: u.confidencial ?? false,
      creadoEl: toIso(new Date().toISOString())
    })))
    setCargando(false)
  }
  const toIso = (d: string) => d.length > 10 ? d.slice(0,10) : d

  const datosFiltrados = useMemo(() => {
    const q = filtro.toLowerCase()
    return datos.filter(d => !q || d.id.toLowerCase().includes(q) || (d.codigoExpediente||'').toLowerCase().includes(q) || d.tituloAsunto.toLowerCase().includes(q) || d.serie.toLowerCase().includes(q) || (d.subserie||'').toLowerCase().includes(q) || (d.tipoDocumental||'').toLowerCase().includes(q))
  }, [datos, filtro])

  const kpis = useMemo(() => ({
    total: datos.length,
    expedientes: datos.filter(d=>d.tipoUnidad==='Expediente').length,
    docs: datos.filter(d=>d.tipoUnidad==='Documento').length,
    validados: datos.filter(d=>d.validado).length,
    permanentes: datos.filter(d=>d.temporalidad==='Permanente').length,
    eliminar: datos.filter(d=>d.destinoFinal==='Eliminación').length,
  }), [datos])

  const download = (name: string, blob: Blob) => { const url = URL.createObjectURL(blob); const a = document.createElement('a'); a.href=url; a.download=name; a.click(); URL.revokeObjectURL(url); }

  return (
    <div className="p-6 grid gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">Catalogador EsSalud</h1>
          <p className="opacity-80">Ingesta · OCR · Análisis · Revisión · Disposición · Exportación</p>
        </div>
        <div className="flex items-center gap-3">
          <Button onClick={() => handleAnalyze()}>{cargando ? 'Procesando…' : 'Cargar lote (demo)'} </Button>
          <input type="file" onChange={e => { const f = e.target.files?.[0]; if (f) handleAnalyze(f) }} />
        </div>
      </div>

      <div className="grid sm:grid-cols-2 lg:grid-cols-6 gap-3">
        <Card><div className="k">Total</div><div className="v">{kpis.total}</div></Card>
        <Card><div className="k">Expedientes</div><div className="v">{kpis.expedientes}</div></Card>
        <Card><div className="k">Documentos</div><div className="v">{kpis.docs}</div></Card>
        <Card><div className="k">Validados</div><div className="v">{kpis.validados}</div></Card>
        <Card><div className="k">Permanentes</div><div className="v">{kpis.permanentes}</div></Card>
        <Card><div className="k">A eliminar</div><div className="v">{kpis.eliminar}</div></Card>
      </div>

      <Card>
        <Tabs defaultValue="ingesta">
          <TabsList>
            <TabsTrigger value="ingesta">Ingesta</TabsTrigger>
            <TabsTrigger value="ocr">OCR</TabsTrigger>
            <TabsTrigger value="analitica">Análisis</TabsTrigger>
            <TabsTrigger value="revision">Revisión</TabsTrigger>
            <TabsTrigger value="disposicion">Disposición</TabsTrigger>
            <TabsTrigger value="export">Exportar</TabsTrigger>
          </TabsList>

          <TabsContent value="ingesta">
            <div className="grid gap-3 p-3">
              <Input placeholder="ID, expediente, asunto, serie…" value={filtro} onChange={e=>setFiltro(e.target.value)} />
              <Progress value={cargando ? 35 : 100} />
              <TablaDocumentos datos={datosFiltrados} onValidar={async (id) => { await validateDoc(id);  
                const now = new Date().toISOString();
                setDatos(prev => prev.map(d => d.id === id ? { ...d, validado: true, revisadoPor: 'Archivista', revisadoEl: now } : d))
              }} />
            </div>
          </TabsContent>

          <TabsContent value="ocr"><div className="p-3 text-sm opacity-80">Calidad OCR (simulada). Reescaneo sugerido: págs 17, 88, 145.</div></TabsContent>
          <TabsContent value="analitica"><div className="p-3 text-sm">TRD cargadas: {trd.length}. Temporalidad/Destino aplicados automáticamente.</div></TabsContent>
          <TabsContent value="revision"><TablaDocumentos datos={datosFiltrados} onValidar={async (id)=>{ await validateDoc(id); setDatos(prev => prev.map(d => d.id===id?{...d, validado:true}:d)) }} /></TabsContent>
          <TabsContent value="disposicion"><TablaDocumentos datos={datosFiltrados} onValidar={async (id)=>{ await validateDoc(id); setDatos(prev => prev.map(d => d.id===id?{...d, validado:true}:d)) }} /></TabsContent>

          <TabsContent value="export">
            <div className="p-3 flex gap-2">
              <Button onClick={async ()=> download('inventario.csv', await exportCSV())}>Exportar CSV</Button>
              <Button onClick={async ()=> download('inventario.xlsx', await exportXLSX())}>Exportar XLSX</Button>
              <Button onClick={async ()=> download('transferencia_bagit.zip', await exportBagIt())}>Generar SIP (BagIt)</Button>
            </div>
          </TabsContent>
        </Tabs>
      </Card>

      <div className="foot">Creador: Gary Martín Osorio Soto · INNOTECH · RUC 10439582842 · Tacna, Perú</div>
    </div>
  )
}

function TablaDocumentos({ datos, onValidar }: { datos: DocumentoBase[]; onValidar: (id: string)=>void }) {
  return (
    <div className="tbl">
      <table>
        <thead>
          <tr>
            <th>ID</th><th>Unidad</th><th>Expediente</th><th>Serie/Sub/Tipo</th><th>Asunto</th><th>Fecha</th><th>Extremas</th><th>Folios</th><th>Temporalidad</th><th>Plazo</th><th>Destino</th><th>Validación</th>
          </tr>
        </thead>
        <tbody>
          {datos.map(d => (
            <tr key={d.id}>
              <td>{d.id}</td>
              <td>{d.tipoUnidad}</td>
              <td>{d.codigoExpediente || '—'}</td>
              <td><div className="col"><span className="b">{d.serie}</span><span className="s">{d.subserie || '—'} · {d.tipoDocumental || '—'}</span></div></td>
              <td className="w">{d.tituloAsunto}</td>
              <td>{d.fechaDoc}</td>
              <td>{d.fechaIni ? `${d.fechaIni} → ${d.fechaFin}` : '—'}</td>
              <td>{d.folios}</td>
              <td>{d.temporalidad}</td>
              <td>{d.plazoConservacionAnios} años</td>
              <td>{d.destinoFinal}</td>
              <td>{d.validado ? <Badge>OK</Badge> : <Button onClick={()=>onValidar(d.id)}>Validar</Button>}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
