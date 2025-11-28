import { useMapStore } from '../store/mapStore';
import './SourceSelector.css';

export function SourceSelector() {
  const { tileSource, setTileSource } = useMapStore();

  const handleSourceChange = (source: 'local' | 'public') => {
    setTileSource(source);
  };

  return (
    <div className="source-selector">
      <div className="source-label">Tile Source:</div>
      <div className="source-buttons">
        <button
          className={`source-button ${tileSource === 'local' ? 'active' : ''}`}
          onClick={() => handleSourceChange('local')}
          title="Local tile server (localhost:8080)"
        >
          Local
        </button>
        <button
          className={`source-button ${tileSource === 'public' ? 'active' : ''}`}
          onClick={() => handleSourceChange('public')}
          title="Public OpenStreetMap tiles (Carto)"
        >
          Public
        </button>
      </div>
    </div>
  );
}
