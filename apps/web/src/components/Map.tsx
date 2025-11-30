import { useEffect, useRef } from 'react';
import maplibregl from 'maplibre-gl';
import { Protocol } from 'pmtiles';
import 'maplibre-gl/dist/maplibre-gl.css';
import { useMapStore, TILE_SOURCES } from '../store/mapStore';
import { LAYER_CONFIG, CYCLING_TAGS, TOOLTIP_LAYERS } from '../layers.config';
import './Map.css';

// Register PMTiles protocol GLOBALLY before any map initialization
const protocol = new Protocol({ metadata: true });

// Cache for TileJSON metadata (to avoid re-fetching on every tile request)
let tilejsonCache: any = null;

// Wrap protocol.tile to remove bounds from TileJSON (MapLibre 5.x bounds strictness fix)
// and cache TileJSON to avoid repeated processing
const originalTile = protocol.tile.bind(protocol);
const wrappedTile = (params: any, abortController?: any): any => {
  // Return cached TileJSON if available
  if (params.type === 'json' && tilejsonCache) {
    return Promise.resolve({ data: tilejsonCache });
  }

  const result = originalTile(params, abortController);
  if (result instanceof Promise) {
    return result.then((res: any) => {
      if (params.type === 'json' && res.data?.bounds) {
        // Remove bounds and cache for future requests
        delete res.data.bounds;
        tilejsonCache = res.data;
      }
      return res;
    });
  }
  return result;
};

maplibregl.addProtocol('pmtiles', wrappedTile as any);

const PMTILES_URL = 'http://localhost:8080/tiles.pmtiles';

interface MapProps {
  onError?: (message: string, type: 'error' | 'success' | 'info' | 'warning') => void;
}

export function Map({ onError }: MapProps) {
  const mapContainer = useRef<HTMLDivElement>(null);
  const tooltipRef = useRef<HTMLDivElement>(null);
  const { setMap, center, zoom, tileSource, setError, clearError } = useMapStore();
  const mapRef = useRef<maplibregl.Map | null>(null);

  useEffect(() => {
    if (!mapContainer.current) return;

    let handlersAdded = false; // Track if handlers are already added

    const initializeMap = async () => {
      try {
        clearError();
        
        const newMap = new maplibregl.Map({
          container: mapContainer.current!,
          style: TILE_SOURCES[tileSource].style,
          center: center as [number, number],
          zoom: zoom,
        });

        // Expose map instance globally for debugging
        (window as any).map = newMap;
        console.log('Map instance exposed on window.map');

        // Log zoom level changes
        newMap.on('zoom', () => {
          console.log('Current zoom level:', newMap.getZoom().toFixed(2));
        });

      newMap.on('error', (event) => {
        if (event.error?.message) {
          console.error('Map error:', event.error.message);
          const errorMsg = `Map error: ${event.error.message}`;
          setError(errorMsg);
          if (onError) {
            onError(errorMsg, 'error');
          }
        }
      });

        newMap.on('style.load', async () => {
        clearError();
        
        // Save map reference for layer visibility toggling
        mapRef.current = newMap;

        // Add local PMTiles source if using local tiles
        if (tileSource === 'local') {
          if (!newMap.getSource('local-tiles')) {
            newMap.addSource('local-tiles', {
              type: 'vector',
              url: `pmtiles://${PMTILES_URL}`,
              attribution: '© OpenStreetMap contributors'
            });
          }
          
          // Wait for source to be loaded before adding layers
          newMap.on('sourcedata', (e) => {
            if (e.sourceId === 'local-tiles' && e.isSourceLoaded) {
              // Add all layers from configuration
              Object.values(LAYER_CONFIG).forEach((layerConfig) => {
                if (!newMap.getLayer(layerConfig.id)) {
                  newMap.addLayer(layerConfig);
                  console.log(`Layer added: ${layerConfig.id}`);
                }
              });

              // Add hover tooltip handlers (only once per map initialization)
              if (handlersAdded) return;
              handlersAdded = true;
              
              console.log('Attaching global tooltip handler');
              
              // Use requestAnimationFrame to throttle tooltip updates
              let pendingTooltipUpdate: number | null = null;
              let lastMouseEvent: any = null;

              // Global mousemove handler for better reliability
              newMap.on('mousemove', (e) => {
                lastMouseEvent = e;

                if (pendingTooltipUpdate === null) {
                  pendingTooltipUpdate = requestAnimationFrame(() => {
                    if (!lastMouseEvent) {
                      pendingTooltipUpdate = null;
                      return;
                    }

                    // Query all tooltip layers at once
                    const features = newMap.queryRenderedFeatures(lastMouseEvent.point, {
                      layers: TOOLTIP_LAYERS.filter(id => newMap.getLayer(id))
                    });

                    if (features.length > 0) {
                      newMap.getCanvas().style.cursor = 'pointer';
                      
                      const feature = features[0];
                      const properties = feature.properties || {};
                      
                      // Debug log (throttled)
                      // console.log('Hover feature:', properties);

                      // Extract cycling-relevant tags using memoized constant
                      const tags = CYCLING_TAGS
                        .filter(tag => properties[tag] !== undefined && properties[tag] !== null)
                        .map(tag => `${tag}: ${properties[tag]}`);
                      
                      const content = tags.join('<br/>');
                      
                      if (tooltipRef.current && content) {
                        tooltipRef.current.innerHTML = content;
                        tooltipRef.current.style.left = lastMouseEvent.point.x + 15 + 'px';
                        tooltipRef.current.style.top = lastMouseEvent.point.y + 15 + 'px';
                        tooltipRef.current.style.display = 'block';
                      }
                    } else {
                      newMap.getCanvas().style.cursor = '';
                      if (tooltipRef.current) {
                        tooltipRef.current.style.display = 'none';
                      }
                    }
                    
                    pendingTooltipUpdate = null;
                  });
                }
              });

              // Handle mouse leaving the map canvas
              newMap.on('mouseout', () => {
                if (pendingTooltipUpdate !== null) {
                  cancelAnimationFrame(pendingTooltipUpdate);
                  pendingTooltipUpdate = null;
                }
                if (tooltipRef.current) {
                  tooltipRef.current.style.display = 'none';
                }
              });
            }
          });
        }
      });
        setMap(newMap);
      } catch (error) {
        const errorMsg = error instanceof Error ? error.message : 'Failed to initialize map';
        console.error('Error initializing map:', error);
        setError(errorMsg);
        if (onError) {
          onError(errorMsg, 'error');
        }
      }
    };

    initializeMap();

    return () => {
      // Cleanup: Remove event listeners and destroy map to prevent memory leaks
      if (mapRef.current) {
        const map = mapRef.current as any;
        TOOLTIP_LAYERS.forEach(layerId => {
          if (map.getLayer(layerId)) {
            try {
              map.off('mousemove', layerId);
              map.off('mouseleave', layerId);
            } catch (e) {
              console.warn(`Could not remove listeners for ${layerId}:`, e);
            }
          }
        });
        map.off('zoom');
        map.off('error');
        map.off('style.load');
        map.off('sourcedata');
        map.remove();
        mapRef.current = null;
      }
    };
  }, [setMap, center, zoom, tileSource, onError, setError, clearError]);

  return (
    <div ref={mapContainer} className="map-container">
      <div 
        ref={tooltipRef} 
        className="cycling-tooltip"
        style={{
          display: 'none',
          position: 'absolute',
          backgroundColor: 'rgba(0, 0, 0, 0.8)',
          color: '#fff',
          padding: '8px 12px',
          borderRadius: '4px',
          fontSize: '12px',
          pointerEvents: 'none',
          zIndex: 1000,
          maxWidth: '300px',
          wordWrap: 'break-word',
          boxShadow: '0 2px 8px rgba(0,0,0,0.3)'
        }}
      />
    </div>
  );
}
