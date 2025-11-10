import React from 'react'
import { createRoot } from 'react-dom/client'
// Import the TSX App file (extensionless import also works)
import App from './App'
import './styles.css'

const root = document.getElementById('root')
if (root) {
  createRoot(root).render(
    <React.StrictMode>
      <App />
    </React.StrictMode>
  )
}
