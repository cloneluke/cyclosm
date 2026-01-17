import { useEffect } from 'react';
import { useMapStore } from '../store/mapStore';
import { HAS_OVERTURE_SEGMENT_SOURCE } from '../layers.config';
import './LayerToggle.css';

export function LayerToggle() {
  const { 
    map, 
    layerVisibility, 
    setLayerVisibility, 
    getLayerVisibility 
  } = useMapStore();

  // Sync layer visibility with map when visibility state changes
  useEffect(() => {
    if (!map) return;

    const onStyleLoad = () => {
      Object.entries(layerVisibility).forEach(([layerId, isVisible]) => {
        try {
          if (map.getLayer(layerId)) {
            map.setLayoutProperty(
              layerId,
              'visibility',
              isVisible ? 'visible' : 'none'
            );
          }
        } catch (error) {
          console.error(`Error setting visibility for layer ${layerId}:`, error);
        }
      });
    };

    map.on('style.load', onStyleLoad);

    // Also try immediately in case style is already loaded
    setTimeout(() => {
      try {
        if (map.getLayer('cycleways')) {
          onStyleLoad();
        }
      } catch (error) {
        console.error('Error checking layers:', error);
      }
    }, 100);

    return () => {
      map.off('style.load', onStyleLoad);
    };
  }, [map, layerVisibility]);

  const handleCyclewaysToggle = () => {
    const newValue = !getLayerVisibility('cycleways');
    setLayerVisibility('cycleways', newValue);
    
    // If turning on cycleways, also turn on tracks
    if (newValue && !getLayerVisibility('tracks')) {
      setLayerVisibility('tracks', true);
    }
    
    if (!map) return;
    try {
      if (map.getLayer('cycleways')) {
        map.setLayoutProperty(
          'cycleways',
          'visibility',
          newValue ? 'visible' : 'none'
        );
      }
    } catch (error) {
      console.error('Error toggling cycleways:', error);
    }
  };

  const handlePOIToggle = () => {
    const newValue = !getLayerVisibility('poi-points');
    setLayerVisibility('poi-points', newValue);
    
    if (!map) return;
    try {
      if (map.getLayer('poi-points')) {
        map.setLayoutProperty(
          'poi-points',
          'visibility',
          newValue ? 'visible' : 'none'
        );
      }
    } catch (error) {
      console.error('Error toggling POI:', error);
    }
  };

  const handleTracksToggle = () => {
    const newValue = !getLayerVisibility('tracks');
    setLayerVisibility('tracks', newValue);
    
    if (!map) return;
    try {
      if (map.getLayer('tracks')) {
        map.setLayoutProperty(
          'tracks',
          'visibility',
          newValue ? 'visible' : 'none'
        );
      }
    } catch (error) {
      console.error('Error toggling tracks:', error);
    }
  };

  const handleShouldersToggle = () => {
    const newValue = !getLayerVisibility('bicycle-shoulders');
    setLayerVisibility('bicycle-shoulders', newValue);
    
    if (!map) return;
    try {
      if (map.getLayer('bicycle-shoulders')) {
        map.setLayoutProperty(
          'bicycle-shoulders',
          'visibility',
          newValue ? 'visible' : 'none'
        );
      }
    } catch (error) {
      console.error('Error toggling shoulders:', error);
    }
  };

  const handleOvertureToggle = () => {
    const newValue = !getLayerVisibility('overture-cycle');
    setLayerVisibility('overture-cycle', newValue);

    if (!map) return;
    try {
      if (map.getLayer('overture-cycle')) {
        map.setLayoutProperty(
          'overture-cycle',
          'visibility',
          newValue ? 'visible' : 'none'
        );
      }
    } catch (error) {
      console.error('Error toggling Overture layer:', error);
    }
  };

  const handleOvertureCyclewaysToggle = () => {
    const newValue = !getLayerVisibility('overture-cycleways');
    setLayerVisibility('overture-cycleways', newValue);

    if (!map) return;
    try {
      if (map.getLayer('overture-cycleways')) {
        map.setLayoutProperty(
          'overture-cycleways',
          'visibility',
          newValue ? 'visible' : 'none'
        );
      }
    } catch (error) {
      console.error('Error toggling Overture cycleways layer:', error);
    }
  };

  const handleBicycleNoToggle = () => {
    const newValue = !getLayerVisibility('bicycle-no');
    setLayerVisibility('bicycle-no', newValue);
    console.log(`🚫 Toggling bicycle-no layer to: ${newValue ? 'visible' : 'none'}`);
    if (!map) return;
    try {
      if (map.getLayer('bicycle-no')) {
        map.setLayoutProperty(
          'bicycle-no',
          'visibility',
          newValue ? 'visible' : 'none'
        );
        // Query features to verify data is in tiles
        const features = map.querySourceFeatures('local-tiles', {
          sourceLayer: 'transportation',
          filter: ['==', ['get', 'bicycle'], 'no']
        });
        console.log(`Found ${features.length} bicycle=no features in tiles`);
        if (features.length > 0) {
          console.log('Sample feature:', features[0].properties);
        }
      } else {
        console.warn('bicycle-no layer not found on map');
      }
    } catch (error) {
      console.error('Error toggling bicycle=no:', error);
    }
  };

  return (
    <div className="layer-toggle">
      <div className="layer-toggle-group">
        <label className="layer-toggle-label">
          <input
            type="checkbox"
            checked={getLayerVisibility('cycleways')}
            onChange={handleCyclewaysToggle}
            className="layer-toggle-checkbox"
          />
          <span className="layer-toggle-text">🚴 Cycleways</span>
        </label>
      </div>
      <div className="layer-toggle-group" style={{ marginLeft: '20px' }}>
        <label className="layer-toggle-label">
          <input
            type="checkbox"
            checked={getLayerVisibility('tracks')}
            onChange={handleTracksToggle}
            className="layer-toggle-checkbox"
          />
          <span className="layer-toggle-text">🛤️ Tracks</span>
        </label>
      </div>
      <div className="layer-toggle-group">
        <label className="layer-toggle-label">
          <input
            type="checkbox"
            checked={getLayerVisibility('bicycle-shoulders')}
            onChange={handleShouldersToggle}
            className="layer-toggle-checkbox"
          />
          <span className="layer-toggle-text">🛣️ Shoulders</span>
        </label>
      </div>
      <div className="layer-toggle-group">
        <label className="layer-toggle-label">
          <input
            type="checkbox"
            checked={getLayerVisibility('bicycle-no')}
            onChange={handleBicycleNoToggle}
            className="layer-toggle-checkbox"
          />
          <span className="layer-toggle-text">🚫 No Bicycles</span>
        </label>
      </div>
    </div>
  );
}
