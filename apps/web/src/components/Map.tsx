import { useEffect, useRef } from 'react';
import maplibregl from 'maplibre-gl';
import { PMTiles, Protocol } from 'pmtiles';
import 'maplibre-gl/dist/maplibre-gl.css';
import { useMapStore } from '../store/mapStore';
import './Map.css';

// Register PMTiles protocol
let protocolInitialized = false;

export function Map() {
  const mapContainer = useRef<HTMLDivElement>(null);
  const { map, setMap, center, zoom } = useMapStore();

  useEffect(() => {
    if (!mapContainer.current) return;

    // Initialize PMTiles protocol once
    if (!protocolInitialized) {
      const protocol = new Protocol();
      maplibregl.addProtocol('pmtiles', protocol.tile);
      protocolInitialized = true;
    }

    try {
      const newMap = new maplibregl.Map({
        container: mapContainer.current,
        style: {
          version: 8,
          sources: {
            tiles: {
              type: 'vector',
              url: 'pmtiles://http://localhost:8080/tiles.pmtiles',
            },
          },
          layers: [
            {
              id: 'background',
              type: 'background',
              paint: {
                'background-color': '#f0f0f0',
              },
            },
            {
              id: 'water',
              type: 'fill',
              source: 'tiles',
              'source-layer': 'water',
              paint: {
                'fill-color': '#88ccee',
              },
            },
            {
              id: 'roads',
              type: 'line',
              source: 'tiles',
              'source-layer': 'roads',
              paint: {
                'line-color': '#666666',
                'line-width': 1,
              },
            },
            {
              id: 'cycleways',
              type: 'line',
              source: 'tiles',
              'source-layer': 'cycleways',
              paint: {
                'line-color': '#00aa00',
                'line-width': 2,
              },
            },
          ],
        },
        center: center as [number, number],
        zoom: zoom,
      });

      setMap(newMap);

      return () => {
        if (newMap) {
          newMap.remove();
        }
      };
    } catch (error) {
      console.error('Error initializing map:', error);
    }
  }, [setMap, center, zoom]);

  return <div ref={mapContainer} className="map-container" />;
}
