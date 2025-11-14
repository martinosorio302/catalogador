import React, { useState } from 'react';
import { simularAnalisisPDF } from './motorTRD';
import { API_BASE } from './config';

export default function App(){
  const [results, setResults] = useState(null);

  function testBridge(){
    console.log(window?.catalogador?.ping());
    alert("✅ Conexión Electron lista.\n" + JSON.stringify(window.catalogador.ping(), null, 2));
  }

  function runSimulation(){
    // Try calling backend API first; fall back to local simulation if it fails
    const url = `${API_BASE.replace(/\/+$/,'')}/classify`;
    fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ titulo: 'Acta de reunión', serie: 'Actas', asuntoUnidad: 'Recursos Humanos' })
    }).then(async res => {
      if (!res.ok) throw new Error('API error ' + res.status);
      const json = await res.json();
      setResults({ source: 'api', data: json });
    }).catch(err => {
      console.warn('API call failed, falling back to local simulation:', err);
      const out = simularAnalisisPDF('dummy.pdf');
      setResults({ source: 'local', data: out });
    });
  }

  return (
    <div style={{display:'flex', height:'100vh', fontFamily:'Segoe UI, Arial'}}>
      
      {/* PANEL LATERAL */}
      <aside style={{
        width:'260px', background:'#1e1f26', color:'#fff',
        padding:'18px', display:'flex', flexDirection:'column', gap:'12px'
      }}>
        <h2 style={{marginTop:0}}>📁 Catalogador EsSalud</h2>
        <button style={btn} onClick={testBridge}>🔄 Probar conexión</button>
        <button style={btn}>📄 Ingesta / Escaneo</button>
        <button style={btn}>🧠 OCR + IA</button>
        <button style={btn}>🗂 Clasificar Expedientes</button>
        <button style={btn}>📚 TRD / PCDA</button>
        <button style={btn}>📦 Inventario AGN</button>
        <button style={btn}>⬆ Exportar / Firmar Actas</button>
      </aside>

      {/* PANEL PRINCIPAL */}
      <main style={{flex:1, padding:'28px'}}>
        <h1>Catalogador de Archivos - EsSalud</h1>
        <p style={{opacity:0.8}}>Maqueta funcional convertida en aplicación real de escritorio.</p>

        <section style={{
          marginTop:'28px',
          padding:'20px',
          border:'1px dashed #999',
          borderRadius:'10px',
          background:'#fafafa',
          maxWidth:'850px'
        }}>
          <b>Flujo archivístico:</b>
          <ol>
            <li>Recepción / Digitalización / Clasificación primaria.</li>
            <li>OCR + Detección de tipo documental con IA.</li>
            <li>Segmentación por expediente y agrupación.</li>
            <li>Asignación normativa: TRD / PCDA (tiempos y disposición final).</li>
            <li>Generación automática de inventarios AGN + Actas.</li>
          </ol>
          <div style={{marginTop:18}}>
            <button style={{...btn, background:'#2563eb', color:'#fff'}} onClick={runSimulation}>▶ Simular análisis PDF</button>
          </div>

          {results && (
            <div style={{marginTop:16, padding:12, background:'#fff', border:'1px solid #ddd', borderRadius:8}}>
              <h3>Resultados de la simulación</h3>
              <pre style={{whiteSpace:'pre-wrap', fontSize:13}}>{JSON.stringify(results, null, 2)}</pre>
            </div>
          )}
        </section>
      </main>
    </div>
  );
}

const btn = {
  padding:'12px 14px',
  border:'none',
  background:'#32343c',
  borderRadius:'6px',
  textAlign:'left',
  cursor:'pointer',
  fontSize:'15px'
};
