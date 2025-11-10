// Frontend configuration. Change the API_BASE to match the FastAPI service.
// Default assumes the API listens on http://127.0.0.1:8000 (aligned with NSSM/setup)
// You can override at build time with REACT_APP_API_BASE, e.g.:
// REACT_APP_API_BASE=http://127.0.0.1:8123 npm run build
export const API_BASE = process.env.REACT_APP_API_BASE || 'http://127.0.0.1:8000';
