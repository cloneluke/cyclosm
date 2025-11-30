import { create } from 'zustand';
import type { Map } from 'maplibre-gl';

export const TILE_SOURCES = {
  local: {
    url: 'pmtiles://http://localhost:8080/tiles.pmtiles',
    name: 'Local Tile Server',
    style: 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json',
  },
  public: {
    url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.pbf',
    name: 'Public OSM Tiles',
    style: 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json',
  },
} as const;

// Default layer visibility state
const DEFAULT_LAYER_VISIBILITY = {
  cycleways: true,
  tracks: true,
  'bicycle-shoulders': false,
  'poi-points': true,
};

// Load layer visibility from localStorage or use defaults
const loadLayerVisibility = () => {
  try {
    const stored = localStorage.getItem('cyclosm-layer-visibility');
    return stored ? JSON.parse(stored) : DEFAULT_LAYER_VISIBILITY;
  } catch {
    return DEFAULT_LAYER_VISIBILITY;
  }
};

interface MapState {
  map: Map | null;
  setMap: (map: Map | null) => void;
  center: [number, number];
  zoom: number;
  tileSource: 'local' | 'public';
  isLoading: boolean;
  error: string | null;
  layerVisibility: Record<string, boolean>;
  setCenter: (center: [number, number]) => void;
  setZoom: (zoom: number) => void;
  setTileSource: (source: 'local' | 'public') => void;
  setLoading: (loading: boolean) => void;
  setError: (error: string | null) => void;
  clearError: () => void;
  setLayerVisibility: (layer: string, visible: boolean) => void;
  getLayerVisibility: (layer: string) => boolean;
}

export const useMapStore = create<MapState>((set, get) => ({
  map: null,
  setMap: (map) => set({ map }),
  center: [-93.2, 44.9], // Minneapolis, MN - center of 5-state region
  zoom: 10, // Lower zoom to ensure we're not at maxzoom
  tileSource: 'local', // Use local tiles for debugging
  isLoading: false,
  error: null,
  layerVisibility: loadLayerVisibility(),
  setCenter: (center) => set({ center }),
  setZoom: (zoom) => set({ zoom }),
  setTileSource: (source) => set({ tileSource: source }),
  setLoading: (loading) => set({ isLoading: loading }),
  setError: (error) => set({ error }),
  clearError: () => set({ error: null }),
  setLayerVisibility: (layer, visible) =>
    set((state) => {
      const updated = { ...state.layerVisibility, [layer]: visible };
      // Persist to localStorage
      try {
        localStorage.setItem('cyclosm-layer-visibility', JSON.stringify(updated));
      } catch (e) {
        console.warn('Failed to save layer visibility to localStorage:', e);
      }
      return { layerVisibility: updated };
    }),
  getLayerVisibility: (layer) => get().layerVisibility[layer] ?? true,
}));
