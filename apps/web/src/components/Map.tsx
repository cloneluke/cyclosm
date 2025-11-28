import { useEffect, useRef } from 'react';
import maplibregl from 'maplibre-gl';
import { Protocol } from 'pmtiles';
import 'maplibre-gl/dist/maplibre-gl.css';
import { useMapStore, TILE_SOURCES } from '../store/mapStore';
import './Map.css';

// Register PMTiles protocol
let protocolInitialized = false;

interface MapProps {
  onError?: (message: string, type: 'error' | 'success' | 'info' | 'warning') => void;
}

export function Map({ onError }: MapProps) {
  const mapContainer = useRef<HTMLDivElement>(null);
  const { setMap, center, zoom, tileSource, setError, clearError } = useMapStore();

  useEffect(() => {
    if (!mapContainer.current) return;

    // Initialize PMTiles protocol once
    if (!protocolInitialized) {
      const protocol = new Protocol();
      maplibregl.addProtocol('pmtiles', protocol.tile);
      protocolInitialized = true;
    }

    try {
      clearError();
      const newMap = new maplibregl.Map({
        container: mapContainer.current,
        style: TILE_SOURCES[tileSource].style,
        center: center as [number, number],
        zoom: zoom,
      });

      // Listen for tile loading errors
      newMap.on('error', (event) => {
        console.error('Map error event:', event.error);
        // Only handle tile-related errors, not style validation errors
        if (event.error?.message?.includes('tile')) {
          const errorMsg = `Tile loading error: ${event.error.message}`;
          setError(errorMsg);
          if (onError) {
            onError(errorMsg, 'error');
          }
          // Attempt fallback to public tiles if on local
          if (tileSource === 'local') {
            setTimeout(() => {
              setError(null);
              onError?.('Switching to public tiles...', 'info');
            }, 2000);
          }
        }
      });

      // Track style loading
      newMap.on('style.load', () => {
        console.log('Map style loaded successfully');
        clearError();
      });

      setMap(newMap);

      return () => {
        if (newMap) {
          newMap.remove();
        }
      };
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : 'Failed to initialize map';
      console.error('Error initializing map:', error);
      setError(errorMsg);
      if (onError) {
        onError(errorMsg, 'error');
      }
    }
  }, [setMap, center, zoom, tileSource, onError, setError, clearError]);

  return <div ref={mapContainer} className="map-container" />;
}
