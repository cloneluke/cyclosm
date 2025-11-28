import { create } from 'zustand';
import type { Map } from 'maplibre-gl';

export const TILE_SOURCES = {
  local: {
    url: 'http://localhost:8080/tiles/{z}/{x}/{y}.pbf',
    name: 'Local Tile Server',
    style: 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json',
  },
  public: {
    url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.pbf',
    name: 'Public OSM Tiles',
    style: 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json',
  },
} as const;

interface MapState {
  map: Map | null;
  setMap: (map: Map | null) => void;
  center: [number, number];
  zoom: number;
  tileSource: 'local' | 'public';
  setCenter: (center: [number, number]) => void;
  setZoom: (zoom: number) => void;
  setTileSource: (source: 'local' | 'public') => void;
}

export const useMapStore = create<MapState>((set) => ({
  map: null,
  setMap: (map) => set({ map }),
  center: [-105.2705, 40.0150], // Colorado center
  zoom: 8,
  tileSource: 'public',
  setCenter: (center) => set({ center }),
  setZoom: (zoom) => set({ zoom }),
  setTileSource: (source) => set({ tileSource: source }),
}));
