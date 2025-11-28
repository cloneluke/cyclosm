import { useEffect, useRef } from 'react';
import maplibregl from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';
import { useMapStore } from '../store/mapStore';
import './Map.css';

export function Map() {
  const mapContainer = useRef<HTMLDivElement>(null);
  const { map, setMap, center, zoom } = useMapStore();

  useEffect(() => {
    if (!mapContainer.current) return;

    try {
      const newMap = new maplibregl.Map({
        container: mapContainer.current,
        style: 'https://demotiles.maplibre.org/style.json',
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
