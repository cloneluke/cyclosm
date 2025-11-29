import { create } from 'zustand';
import type { Map } from 'maplibre-gl';

export const TILE_SOURCES = {
  local: {
    url: 'pmtiles://http://localhost:8080/data/tiles.pmtiles',
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
  isLoading: boolean;
  error: string | null;
  setCenter: (center: [number, number]) => void;
  setZoom: (zoom: number) => void;
  setTileSource: (source: 'local' | 'public') => void;
  setLoading: (loading: boolean) => void;
  setError: (error: string | null) => void;
  clearError: () => void;
}

export const useMapStore = create<MapState>((set) => ({
  map: null,
  setMap: (map) => set({ map }),
  center: [-93.2, 44.9], // Minneapolis, MN - center of 5-state region
  zoom: 10, // Lower zoom to ensure we're not at maxzoom
  tileSource: 'local', // Use local tiles for debugging
  isLoading: false,
  error: null,
  setCenter: (center) => set({ center }),
  setZoom: (zoom) => set({ zoom }),
  setTileSource: (source) => set({ tileSource: source }),
  setLoading: (loading) => set({ isLoading: loading }),
  setError: (error) => set({ error }),
  clearError: () => set({ error: null }),
}));
