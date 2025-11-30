import { useState, useCallback, lazy, Suspense } from 'react'
import type { ToastMessage } from './components/Toast'
import { Attribution } from './components/Attribution'
import { ErrorBoundary } from './components/ErrorBoundary'
import { ToastContainer } from './components/Toast'
import './App.css'

const Map = lazy(() => import('./components/Map').then((mod) => ({ default: mod.Map })))
const LayerToggle = lazy(() => import('./components/LayerToggle').then((mod) => ({ default: mod.LayerToggle })))
const SourceSelector = lazy(() => import('./components/SourceSelector').then((mod) => ({ default: mod.SourceSelector })))
const MapControls = lazy(() => import('./components/MapControls').then((mod) => ({ default: mod.MapControls })))

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
        <Suspense fallback={<div className="app-loading">Loading map…</div>}>
          <Map onError={addToast} />
        </Suspense>
        <Suspense fallback={null}>
          <SourceSelector />
        </Suspense>
        <Suspense fallback={null}>
          <LayerToggle />
        </Suspense>
        <Suspense fallback={null}>
          <MapControls />
        </Suspense>
        <Attribution />
        <ToastContainer toasts={toasts} onRemove={removeToast} />
      </div>
    </ErrorBoundary>
  )
}

export default App
