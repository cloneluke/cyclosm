/**
 * Layer configuration for cycling map
 * Centralized definition to avoid repetition and improve maintainability
 */

const OVERTURE_SEGMENT_PM_TILES = import.meta.env.VITE_OVERTURE_SEGMENT_PM_TILES ?? '';
const OVERTURE_SEGMENT_LAYER = import.meta.env.VITE_OVERTURE_SEGMENT_LAYER ?? 'transportation_segment';

export const HAS_OVERTURE_SEGMENT_SOURCE = Boolean(OVERTURE_SEGMENT_PM_TILES);
export const OVERTURE_SEGMENT_SOURCE_ID = 'overture-segments';
export const OVERTURE_SEGMENT_PM_TILES_URL = OVERTURE_SEGMENT_PM_TILES;
export const OVERTURE_SEGMENT_LAYER_NAME = OVERTURE_SEGMENT_LAYER;

export const CYCLING_TAGS = [
  'highway',
  'bicycle',
  'cycleway',
  'shoulder',
  'surface',
  'name',
  'access',
  'foot',
  'amenity',
  'shop',
  'leisure',
] as const;

const baseLayerConfig: Record<string, any> = {
  'roads-base': {
    id: 'roads-base',
    type: 'line',
    source: 'local-tiles',
    'source-layer': 'transportation',
    filter: ['!=', ['get', 'brunnel'], 'tunnel'],
    paint: {
      'line-color': [
        'match',
        ['get', 'class'],
        'motorway',
        '#e892a2',
        'trunk',
        '#f9b29c',
        'primary',
        '#fcd6a4',
        'secondary',
        '#f7fabf',
        'tertiary',
        '#ffffff',
        'minor',
        '#ffffff',
        'service',
        '#ffffff',
        '#cccccc',
      ],
      'line-width': [
        'interpolate',
        ['exponential', 1.5],
        ['zoom'],
        5,
        [
          'match',
          ['get', 'class'],
          'motorway',
          0.5,
          'trunk',
          0.4,
          0,
        ],
        12,
        [
          'match',
          ['get', 'class'],
          'motorway',
          3,
          'trunk',
          2.5,
          'primary',
          2,
          'secondary',
          1.5,
          'tertiary',
          1,
          0.5,
        ],
        16,
        [
          'match',
          ['get', 'class'],
          'motorway',
          8,
          'trunk',
          7,
          'primary',
          6,
          'secondary',
          5,
          'tertiary',
          4,
          'minor',
          3,
          2,
        ],
      ],
    },
  } as any,

  cycleways: {
    id: 'cycleways',
    type: 'line',
    source: 'local-tiles',
    'source-layer': 'transportation',
    filter: [
      'all',
      [
        'in',
        ['get', 'highway'],
        ['literal', ['path', 'cycleway', 'footway', 'steps', 'pedestrian']],
      ],
      ['!=', ['get', 'bicycle'], 'no'],
    ],
    minzoom: 5,
    paint: {
      'line-color': '#2fb344',
      'line-width': [
        'interpolate',
        ['exponential', 1.5],
        ['zoom'],
        5,
        2,
        8,
        2.5,
        10,
        3.5,
        13,
        5,
        16,
        7,
        18,
        10,
      ],
      'line-opacity': 0.9,
    },
  } as any,

  tracks: {
    id: 'tracks',
    type: 'line',
    source: 'local-tiles',
    'source-layer': 'transportation',
    filter: ['==', ['get', 'highway'], 'track'],
    minzoom: 5,
    paint: {
      'line-color': '#8B6F47',
      'line-width': [
        'interpolate',
        ['exponential', 1.5],
        ['zoom'],
        5,
        2,
        8,
        2.5,
        10,
        3.5,
        13,
        5,
        16,
        7,
        18,
        10,
      ],
      'line-opacity': 0.9,
    },
  } as any,

  'bicycle-shoulders': {
    id: 'bicycle-shoulders',
    type: 'line',
    source: 'local-tiles',
    'source-layer': 'transportation',
    filter: [
      'in',
      ['get', 'shoulder'],
      ['literal', ['wide', 'yes', 'left', 'right', 'both', 'paved']],
    ],
    minzoom: 5,
    paint: {
      'line-color': '#FFD700',
      'line-width': [
        'interpolate',
        ['exponential', 1.5],
        ['zoom'],
        5,
        1,
        8,
        1.5,
        10,
        2,
        13,
        3.5,
        16,
        5,
        18,
        7,
      ],
      'line-opacity': 0.85,
    },
  } as any,

  'poi-points': {
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
      'circle-stroke-color': '#ffffff',
    },
  } as any,

  'trails': {
    id: 'trails',
    type: 'line',
    source: 'local-tiles',
    'source-layer': 'transportation',
    filter: [
      'all',
      [
        'in',
        ['get', 'highway'],
        ['literal', ['path', 'footway', 'steps', 'pedestrian']],
      ],
      ['!=', ['get', 'bicycle'], 'no'],
    ],
    minzoom: 10,
    paint: {
      'line-color': [
        'match',
        ['get', 'highway'],
        'path',
        '#8B4513',
        'footway',
        '#D2691E',
        'steps',
        '#CD853F',
        '#8B4513',
      ],
      'line-width': [
        'interpolate',
        ['linear'],
        ['zoom'],
        10,
        0.5,
        12,
        1.5,
        16,
        3,
      ],
      'line-opacity': 0.85,
      'line-dasharray': [2, 2],
    },
  } as any,

  'place-labels-small': {
    id: 'place-labels-small',
    type: 'symbol',
    source: 'local-tiles',
    'source-layer': 'place',
    minzoom: 10,
    filter: [
      'in',
      ['get', 'place'],
      ['literal', ['village', 'hamlet', 'suburb', 'neighbourhood']],
    ],
    layout: {
      'text-field': ['get', 'name'],
      'text-size': [
        'interpolate',
        ['linear'],
        ['zoom'],
        10,
        11,
        14,
        14,
      ],
      'text-anchor': 'center',
    },
    paint: {
      'text-color': '#444444',
      'text-halo-color': '#ffffff',
      'text-halo-width': 2,
    },
  } as any,

  'place-labels-large': {
    id: 'place-labels-large',
    type: 'symbol',
    source: 'local-tiles',
    'source-layer': 'place',
    minzoom: 4,
    filter: [
      'in',
      ['get', 'place'],
      ['literal', ['city', 'town']],
    ],
    layout: {
      'text-field': ['get', 'name'],
      'text-size': [
        'interpolate',
        ['linear'],
        ['zoom'],
        4,
        12,
        8,
        16,
        12,
        20,
      ],
      'text-anchor': 'center',
    },
    paint: {
      'text-color': '#1a1a1a',
      'text-halo-color': '#ffffff',
      'text-halo-width': 3,
    },
  } as any,
};

if (HAS_OVERTURE_SEGMENT_SOURCE) {
  baseLayerConfig['overture-cycle'] = {
    id: 'overture-cycle',
    type: 'line',
    source: OVERTURE_SEGMENT_SOURCE_ID,
    'source-layer': OVERTURE_SEGMENT_LAYER,
    minzoom: 0,
    // Visible at all zoom levels
    paint: {
      'line-color': '#FF1744',
      'line-width': [
        'interpolate',
        ['linear'],
        ['zoom'],
        0,
        1,
        6,
        2,
        12,
        3,
        16,
        5,
      ],
      'line-opacity': 0.9,
    },
  } as any;

  baseLayerConfig['overture-cycleways'] = {
    id: 'overture-cycleways',
    type: 'line',
    source: OVERTURE_SEGMENT_SOURCE_ID,
    'source-layer': OVERTURE_SEGMENT_LAYER,
    minzoom: 0,
    filter: [
      'any',
      ['==', ['get', 'class'], 'cycleway'],
      ['==', ['get', 'class'], 'path'],
    ],
    // Visible at all zoom levels
    paint: {
      'line-color': '#9C27B0',
      'line-width': [
        'interpolate',
        ['linear'],
        ['zoom'],
        0,
        1.2,
        6,
        2.5,
        12,
        4,
        16,
        6,
      ],
      'line-opacity': 0.95,
    },
  } as any;
}

// Add bicycle-no layer last so it draws on top
baseLayerConfig['bicycle-no'] = {
  id: 'bicycle-no',
  type: 'line',
  source: 'local-tiles',
  'source-layer': 'transportation',
  filter: ['==', ['get', 'bicycle'], 'no'],
  minzoom: 5,
  paint: {
    'line-color': '#ff0000',
    'line-width': [
      'interpolate',
      ['linear'],
      ['zoom'],
      5,
      2,
      8,
      2.5,
      10,
      3.5,
      13,
      5,
      16,
      7,
      18,
      10,
    ],
    'line-opacity': 0.9,
  },
  layout: {
    'line-join': 'round',
    'line-cap': 'round',
  },
} as any;

export const LAYER_CONFIG = baseLayerConfig;

/**
 * Layer IDs in order (used for event listeners, visibility toggling, cleanup)
 */
export const LAYER_IDS = Object.keys(LAYER_CONFIG) as Array<keyof typeof LAYER_CONFIG>;

/**
 * Get layer IDs that should have hover tooltips
 */
const baseTooltipLayers = ['cycleways', 'tracks', 'bicycle-shoulders', 'bicycle-no', 'poi-points', 'roads-base'];

if (HAS_OVERTURE_SEGMENT_SOURCE) {
  baseTooltipLayers.push('overture-cycle');
}

export const TOOLTIP_LAYERS = baseTooltipLayers;
