import { useEffect, useState, useMemo, useRef } from 'react'
import toast from 'react-hot-toast'
import {
  MapContainer, TileLayer, Circle, CircleMarker, Popup, Tooltip,
  useMap, ZoomControl,
} from 'react-leaflet'
import { fetchRiskZones, fetchHeatmapData, fetchMLHotspots } from '../api'
import { Topbar } from './Dashboard'
import { format } from 'date-fns'
import 'leaflet/dist/leaflet.css'

// ── Zone config — identical to Flutter app ZoneModel ──────────────────────
const ZONE_CONFIG = {
  safe:     { color: '#43A047', label: 'Safe Zone',      emoji: '🟢' },
  moderate: { color: '#F39C12', label: 'Moderate Zone',  emoji: '🟡' },
  high:     { color: '#E74C3C', label: 'High Risk Zone', emoji: '🔴' },
  critical: { color: '#8B0000', label: 'Critical Zone',  emoji: '🟥' },
}

const SOS_COLORS = {
  active:      '#ef4444',
  resolved:    '#10b981',
  false_alarm: '#f59e0b',
}

// Auto-fit map to all zones
function FitBounds({ zones }) {
  const map = useMap()
  const fitted = useRef(false)

  useEffect(() => {
    if (zones.length === 0 || fitted.current) return
    const bounds = zones.map(z => [z.lat, z.lon])
    map.fitBounds(bounds, { padding: [40, 40] })
    fitted.current = true
  }, [zones, map])

  return null
}

export default function HeatmapPage() {
  const [riskData, setRiskData]   = useState({ zones: [], currentHour: 0, multiplier: 0 })
  const [sosPoints, setSosPoints] = useState([])
  const [loading, setLoading]     = useState(true)
  const [layer, setLayer]         = useState('zones')
  const [filterType, setFilter]   = useState('all')
  const [liveLocation, setLiveLoc]= useState(null)

  const loadData = (showLoading = false) => {
    if (showLoading) setLoading(true)
    Promise.all([
      fetchRiskZones().catch(() => null), 
      fetchHeatmapData().catch(() => []),
      fetchMLHotspots().catch(() => [])
    ])
      .then(([rd, sos, mlHotspots]) => {
        // Fallback default zones if live backend array is empty or deploying
        const defaultZones = [
          {"name": "Shyamla Hills", "lat": 23.245, "lon": 77.418, "baseScore": 16.0, "riskScore": 16, "zoneType": "safe", "zoneColor": "#43A047"},
          {"name": "TT Nagar", "lat": 23.235, "lon": 77.412, "baseScore": 18.0, "riskScore": 18, "zoneType": "safe", "zoneColor": "#43A047"},
          {"name": "MP Nagar", "lat": 23.2332, "lon": 77.4272, "baseScore": 22.0, "riskScore": 22, "zoneType": "safe", "zoneColor": "#43A047"},
          {"name": "Gandhi Nagar", "lat": 23.248, "lon": 77.408, "baseScore": 24.0, "riskScore": 24, "zoneType": "safe", "zoneColor": "#43A047"},
          {"name": "Kamla Nagar", "lat": 23.218, "lon": 77.438, "baseScore": 29.0, "riskScore": 29, "zoneType": "moderate", "zoneColor": "#F39C12"},
          {"name": "Habibganj", "lat": 23.2289, "lon": 77.4382, "baseScore": 31.0, "riskScore": 31, "zoneType": "moderate", "zoneColor": "#F39C12"},
          {"name": "Ashoka Garden", "lat": 23.238, "lon": 77.478, "baseScore": 37.0, "riskScore": 37, "zoneType": "moderate", "zoneColor": "#F39C12"},
          {"name": "Ayodhya Nagar", "lat": 23.225, "lon": 77.482, "baseScore": 40.0, "riskScore": 40, "zoneType": "moderate", "zoneColor": "#F39C12"},
          {"name": "Kotwali", "lat": 23.258, "lon": 77.4025, "baseScore": 42.0, "riskScore": 42, "zoneType": "moderate", "zoneColor": "#F39C12"},
          {"name": "Aishbag", "lat": 23.25, "lon": 77.4, "baseScore": 44.0, "riskScore": 44, "zoneType": "moderate", "zoneColor": "#F39C12"},
          {"name": "Piplani", "lat": 23.2458, "lon": 77.4672, "baseScore": 55.0, "riskScore": 55, "zoneType": "high", "zoneColor": "#E74C3C"},
          {"name": "Govindpura", "lat": 23.262, "lon": 77.472, "baseScore": 61.0, "riskScore": 61, "zoneType": "high", "zoneColor": "#E74C3C"},
          {"name": "Misrod", "lat": 23.198, "lon": 77.487, "baseScore": 66.0, "riskScore": 66, "zoneType": "high", "zoneColor": "#E74C3C"},
          {"name": "Kolar Road", "lat": 23.178, "lon": 77.458, "baseScore": 74.0, "riskScore": 74, "zoneType": "high", "zoneColor": "#E74C3C"},
          {"name": "Ratibad", "lat": 23.1452, "lon": 77.358, "baseScore": 83.0, "riskScore": 83, "zoneType": "critical", "zoneColor": "#8B0000"},
          {"name": "Berasia", "lat": 23.628, "lon": 77.435, "baseScore": 88.0, "riskScore": 88, "zoneType": "critical", "zoneColor": "#8B0000"},
          {"name": "MG Road Indore", "lat": 22.7196, "lon": 75.8577, "baseScore": 18.0, "riskScore": 18, "zoneType": "safe", "zoneColor": "#43A047"},
          {"name": "Vijay Nagar", "lat": 22.746, "lon": 75.8873, "baseScore": 22.0, "riskScore": 22, "zoneType": "safe", "zoneColor": "#43A047"},
          {"name": "Palasia", "lat": 22.7278, "lon": 75.8716, "baseScore": 25.0, "riskScore": 25, "zoneType": "safe", "zoneColor": "#43A047"},
          {"name": "Banganga", "lat": 22.72, "lon": 75.835, "baseScore": 37.0, "riskScore": 37, "zoneType": "moderate", "zoneColor": "#F39C12"},
          {"name": "Lasudia", "lat": 22.738, "lon": 75.902, "baseScore": 55.0, "riskScore": 55, "zoneType": "high", "zoneColor": "#E74C3C"},
          {"name": "Devguradia", "lat": 22.802, "lon": 75.92, "baseScore": 77.0, "riskScore": 77, "zoneType": "critical", "zoneColor": "#8B0000"}
        ].map((z, idx) => ({ ...z, id: `fb_${idx}`, radius: 0.5 }))

        let fetchedZones = Array.isArray(rd?.zones) ? rd.zones : (Array.isArray(rd) ? rd : [])
        if (fetchedZones.length === 0) {
          fetchedZones = defaultZones
        }

        const safeMLArr = Array.isArray(mlHotspots) ? mlHotspots : (Array.isArray(mlHotspots?.hotspots) ? mlHotspots.hotspots : (Array.isArray(mlHotspots?.data) ? mlHotspots.data : []))
        const mlZones = safeMLArr.map((z, idx) => {
          const riskScore = z.risk_score || 56;
          let zoneType, zoneColor, zoneLabel;
          if (riskScore <= 25) { zoneType = 'safe'; zoneColor = '#43A047'; zoneLabel = 'Safe Zone'; }
          else if (riskScore <= 50) { zoneType = 'moderate'; zoneColor = '#F39C12'; zoneLabel = 'Moderate Zone'; }
          else if (riskScore <= 75) { zoneType = 'high'; zoneColor = '#E74C3C'; zoneLabel = 'High Risk Zone'; }
          else { zoneType = 'critical'; zoneColor = '#8B0000'; zoneLabel = 'Critical Zone'; }
          return {
            id: `ml_${z.id || z.name || idx}`,
            name: z.name || 'ML Hotspot',
            lat: Number(z.lat) || 23.25,
            lon: Number(z.lon) || 77.41,
            radius: Number(z.radius) || 0.8,
            baseScore: riskScore, riskScore, zoneType, zoneColor, zoneLabel
          };
        });

        const finalData = {
          zones: [...fetchedZones, ...mlZones],
          currentHour: rd?.currentHour || new Date().getHours(),
          multiplier: rd?.multiplier || 0
        }

        setRiskData(finalData); 
        setSosPoints(Array.isArray(sos) ? sos : []); 
      })
      .catch((err) => {
        console.error(err)
        toast.error('Showing offline cached zones')
      })
      .finally(() => { if (showLoading) setLoading(false) })
  }

  useEffect(() => {
    loadData(true)

    // Fetch user's live location
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (pos) => setLiveLoc([pos.coords.latitude, pos.coords.longitude]),
        (err) => console.warn("Could not get live location", err),
        { enableHighAccuracy: true }
      )
    }

    const handleUpdate = () => loadData(false)
    window.addEventListener('realtime_update', handleUpdate)
    
    const intervalId = setInterval(() => loadData(false), 5 * 60 * 1000)

    return () => {
      window.removeEventListener('realtime_update', handleUpdate)
      clearInterval(intervalId)
    }
  }, [])

  const { zones } = riskData

  const filteredZones = useMemo(() =>
    filterType === 'all' ? zones : zones.filter(z => z.zoneType === filterType),
    [zones, filterType]
  )

  const zoneCounts = useMemo(() => ({
    safe:     zones.filter(z => z.zoneType === 'safe').length,
    moderate: zones.filter(z => z.zoneType === 'moderate').length,
    high:     zones.filter(z => z.zoneType === 'high').length,
    critical: zones.filter(z => z.zoneType === 'critical').length,
  }), [zones])

  const mapCenter = [23.2332, 77.4272] // Bhopal default

  return (
    <>
      <Topbar title="Safety Zone Map" sub="Live risk zones and incident tracking" />
      <div className="page-content">

        {/* ── Zone Type Stats ──────────────────────────────────────────── */}
        <div className="stats-grid" style={{ gridTemplateColumns: 'repeat(4,1fr)', marginBottom: 20 }}>
          {Object.entries(ZONE_CONFIG).map(([type, cfg]) => (
            <div
              key={type}
              className="stat-card"
              style={{
                cursor: 'pointer',
                border: filterType === type ? `1px solid ${cfg.color}` : undefined,
                boxShadow: filterType === type ? `0 0 14px ${cfg.color}35` : undefined,
              }}
              onClick={() => setFilter(f => f === type ? 'all' : type)}
            >
              <div className="stat-icon" style={{ background: `${cfg.color}22`, fontSize: 22 }}>{cfg.emoji}</div>
              <div className="stat-body">
                <p className="stat-label">{cfg.label}</p>
                <p className="stat-value" style={{ color: cfg.color }}>{zoneCounts[type]}</p>
                <p className="stat-sub">{filterType === type ? '← filtering' : 'zones'}</p>
              </div>
            </div>
          ))}
        </div>

        <div className="grid-60-40">

          {/* ── Map Card ─────────────────────────────────────────────── */}
          <div className="card" style={{ padding: 0, overflow: 'hidden' }}>

            {/* Toolbar */}
            <div style={{
              padding: '14px 20px', borderBottom: '1px solid var(--border)',
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
              flexWrap: 'wrap', gap: 10,
            }}>
              <div>
                <p className="card-title">🗺️ Live Safety Zone Map</p>
                <p className="card-subtitle">
                  {filteredZones.length} zones &nbsp;·&nbsp;
                  Hour: {riskData.currentHour}:00 &nbsp;·&nbsp;
                  Multiplier: {riskData.multiplier >= 0 ? '+' : ''}{riskData.multiplier}
                  {riskData.multiplier > 5 && <span style={{ color: '#ef4444' }}> ⬆ High-risk hours</span>}
                </p>
              </div>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                {[
                  { key: 'zones', label: '⭕ Zones' },
                  { key: 'sos',   label: '🔴 SOS' },
                  { key: 'both',  label: '📍 Both' },
                ].map(l => (
                  <button
                    key={l.key}
                    className={`btn btn-sm ${layer === l.key ? 'btn-primary' : 'btn-ghost'}`}
                    onClick={() => setLayer(l.key)}
                  >
                    {l.label}
                  </button>
                ))}
                {filterType !== 'all' && (
                  <button className="btn btn-sm btn-ghost" onClick={() => setFilter('all')}>✕ Clear</button>
                )}
              </div>
            </div>

            {/* Map */}
            {loading ? (
              <div className="loading-spinner" style={{ height: 520 }}>
                <div className="spinner" />
                <p style={{ color: 'var(--text-muted)', fontSize: 13 }}>Loading zones…</p>
              </div>
            ) : (
              <div style={{ height: 520 }}>
                <MapContainer
                  center={mapCenter}
                  zoom={11}
                  style={{ height: '100%', width: '100%' }}
                  zoomControl={false}
                >
                  {/* Standard Google Maps Tiles */}
                  <TileLayer
                    url="https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}"
                    attribution='&copy; Google Maps'
                    maxZoom={19}
                  />
                  <ZoomControl position="bottomright" />
                  <FitBounds zones={filteredZones} />

                  {/* ── Admin's Live Location (Blue Dot) ────────────────── */}
                  {liveLocation && (
                    <CircleMarker
                      center={liveLocation}
                      radius={8}
                      pathOptions={{
                        fillColor: '#3b82f6',
                        fillOpacity: 1,
                        color: '#ffffff',
                        weight: 2.5,
                      }}
                    >
                      <Popup closeButton={false}>
                        <div style={{ fontFamily: 'Inter', fontSize: 13, fontWeight: 700, color: '#1e293b' }}>
                          🔵 Your Live Location
                        </div>
                      </Popup>
                    </CircleMarker>
                  )}

                  {/* ── Risk Zone Circles — exact replica of Flutter app ── */}
                  {(layer === 'zones' || layer === 'both') && filteredZones.map(zone => (
                    <Circle
                      key={zone.id}
                      center={[zone.lat, zone.lon]}
                      radius={zone.radius * 1000}       // 1km → metres, same as Flutter
                      pathOptions={{
                        fillColor:    zone.zoneColor,
                        fillOpacity:  0.30,              // Flutter: color.withOpacity(0.3)
                        color:        zone.zoneColor,    // Flutter: strokeColor
                        weight:       2,                 // Flutter: strokeWidth: 2
                        opacity:      0.85,
                      }}
                    >
                      {/* Tooltip — shows on hover for high/critical zones */}
                      {(zone.zoneType === 'high' || zone.zoneType === 'critical') && (
                        <Tooltip
                          permanent
                          direction="center"
                          className="zone-label-tooltip"
                        >
                          <span style={{
                            fontFamily: 'Inter, sans-serif',
                            fontSize: 10,
                            fontWeight: 700,
                            color: zone.zoneColor,
                            whiteSpace: 'nowrap',
                          }}>
                            {ZONE_CONFIG[zone.zoneType].emoji} {zone.name}
                          </span>
                        </Tooltip>
                      )}

                      <Popup closeButton={false} className="zone-popup">
                        <ZonePopupContent zone={zone} />
                      </Popup>
                    </Circle>
                  ))}

                  {/* ── SOS Incident Points ──────────────────────────────── */}
                  {(layer === 'sos' || layer === 'both') && sosPoints.map((p, i) => (
                    <Circle
                      key={`sos_${i}`}
                      center={[p.lat, p.lon]}
                      radius={250}
                      pathOptions={{
                        fillColor:   SOS_COLORS[p.status] || '#8b5cf6',
                        fillOpacity: 0.9,
                        color:       SOS_COLORS[p.status] || '#8b5cf6',
                        weight:      1.5,
                      }}
                    >
                      <Popup closeButton={false}>
                        <SOSPopupContent point={p} />
                      </Popup>
                    </Circle>
                  ))}
                </MapContainer>
              </div>
            )}

            {/* Legend */}
            <div style={{
              padding: '10px 20px', borderTop: '1px solid var(--border)',
              display: 'flex', gap: 18, flexWrap: 'wrap', alignItems: 'center',
              fontSize: 12, color: 'var(--text-secondary)',
            }}>
              <span style={{ fontWeight: 700, color: 'var(--text-primary)' }}>Legend:</span>
              {Object.entries(ZONE_CONFIG).map(([t, c]) => (
                <LegendDot key={t} color={c.color} label={c.label} />
              ))}
              {(layer === 'sos' || layer === 'both') && Object.entries(SOS_COLORS).map(([k, c]) => (
                <LegendDot key={k} color={c} label={k.replace('_', ' ')} filled />
              ))}
            </div>
          </div>

          {/* ── Zone Directory List ──────────────────────────────────── */}
          <div className="card" style={{ maxHeight: 660, display: 'flex', flexDirection: 'column' }}>
            <div className="card-header">
              <div>
                <p className="card-title">Zone Directory</p>
                <p className="card-subtitle">{filteredZones.length} zones · sorted by risk</p>
              </div>
            </div>
            <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 6 }}>
              {filteredZones.length === 0 ? (
                <div className="empty-state"><p className="empty-icon">🗺️</p><p>No zones match filter</p></div>
              ) : (
                filteredZones
                  .slice()
                  .sort((a, b) => b.riskScore - a.riskScore)
                  .map(zone => <ZoneListItem key={zone.id} zone={zone} />)
              )}
            </div>
          </div>

        </div>
      </div>

      {/* Inline styles for Leaflet popup */}
      <style>{`
        .leaflet-popup-content-wrapper {
          background: #ffffff !important;
          border: 1px solid rgba(0,0,0,0.05) !important;
          border-radius: 8px !important;
          box-shadow: 0 4px 15px rgba(0,0,0,0.1) !important;
          color: #111827 !important;
        }
        .leaflet-popup-tip { background: #ffffff !important; }
        .leaflet-popup-content { margin: 12px 16px !important; }
        .leaflet-tooltip {
          background: rgba(255,255,255,0.95) !important;
          border: 1px solid rgba(0,0,0,0.05) !important;
          box-shadow: 0 4px 6px rgba(0,0,0,0.05) !important;
          padding: 4px 8px !important;
          border-radius: 6px !important;
          color: #111827 !important;
          font-weight: 600 !important;
        }
        .leaflet-control-zoom a {
          background: #ffffff !important;
          color: #111827 !important;
          border-color: rgba(0,0,0,0.1) !important;
        }
        .leaflet-control-zoom a:hover { background: #f9fafb !important; }
        .leaflet-control-attribution { background: rgba(255,255,255,0.9) !important; color: #6b7280 !important; }
        .leaflet-control-attribution a { color: #3b82f6 !important; }
      `}</style>
    </>
  )
}

// ── Sub-components ──────────────────────────────────────────────────────────

function LegendDot({ color, label, filled }) {
  return (
    <span style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
      <span style={{
        width: 14, height: 14, borderRadius: '50%', display: 'inline-block', flexShrink: 0,
        background: filled ? color : `${color}4d`,
        border: `2px solid ${color}`,
      }} />
      {label}
    </span>
  )
}

function ZonePopupContent({ zone }) {
  const cfg = ZONE_CONFIG[zone.zoneType] || ZONE_CONFIG.safe
  return (
    <div style={{ fontFamily: 'Inter, sans-serif', minWidth: 200 }}>
      <p style={{ fontWeight: 700, fontSize: 14, marginBottom: 8, color: zone.zoneColor }}>
        {cfg.emoji} {zone.name}
      </p>
      <table style={{ fontSize: 12, width: '100%', borderCollapse: 'collapse' }}>
        <tbody>
          {[
            ['Type',       cfg.label],
            ['Risk Score', `${zone.riskScore}%`],
            ['Base Score', `${zone.baseScore}`],
            ['Radius',     `${zone.radius} km`],
          ].map(([k, v]) => (
            <tr key={k}>
              <td style={{ color: '#4b5563', paddingRight: 10, paddingBottom: 4 }}>{k}</td>
              <td style={{ fontWeight: 600, color: k === 'Risk Score' ? zone.zoneColor : '#111827' }}>{v}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <div style={{ height: 4, background: '#f3f4f6', borderRadius: 2, marginTop: 8 }}>
        <div style={{ height: 4, width: `${zone.riskScore}%`, background: zone.zoneColor, borderRadius: 2 }} />
      </div>
    </div>
  )
}

function SOSPopupContent({ point }) {
  const color = SOS_COLORS[point.status] || '#8b5cf6'
  return (
    <div style={{ fontFamily: 'Inter, sans-serif', minWidth: 190 }}>
      <p style={{ fontWeight: 700, fontSize: 13, marginBottom: 6, color }}>🆘 SOS Incident</p>
      {[
        ['User',    point.user_phone],
        ['Status',  point.status?.replace('_', ' ')],
        ['Message', point.message || '—'],
      ].map(([k, v]) => (
        <p key={k} style={{ fontSize: 12, marginBottom: 2 }}>
          <span style={{ color: '#4b5563' }}>{k}: </span>
          <span style={{ fontWeight: 600, color: '#111827' }}>{v}</span>
        </p>
      ))}
      {point.createdAt && (
        <p style={{ fontSize: 11, color: '#9ca3af', marginTop: 4 }}>
          {format(new Date(point.createdAt), 'MMM d, yyyy HH:mm')}
        </p>
      )}
    </div>
  )
}

function ZoneListItem({ zone }) {
  const cfg = ZONE_CONFIG[zone.zoneType] || ZONE_CONFIG.safe
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 10, padding: '9px 10px',
      background: '#ffffff', borderRadius: 8,
      border: '1px solid var(--border)', transition: 'all 0.15s',
    }}>
      <div style={{ width: 10, height: 36, borderRadius: 3, background: zone.zoneColor, flexShrink: 0 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <p style={{ fontSize: 13, fontWeight: 600, marginBottom: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {zone.name}
        </p>
        <p style={{ fontSize: 10, color: 'var(--text-muted)', fontFamily: 'monospace' }}>
          {zone.lat.toFixed(4)}°, {zone.lon.toFixed(4)}°
        </p>
        <div style={{ height: 3, background: 'var(--bg-hover)', borderRadius: 2, marginTop: 3 }}>
          <div style={{ height: 3, width: `${zone.riskScore}%`, background: zone.zoneColor, borderRadius: 2 }} />
        </div>
      </div>
      <div style={{ textAlign: 'right', flexShrink: 0 }}>
        <p style={{ fontSize: 15, fontWeight: 800, color: zone.zoneColor, lineHeight: 1 }}>{zone.riskScore}%</p>
        <span style={{
          fontSize: 9, fontWeight: 700, padding: '2px 6px', borderRadius: 10,
          background: `${zone.zoneColor}20`, color: zone.zoneColor,
          display: 'inline-block', marginTop: 3, textTransform: 'uppercase', letterSpacing: 0.5,
        }}>
          {cfg.emoji} {zone.zoneType}
        </span>
      </div>
    </div>
  )
}
