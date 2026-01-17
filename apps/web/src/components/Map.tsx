import { useEffect, useRef } from 'react';
import maplibregl from 'maplibre-gl';
import { Protocol } from 'pmtiles';
import 'maplibre-gl/dist/maplibre-gl.css';
import { useMapStore, TILE_SOURCES } from '../store/mapStore';
import {
  LAYER_CONFIG,
  CYCLING_TAGS,
  TOOLTIP_LAYERS,
  HAS_OVERTURE_SEGMENT_SOURCE,
  OVERTURE_SEGMENT_PM_TILES_URL,
  OVERTURE_SEGMENT_SOURCE_ID,
} from '../layers.config';
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

const PMTILES_URL = `http://localhost:8080/tiles.pmtiles?v=${Date.now()}`;

interface MapProps {
  onError?: (message: string, type: 'error' | 'success' | 'info' | 'warning') => void;
}

export function Map({ onError }: MapProps) {
  const mapContainer = useRef<HTMLDivElement>(null);
  const tooltipRef = useRef<HTMLDivElement>(null);
  const { setMap, center, zoom, tileSource, setError, clearError } = useMapStore();
  const overtureEnabled = useMapStore(
    (state) => state.layerVisibility['overture-cycle'] ?? false
  );
  const mapRef = useRef<maplibregl.Map | null>(null);

  useEffect(() => {
    if (!mapContainer.current) return;

    let handlersAdded = false; // Track if handlers are already added
    let mouseMoveHandler: ((event: maplibregl.MapMouseEvent) => void) | null = null;
    let mouseOutHandler: ((event: maplibregl.MapMouseEvent) => void) | null = null;
    let sourceDataHandler: ((event: maplibregl.MapSourceDataEvent) => void) | null = null;
    let zoomHandler: ((
      event: maplibregl.MapLibreEvent<MouseEvent | TouchEvent | WheelEvent | undefined>
    ) => void) | null = null;
    let errorHandler: ((event: maplibregl.ErrorEvent) => void) | null = null;
    let styleLoadHandler: ((event?: maplibregl.MapLibreEvent) => void) | null = null;

    const initializeMap = async () => {
      try {
        clearError();
        
        const newMap = new maplibregl.Map({
          container: mapContainer.current!,
          style: TILE_SOURCES[tileSource].style,
          center: center as [number, number],
          zoom: zoom,
        });

        mapRef.current = newMap;

        // Expose map instance globally for debugging
        (window as any).map = newMap;
        console.log('Map instance exposed on window.map');

        // Log zoom level changes
        zoomHandler = (_event) => {
          console.log('Current zoom level:', newMap.getZoom().toFixed(2));
        };
        newMap.on('zoom', zoomHandler);

        errorHandler = (event) => {
          if (event.error?.message) {
            console.error('Map error:', event.error.message);
            const errorMsg = `Map error: ${event.error.message}`;
            setError(errorMsg);
            if (onError) {
              onError(errorMsg, 'error');
            }
          }
        };
        newMap.on('error', errorHandler);

        const onStyleLoad = async () => {
          const isOvertureEnabled =
            useMapStore.getState().layerVisibility['overture-cycle'] ?? false;
          clearError();

          // Save map reference for layer visibility toggling
          mapRef.current = newMap;

          const ensureSources = () => {
            if (tileSource === 'local' && !newMap.getSource('local-tiles')) {
              newMap.addSource('local-tiles', {
                type: 'vector',
                url: `pmtiles://${PMTILES_URL}`,
                attribution: '© OpenStreetMap contributors',
              });
            }

            if (
              isOvertureEnabled &&
              HAS_OVERTURE_SEGMENT_SOURCE &&
              OVERTURE_SEGMENT_PM_TILES_URL &&
              !newMap.getSource(OVERTURE_SEGMENT_SOURCE_ID)
            ) {
              newMap.addSource(OVERTURE_SEGMENT_SOURCE_ID, {
                type: 'vector',
                url: `pmtiles://${OVERTURE_SEGMENT_PM_TILES_URL}`,
                attribution: '© Overture Maps Foundation & contributors',
              });
            }
          };

          const addConfiguredLayers = () => {
            Object.values(LAYER_CONFIG).forEach((layerConfig) => {
              if (layerConfig.id === 'overture-cycle' && !isOvertureEnabled) {
                return;
              }

              if (newMap.getLayer(layerConfig.id)) {
                return;
              }

              if (!newMap.getSource(layerConfig.source)) {
                return;
              }

              newMap.addLayer(layerConfig);
              console.log(`Layer added: ${layerConfig.id}`);
              
              // Apply initial visibility from store
              const layerVisibility = useMapStore.getState().layerVisibility[layerConfig.id];
              if (layerVisibility !== undefined) {
                newMap.setLayoutProperty(
                  layerConfig.id,
                  'visibility',
                  layerVisibility ? 'visible' : 'none'
                );
                console.log(`Layer ${layerConfig.id} initial visibility: ${layerVisibility ? 'visible' : 'none'}`);
              }
            });
          };

          ensureSources();
          addConfiguredLayers();

          if (!sourceDataHandler) {
            sourceDataHandler = (event) => {
              if (event.isSourceLoaded) {
                addConfiguredLayers();
              }
            };
            newMap.on('sourcedata', sourceDataHandler);
          }

          if (!handlersAdded) {
            handlersAdded = true;
            console.log('Attaching global tooltip handler');

            // Use requestAnimationFrame to throttle tooltip updates
            let pendingTooltipUpdate: number | null = null;
            let lastMouseEvent: maplibregl.MapMouseEvent | null = null;

            mouseMoveHandler = (e) => {
              lastMouseEvent = e;

              if (pendingTooltipUpdate === null) {
                pendingTooltipUpdate = requestAnimationFrame(() => {
                  if (!lastMouseEvent) {
                    pendingTooltipUpdate = null;
                    return;
                  }

                  const features = newMap.queryRenderedFeatures(lastMouseEvent.point, {
                    layers: TOOLTIP_LAYERS.filter((id) => newMap.getLayer(id)),
                  });

                  if (features.length > 0) {
                    newMap.getCanvas().style.cursor = 'pointer';

                    const feature = features[0];
                    const properties = feature.properties || {};

                    const tags = CYCLING_TAGS
                      .filter((tag) => properties[tag] !== undefined && properties[tag] !== null)
                      .map((tag) => `${tag}: ${properties[tag]}`);

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
            };

            mouseOutHandler = (_event) => {
              if (pendingTooltipUpdate !== null) {
                cancelAnimationFrame(pendingTooltipUpdate);
                pendingTooltipUpdate = null;
              }
              if (tooltipRef.current) {
                tooltipRef.current.style.display = 'none';
              }
            };

            newMap.on('mousemove', mouseMoveHandler);
            newMap.on('mouseout', mouseOutHandler);
          }
        };

        styleLoadHandler = onStyleLoad;
        newMap.on('style.load', onStyleLoad);
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
        const map = mapRef.current as maplibregl.Map;
        if (mouseMoveHandler) {
          map.off('mousemove', mouseMoveHandler);
        }
        if (mouseOutHandler) {
          map.off('mouseout', mouseOutHandler);
        }
        if (sourceDataHandler) {
          map.off('sourcedata', sourceDataHandler);
        }
        if (zoomHandler) {
          map.off('zoom', zoomHandler);
        }
        if (errorHandler) {
          map.off('error', errorHandler);
        }
        if (styleLoadHandler) {
          map.off('style.load', styleLoadHandler);
        }
        map.remove();
        mapRef.current = null;
      }

      if (tooltipRef.current) {
        tooltipRef.current.style.display = 'none';
      }
    };
  }, [setMap, center, zoom, tileSource, onError, setError, clearError]);

  useEffect(() => {
    if (
      !HAS_OVERTURE_SEGMENT_SOURCE ||
      !OVERTURE_SEGMENT_PM_TILES_URL ||
      !mapRef.current
    ) {
      return;
    }

    const map = mapRef.current;
    const overtureLayerConfig = LAYER_CONFIG['overture-cycle'];
    const overtureCyclewaysConfig = LAYER_CONFIG['overture-cycleways'];

    if (!overtureLayerConfig || !overtureCyclewaysConfig) {
      return;
    }

    // Ensure style is loaded before trying to add/remove layers
    const handleOvertureToggle = () => {
      if (overtureEnabled) {
        try {
          if (!map.getSource(OVERTURE_SEGMENT_SOURCE_ID)) {
            map.addSource(OVERTURE_SEGMENT_SOURCE_ID, {
              type: 'vector',
              url: `pmtiles://${OVERTURE_SEGMENT_PM_TILES_URL}`,
              attribution: '© Overture Maps Foundation & contributors',
            });
          }

          // Add overture-cycle layer
          if (!map.getLayer(overtureLayerConfig.id)) {
            map.addLayer(overtureLayerConfig);
            console.log('Overture layer added');
          } else {
            map.setLayoutProperty(overtureLayerConfig.id, 'visibility', 'visible');
            console.log('Overture layer made visible');
          }

          // Add overture-cycleways layer
          if (!map.getLayer(overtureCyclewaysConfig.id)) {
            map.addLayer(overtureCyclewaysConfig);
            console.log('Overture cycleways layer added');
          } else {
            map.setLayoutProperty(overtureCyclewaysConfig.id, 'visibility', 'visible');
            console.log('Overture cycleways layer made visible');
          }
        } catch (error) {
          console.error('Error adding Overture layer:', error);
        }
      } else {
        try {
          if (map.getLayer(overtureLayerConfig.id)) {
            map.removeLayer(overtureLayerConfig.id);
            console.log('Overture layer removed');
          }
          if (map.getLayer(overtureCyclewaysConfig.id)) {
            map.removeLayer(overtureCyclewaysConfig.id);
            console.log('Overture cycleways layer removed');
          }
          if (map.getSource(OVERTURE_SEGMENT_SOURCE_ID)) {
            map.removeSource(OVERTURE_SEGMENT_SOURCE_ID);
          }
        } catch (error) {
          console.error('Error removing Overture layer:', error);
        }
      }
    };

    // Only run after style is loaded
    if (map.isStyleLoaded()) {
      handleOvertureToggle();
    } else {
      map.on('style.load', handleOvertureToggle);
      return () => {
        map.off('style.load', handleOvertureToggle);
      };
    }
  }, [overtureEnabled]);

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
