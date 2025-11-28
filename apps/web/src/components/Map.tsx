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
      try {
        const protocol = new Protocol();
        maplibregl.addProtocol('pmtiles', protocol.tile);
        protocolInitialized = true;
        console.log('PMTiles protocol initialized');
      } catch (e) {
        console.error('Failed to initialize PMTiles protocol:', e);
      }
    }

    try {
      clearError();
      
      const newMap = new maplibregl.Map({
        container: mapContainer.current,
        style: TILE_SOURCES[tileSource].style,
        center: center as [number, number],
        zoom: zoom,
      });

      newMap.on('error', (event) => {
        console.error('Map error event:', event);
        if (event.error?.message) {
          console.error('Map error:', event.error.message);
        }
      });

      newMap.on('data', (e) => {
        if (e.dataType === 'source' && e.sourceId === 'local-tiles') {
          console.log('Data event for local-tiles:', e);
        }
      });

      newMap.on('sourcedata', (e) => {
        if (e.sourceId === 'local-tiles') {
          console.log('Sourcedata event:', e.dataType, 'isSourceLoaded:', e.isSourceLoaded);
        }
      });

      newMap.on('style.load', () => {
        clearError();
        
        // Add local PMTiles source if using local tiles
        if (tileSource === 'local') {
          console.log('Adding local-tiles source...');
          
          if (!newMap.getSource('local-tiles')) {
            newMap.addSource('local-tiles', {
              type: 'vector',
              url: 'pmtiles://http://localhost:8080/data/tiles.pmtiles',
              attribution: '© OpenStreetMap contributors'
            });
          }
          
          // Wait for source to be loaded before adding layers
          newMap.on('sourcedata', (e) => {
            if (e.sourceId === 'local-tiles' && e.isSourceLoaded) {
              console.log('Local tiles source loaded, adding layers...');
              
              // Debug: log tile data
              const source = newMap.getSource('local-tiles');
              console.log('Source:', source);
              
              // Check what features are available
              setTimeout(() => {
                // Get a rendered feature to see what layers exist
                const center = newMap.getCenter();
                const point = newMap.project(center);
                const renderedFeatures = newMap.queryRenderedFeatures(point);
                console.log('Rendered features at center:', renderedFeatures.length);
                
                // Get unique source layers from local-tiles
                const localTileFeatures = renderedFeatures.filter(f => f.source === 'local-tiles');
                const sourceLayers = [...new Set(localTileFeatures.map(f => f.sourceLayer))];
                console.log('Source layers from local-tiles:', sourceLayers);
                
                if (localTileFeatures.length > 0) {
                  console.log('Sample local-tiles feature:', localTileFeatures[0]);
                }
              }, 1000);
              
              // Add cycling-specific layers
              // Debug: show all roads from local tiles
              if (!newMap.getLayer('local-roads-debug')) {
                try {
                  newMap.addLayer({
                    id: 'local-roads-debug',
                    type: 'line',
                    source: 'local-tiles',
                    'source-layer': 'roads',
                    paint: {
                      'line-color': '#ff0000',
                      'line-width': 1,
                      'line-opacity': 0.3
                    }
                  });
                  console.log('Added debug road layer');
                } catch (err) {
                  console.error('Error adding debug road layer:', err);
                }
              }
              
              if (!newMap.getLayer('cycleways')) {
                try {
                  newMap.addLayer({
                    id: 'cycleways',
                    type: 'line',
                    source: 'local-tiles',
                    'source-layer': 'roads',
                    filter: ['all',
                      ['has', 'highway'],
                      ['in', ['get', 'highway'], ['literal', ['path', 'cycleway']]]
                    ],
                    paint: {
                      'line-color': '#2fb344',
                      'line-width': [
                        'interpolate',
                        ['exponential', 1.5],
                        ['zoom'],
                        10, 2,
                        14, 4,
                        18, 8
                      ],
                      'line-opacity': 0.9
                    }
                  });
                  console.log('Added cycleway layer');
                } catch (err) {
                  console.error('Error adding cycleway layer:', err);
                }
              }
              
              if (!newMap.getLayer('poi-points')) {
                try {
                  newMap.addLayer({
                    id: 'poi-points',
                    type: 'circle',
                    source: 'local-tiles',
                    'source-layer': 'poi',
                    minzoom: 13,
                    paint: {
                      'circle-radius': 5,
                      'circle-color': '#d4a574',
                      'circle-opacity': 0.6,
                      'circle-stroke-width': 1,
                      'circle-stroke-color': '#ffffff'
                    }
                  });
                  console.log('Added POI layer');
                } catch (err) {
                  console.error('Error adding POI layer:', err);
                }
              }
            }
          });
        }
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
