import { useEffect, useRef } from 'react';
import maplibregl from 'maplibre-gl';
import { Protocol } from 'pmtiles';
import 'maplibre-gl/dist/maplibre-gl.css';
import { useMapStore, TILE_SOURCES } from '../store/mapStore';
import './Map.css';

// Register PMTiles protocol
let protocolInitialized = false;

export function Map() {
  const mapContainer = useRef<HTMLDivElement>(null);
  const { setMap, center, zoom, tileSource } = useMapStore();

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
        style: TILE_SOURCES[tileSource].style,
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
  }, [setMap, center, zoom, tileSource]);

  return <div ref={mapContainer} className="map-container" />;
}
