const API = (window as any).__API__ || 'http://localhost:5000'

export async function fetchTRD() {
  const r = await fetch(`${API}/api/trd`)
  return r.json()
}

export async function analyzePDF(file?: File) {
  const fd = new FormData()
  if (file) fd.append('file', file)
  const r = await fetch(`${API}/api/analyze`, { method: 'POST', body: fd })
  return r.json()
}

export async function validateDoc(id: string) {
  const r = await fetch(`${API}/api/validate/${id}`, { method: 'POST' })
  return r.json()
}

export async function exportCSV() {
  const r = await fetch(`${API}/api/export/csv`, { method: 'POST' })
  return await r.blob()
}

export async function exportXLSX() {
  const r = await fetch(`${API}/api/export/xlsx`, { method: 'POST' })
  return await r.blob()
}

export async function exportBagIt() {
  const r = await fetch(`${API}/api/export/bagit`, { method: 'POST' })
  return await r.blob()
}
