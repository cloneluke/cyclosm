import { useEffect, useRef } from 'react';
import maplibregl from 'maplibre-gl';
import { Protocol } from 'pmtiles';
import 'maplibre-gl/dist/maplibre-gl.css';
import { useMapStore, TILE_SOURCES } from '../store/mapStore';
import './Map.css';

// Register PMTiles protocol GLOBALLY before any map initialization
const protocol = new Protocol({ metadata: true });

// Wrap protocol.tile to remove bounds from TileJSON (MapLibre 5.x bounds strictness fix)
const originalTile = protocol.tile.bind(protocol);
const wrappedTile = (params: any, abortController?: any): any => {
  const result = originalTile(params, abortController);
  if (result instanceof Promise) {
    return result.then((res: any) => {
      if (params.type === 'json' && res.data?.bounds) {
        // Remove bounds to allow viewing outside strict PMTiles bounds
        delete res.data.bounds;
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

  const formatFeatureProperties = (properties: Record<string, any>) => {
    // Extract cycling-relevant tags
    const cyclingTags = ['highway', 'bicycle', 'cycleway', 'surface', 'name', 'access', 'foot', 'amenity', 'shop', 'leisure'];
    
    return cyclingTags
      .filter(tag => properties[tag] !== undefined && properties[tag] !== null)
      .map(tag => `${tag}: ${properties[tag]}`)
      .join('<br/>');
  };

  useEffect(() => {
    if (!mapContainer.current) return;

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
              // Add roads layer with zoom-appropriate styling
              if (!newMap.getLayer('roads-base')) {
                newMap.addLayer({
                  id: 'roads-base',
                  type: 'line',
                  source: 'local-tiles',
                  'source-layer': 'transportation',
                  filter: ['!=', ['get', 'brunnel'], 'tunnel'],
                  paint: {
                    'line-color': [
                      'match',
                      ['get', 'class'],
                      'motorway', '#e892a2',
                      'trunk', '#f9b29c',
                      'primary', '#fcd6a4',
                      'secondary', '#f7fabf',
                      'tertiary', '#ffffff',
                      'minor', '#ffffff',
                      'service', '#ffffff',
                      '#cccccc'
                    ],
                    'line-width': [
                      'interpolate',
                      ['exponential', 1.5],
                      ['zoom'],
                      5, [
                        'match',
                        ['get', 'class'],
                        'motorway', 0.5,
                        'trunk', 0.4,
                        0
                      ],
                      12, [
                        'match',
                        ['get', 'class'],
                        'motorway', 3,
                        'trunk', 2.5,
                        'primary', 2,
                        'secondary', 1.5,
                        'tertiary', 1,
                        0.5
                      ],
                      16, [
                        'match',
                        ['get', 'class'],
                        'motorway', 8,
                        'trunk', 7,
                        'primary', 6,
                        'secondary', 5,
                        'tertiary', 4,
                        'minor', 3,
                        2
                      ]
                    ]
                  }
                });
              }
              
              // Add cycling infrastructure (custom schema with zoom 5)
              if (!newMap.getLayer('cycleways')) {
                newMap.addLayer({
                  id: 'cycleways',
                  type: 'line',
                  source: 'local-tiles',
                  'source-layer': 'transportation',
                  filter: ['in', ['get', 'highway'], ['literal', ['path', 'track', 'cycleway', 'footway', 'steps', 'pedestrian']]],
                  minzoom: 5,
                  paint: {
                    'line-color': '#2fb344',
                    'line-width': [
                      'interpolate',
                      ['exponential', 1.5],
                      ['zoom'],
                      5, 1,
                      8, 1.5,
                      10, 2,
                      13, 3,
                      16, 5,
                      18, 8
                    ],
                    'line-opacity': 0.9
                  }
                });
                console.log('Cycleways layer added (minzoom 5 with custom CyclOSM schema)');
              }
              
              if (!newMap.getLayer('poi-points')) {
                newMap.addLayer({
                  id: 'poi-points',
                  type: 'circle',
                  source: 'local-tiles',
                  'source-layer': 'poi',
                  minzoom: 14,
                  paint: {
                    'circle-radius': 4,
                    'circle-color': '#d4a574',
                    'circle-opacity': 0.7,
                    'circle-stroke-width': 1,
                    'circle-stroke-color': '#ffffff'
                  }
                });
              }

              // Add hover tooltip handlers
              ['cycleways', 'poi-points', 'roads-base'].forEach(layerId => {
                if (newMap.getLayer(layerId)) {
                  newMap.on('mousemove', layerId, (e) => {
                    if (e.features && e.features.length > 0) {
                      const feature = e.features[0];
                      const properties = feature.properties || {};
                      const content = formatFeatureProperties(properties);
                      
                      if (tooltipRef.current && content) {
                        tooltipRef.current.innerHTML = content;
                        tooltipRef.current.style.left = e.originalEvent.pageX + 10 + 'px';
                        tooltipRef.current.style.top = e.originalEvent.pageY + 10 + 'px';
                        tooltipRef.current.style.display = 'block';
                      }
                    }
                  });

                  newMap.on('mouseleave', layerId, () => {
                    if (tooltipRef.current) {
                      tooltipRef.current.style.display = 'none';
                    }
                  });
                }
              });
            }
          });
        }
      });        setMap(newMap);
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
  }, [setMap, center, zoom, tileSource, onError, setError, clearError]);

  return (
    <div ref={mapContainer} className="map-container">
      <div 
        ref={tooltipRef} 
        className="cycling-tooltip"
        style={{
          display: 'none',
          position: 'fixed',
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
