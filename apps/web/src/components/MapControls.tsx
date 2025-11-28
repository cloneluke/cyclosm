import { useEffect, useState } from 'react';
import { useMapStore } from '../store/mapStore';
import './MapControls.css';

export function MapControls() {
  const { map, setCenter, setZoom } = useMapStore();
  const [geoActive, setGeoActive] = useState(false);
  const [geoSupported, setGeoSupported] = useState(false);

  useEffect(() => {
    setGeoSupported('geolocation' in navigator);
  }, []);

  const handleZoomIn = () => {
    if (map) {
      setZoom(map.getZoom() + 1);
      map.zoomTo(map.getZoom() + 1, { duration: 300 });
    }
  };

  const handleZoomOut = () => {
    if (map) {
      setZoom(map.getZoom() - 1);
      map.zoomTo(map.getZoom() - 1, { duration: 300 });
    }
  };

  const handleResetCenter = () => {
    if (map) {
      // Colorado center
      const defaultCenter: [number, number] = [-105.2705, 40.0150];
      setCenter(defaultCenter);
      map.flyTo({
        center: defaultCenter,
        zoom: 8,
        duration: 1500,
      });
    }
  };

  const handleGeolocation = () => {
    if (!geoSupported) {
      return;
    }

    setGeoActive(true);
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const { latitude, longitude } = position.coords;
        if (map) {
          setCenter([longitude, latitude]);
          map.flyTo({
            center: [longitude, latitude],
            zoom: 12,
            duration: 1500,
          });
        }
        setGeoActive(false);
      },
      (error) => {
        console.error('Geolocation error:', error);
        setGeoActive(false);
      }
    );
  };

  return (
    <div className="map-controls">
      <button
        className="control-button"
        onClick={handleZoomIn}
        title="Zoom in"
        aria-label="Zoom in"
      >
        +
      </button>
      <button
        className="control-button"
        onClick={handleZoomOut}
        title="Zoom out"
        aria-label="Zoom out"
      >
        −
      </button>
      <button
        className="control-button"
        onClick={handleResetCenter}
        title="Reset to default center"
        aria-label="Reset center"
      >
        ⊙
      </button>
      {geoSupported && (
        <button
          className={`control-button ${geoActive ? 'active' : ''}`}
          onClick={handleGeolocation}
          disabled={geoActive}
          title="Go to your location"
          aria-label="Go to your location"
        >
          📍
        </button>
      )}
    </div>
  );
}
