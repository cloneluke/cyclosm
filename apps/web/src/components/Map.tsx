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
        style: 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json',
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
