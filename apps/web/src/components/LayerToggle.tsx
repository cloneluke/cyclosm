import { useState, useEffect } from 'react';
import { useMapStore } from '../store/mapStore';
import './LayerToggle.css';

export function LayerToggle() {
  const { map } = useMapStore();
  const [showCycleways, setShowCycleways] = useState(true);
  const [showPOI, setShowPOI] = useState(true);

  useEffect(() => {
    if (!map) return;

    const onStyleLoad = () => {
      // Set initial visibility states
      try {
        if (map.getLayer('cycleways')) {
          map.setLayoutProperty(
            'cycleways',
            'visibility',
            showCycleways ? 'visible' : 'none'
          );
        }
        if (map.getLayer('poi-points')) {
          map.setLayoutProperty(
            'poi-points',
            'visibility',
            showPOI ? 'visible' : 'none'
          );
        }
        if (map.getLayer('poi-labels')) {
          map.setLayoutProperty(
            'poi-labels',
            'visibility',
            showPOI ? 'visible' : 'none'
          );
        }
      } catch (error) {
        console.error('Error setting layer visibility:', error);
      }
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
  }, [map, showCycleways, showPOI]);

  const handleCyclewaysToggle = () => {
    if (!map) return;
    const newValue = !showCycleways;
    setShowCycleways(newValue);
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
    if (!map) return;
    const newValue = !showPOI;
    setShowPOI(newValue);
    try {
      if (map.getLayer('poi-points')) {
        map.setLayoutProperty(
          'poi-points',
          'visibility',
          newValue ? 'visible' : 'none'
        );
      }
      if (map.getLayer('poi-labels')) {
        map.setLayoutProperty(
          'poi-labels',
          'visibility',
          newValue ? 'visible' : 'none'
        );
      }
    } catch (error) {
      console.error('Error toggling POI:', error);
    }
  };

  return (
    <div className="layer-toggle">
      <div className="layer-toggle-group">
        <label className="layer-toggle-label">
          <input
            type="checkbox"
            checked={showCycleways}
            onChange={handleCyclewaysToggle}
            className="layer-toggle-checkbox"
          />
          <span className="layer-toggle-text">🚴 Cycleways</span>
        </label>
      </div>
      <div className="layer-toggle-group">
        <label className="layer-toggle-label">
          <input
            type="checkbox"
            checked={showPOI}
            onChange={handlePOIToggle}
            className="layer-toggle-checkbox"
          />
          <span className="layer-toggle-text">🏪 Amenities</span>
        </label>
      </div>
    </div>
  );
}
