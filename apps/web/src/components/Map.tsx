import { useEffect, useRef } from 'react';
import maplibregl from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';
import { useMapStore } from '../store/mapStore';
import './Map.css';

export function Map() {
  const mapContainer = useRef<HTMLDivElement>(null);
  const { map, setMap, center, zoom, tileSource } = useMapStore();

  useEffect(() => {
    if (!mapContainer.current) return;

    const tileUrl = tileSource === 'local' 
      ? 'http://localhost:8080/tiles/{z}/{x}/{y}.pbf'
      : 'https://tile.openstreetmap.org/data/v3/{z}/{x}/{y}.pbf';

    const newMap = new maplibregl.Map({
      container: mapContainer.current,
      style: {
        version: 8,
        sources: {
          osm: {
            type: 'vector',
            url: tileUrl,
          },
        },
        layers: [
          {
            id: 'water',
            type: 'fill',
            source: 'osm',
            'source-layer': 'water',
            paint: {
              'fill-color': '#88ccee',
            },
          },
          {
            id: 'roads',
            type: 'line',
            source: 'osm',
            'source-layer': 'roads',
            paint: {
              'line-color': '#cccccc',
              'line-width': 1,
            },
          },
          {
            id: 'parks',
            type: 'fill',
            source: 'osm',
            'source-layer': 'parks',
            paint: {
              'fill-color': '#99dd99',
            },
          },
        ],
      },
      center: center,
      zoom: zoom,
    });

    setMap(newMap);

    return () => {
      if (newMap) {
        newMap.remove();
      }
    };
  }, [setMap, tileSource]);

  return <div ref={mapContainer} className="map-container" />;
}
