import { useState, useCallback } from 'react'
import { Map } from './components/Map'
import { SourceSelector } from './components/SourceSelector'
import { ErrorBoundary } from './components/ErrorBoundary'
import { ToastContainer, ToastMessage } from './components/Toast'
import './App.css'

function App() {
  const [toasts, setToasts] = useState<ToastMessage[]>([])

  const addToast = useCallback((message: string, type: 'error' | 'success' | 'info' | 'warning' = 'info', duration = 5000) => {
    const id = Math.random().toString(36).substr(2, 9)
    const toast: ToastMessage = { id, message, type, duration }
    setToasts((prev) => [...prev, toast])
  }, [])

  const removeToast = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id))
  }, [])

  return (
    <ErrorBoundary>
      <div className="app">
        <Map onError={addToast} />
        <SourceSelector />
        <ToastContainer toasts={toasts} onRemove={removeToast} />
      </div>
    </ErrorBoundary>
  )
}

export default App
