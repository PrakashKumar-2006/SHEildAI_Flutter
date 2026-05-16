import { useEffect, useState, useMemo, useRef } from 'react'
import toast from 'react-hot-toast'
import L from 'leaflet'
import {
  MapContainer, TileLayer, Circle, CircleMarker, Popup, Tooltip,
  useMap, ZoomControl, Marker,
} from 'react-leaflet'
import { fetchRiskZones, fetchHeatmapData, fetchMLHotspots, fetchLiveLocations } from '../api'
import { Topbar } from '../components/Topbar'
import { format } from 'date-fns'
import { LuMap, LuShieldCheck } from 'react-icons/lu'
import 'leaflet/dist/leaflet.css'

// ── Zone config — identical to Flutter app ZoneModel ──────────────────────
const ZONE_CONFIG = {
  safe: { color: '#43A047', label: 'Safe Zone', emoji: '🟢' },
  moderate: { color: '#F39C12', label: 'Moderate Zone', emoji: '🟡' },
  high: { color: '#E74C3C', label: 'High Risk Zone', emoji: '🟠' },
  critical: { color: '#8B0000', label: 'Critical Zone', emoji: '🔴' },
}

const SOS_COLORS = {
  active: '#ef4444', // Red-500
  resolved: '#10b981', // Emerald-500
  false_alarm: '#f59e0b', // Amber-500
}

const formatRelativeTime = (date) => {
  if (!date) return 'Unknown'
  const now = new Date()
  const diff = now - new Date(date)
  const minutes = Math.floor(diff / 60000)
  if (minutes < 1) return 'Just now'
  if (minutes < 60) return `${minutes}m ago`
  return `${Math.round(minutes / 60)}h ago`
}

// Auto-fit map to all zones and the first arriving live location
function FitBounds({ zones, liveLocation, liveUsers }) {
  const map = useMap()
  const fitted = useRef(false)
  const fittedWithLive = useRef(false)

  return null
}

// ── Map Fly-To Controller ──────────────────────────────────────────────
function MapFlyTo({ pos }) {
  const map = useMap()
  useEffect(() => {
    if (pos) {
      map.flyTo(pos, 15, { duration: 1.5 })
    }
  }, [pos, map])
  return null
}

export default function HeatmapPage() {
  const [riskData, setRiskData] = useState({ zones: [], currentHour: 0, multiplier: 0 })
  const [sosPoints, setSosPoints] = useState([])
  const [loading, setLoading] = useState(true)
  const [layer, setLayer] = useState('zones')
  const [filterType, setFilter] = useState('all')
  const [liveLocation, setLiveLoc] = useState(null)
  const [liveUsers, setLiveUsers] = useState([])
  const [flyToPos, setFlyToPos] = useState(null)

  const loadData = (showLoading = false) => {
    if (showLoading) setLoading(true)
    Promise.all([
      fetchRiskZones().catch(() => null),
      fetchHeatmapData().catch(() => []),
      fetchMLHotspots().catch(() => []),
      fetchLiveLocations({ sinceMinutes: 240, limit: 100 }).catch(() => ({ locations: [] }))
    ])
      .then(([rd, sos, mlHotspots, live]) => {
        // Fallback default zones if live backend array is empty or deploying
        const defaultZones = [
          { "name": "Shyamla Hills", "lat": 23.245, "lon": 77.418, "baseScore": 16.0, "riskScore": 16, "zoneType": "safe", "zoneColor": "#43A047" },
          { "name": "TT Nagar", "lat": 23.235, "lon": 77.412, "baseScore": 18.0, "riskScore": 18, "zoneType": "safe", "zoneColor": "#43A047" },
          { "name": "MP Nagar", "lat": 23.2332, "lon": 77.4272, "baseScore": 22.0, "riskScore": 22, "zoneType": "safe", "zoneColor": "#43A047" },
          { "name": "Gandhi Nagar", "lat": 23.248, "lon": 77.408, "baseScore": 24.0, "riskScore": 24, "zoneType": "safe", "zoneColor": "#43A047" },
          { "name": "Kamla Nagar", "lat": 23.218, "lon": 77.438, "baseScore": 29.0, "riskScore": 29, "zoneType": "moderate", "zoneColor": "#F39C12" },
          { "name": "Habibganj", "lat": 23.2289, "lon": 77.4382, "baseScore": 31.0, "riskScore": 31, "zoneType": "moderate", "zoneColor": "#F39C12" },
          { "name": "Ashoka Garden", "lat": 23.238, "lon": 77.478, "baseScore": 37.0, "riskScore": 37, "zoneType": "moderate", "zoneColor": "#F39C12" },
          { "name": "Ayodhya Nagar", "lat": 23.225, "lon": 77.482, "baseScore": 40.0, "riskScore": 40, "zoneType": "moderate", "zoneColor": "#F39C12" },
          { "name": "Kotwali", "lat": 23.258, "lon": 77.4025, "baseScore": 42.0, "riskScore": 42, "zoneType": "moderate", "zoneColor": "#F39C12" },
          { "name": "Aishbag", "lat": 23.25, "lon": 77.4, "baseScore": 44.0, "riskScore": 44, "zoneType": "moderate", "zoneColor": "#F39C12" },
          { "name": "Piplani", "lat": 23.2458, "lon": 77.4672, "baseScore": 55.0, "riskScore": 55, "zoneType": "high", "zoneColor": "#E74C3C" },
          { "name": "Govindpura", "lat": 23.262, "lon": 77.472, "baseScore": 61.0, "riskScore": 61, "zoneType": "high", "zoneColor": "#E74C3C" },
          { "name": "Misrod", "lat": 23.198, "lon": 77.487, "baseScore": 66.0, "riskScore": 66, "zoneType": "high", "zoneColor": "#E74C3C" },
          { "name": "Kolar Road", "lat": 23.178, "lon": 77.458, "baseScore": 74.0, "riskScore": 74, "zoneType": "high", "zoneColor": "#E74C3C" },
          { "name": "Ratibad", "lat": 23.1452, "lon": 77.358, "baseScore": 83.0, "riskScore": 83, "zoneType": "critical", "zoneColor": "#8B0000" },
          { "name": "Berasia", "lat": 23.628, "lon": 77.435, "baseScore": 88.0, "riskScore": 88, "zoneType": "critical", "zoneColor": "#8B0000" },
          { "name": "MG Road Indore", "lat": 22.7196, "lon": 75.8577, "baseScore": 18.0, "riskScore": 18, "zoneType": "safe", "zoneColor": "#43A047" },
          { "name": "Vijay Nagar", "lat": 22.746, "lon": 75.8873, "baseScore": 22.0, "riskScore": 22, "zoneType": "safe", "zoneColor": "#43A047" },
          { "name": "Palasia", "lat": 22.7278, "lon": 75.8716, "baseScore": 25.0, "riskScore": 25, "zoneType": "safe", "zoneColor": "#43A047" },
          { "name": "Banganga", "lat": 22.72, "lon": 75.835, "baseScore": 37.0, "riskScore": 37, "zoneType": "moderate", "zoneColor": "#F39C12" },
          { "name": "Lasudia", "lat": 22.738, "lon": 75.902, "baseScore": 55.0, "riskScore": 55, "zoneType": "high", "zoneColor": "#E74C3C" },
          { "name": "Devguradia", "lat": 22.802, "lon": 75.92, "baseScore": 77.0, "riskScore": 77, "zoneType": "critical", "zoneColor": "#8B0000" }
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
            id: `ml_${z.id || z.zone_id || z.name || z.police_station || idx}`,
            name: z.name || z.police_station || z.zone_name || 'ML Hotspot',
            lat: Number(z.lat) || 23.25,
            lon: Number(z.lon) || 77.41,
            radius: Number(z.radius) || Number(z.radius_km) || (Number(z.radius_m) ? Number(z.radius_m) / 1000 : 0.8),
            baseScore: riskScore, riskScore, zoneType, zoneColor, zoneLabel
          };
        });

        setRiskData({
          zones: [...fetchedZones, ...mlZones],
          currentHour: rd?.currentHour || new Date().getHours(),
          multiplier: rd?.multiplier || 0
        })

        // Final SOS mapping ensuring numbers
        const cleanSOS = (Array.isArray(sos) ? sos : (sos?.incidents || [])).map(p => ({
          ...p,
          lat: Number(p.lat),
          lon: Number(p.lon)
        })).filter(p => !isNaN(p.lat) && !isNaN(p.lon))

        setSosPoints(cleanSOS)
        setLiveUsers(Array.isArray(live?.locations) ? live.locations : [])
      })
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    loadData(true)

    // Continuously watch user's live location with max high-accuracy settings
    let watchId;
    if (navigator.geolocation) {
      watchId = navigator.geolocation.watchPosition(
        (pos) => {
          if (pos?.coords?.latitude && pos?.coords?.longitude) {
            setLiveLoc([pos.coords.latitude, pos.coords.longitude])
          }
        },
        (err) => console.warn("Could not get live location", err),
        { enableHighAccuracy: true, maximumAge: 0, timeout: 10000 }
      )
    }

    const handleUpdate = () => loadData(false)
    window.addEventListener('realtime_update', handleUpdate)

    // Listen for socket-driven detailed location updates
    const handleLiveUser = (e) => {
      const data = e.detail
      if (!data?.phone) return
      setLiveUsers(prev => {
        const idx = prev.findIndex(u => u.phone === data.phone)
        const updated = {
          phone: data.phone,
          name: data.name || 'User',
          lat: Number(data.lat),
          lon: Number(data.lon),
          last_seen: new Date().toISOString(),
          isOnline: true
        }
        if (idx > -1) {
          const newList = [...prev]
          newList[idx] = updated
          return newList
        }
        return [updated, ...prev].slice(0, 100)
      })
    }
    window.addEventListener('live_location_update', handleLiveUser)

    const intervalId = setInterval(() => loadData(false), 5 * 60 * 1000)

    return () => {
      window.removeEventListener('realtime_update', handleUpdate)
      window.removeEventListener('live_location_update', handleLiveUser)
      if (watchId) navigator.geolocation.clearWatch(watchId)
      clearInterval(intervalId)
    }
  }, [])

  const filteredZones = useMemo(() => {
    if (filterType === 'all') return riskData.zones
    return riskData.zones.filter(z => z.zoneType === filterType)
  }, [riskData.zones, filterType])

  const zoneStats = useMemo(() => {
    const counts = { safe: 0, moderate: 0, high: 0, critical: 0, ml: 0, manual: 0 }
    riskData.zones.forEach(z => {
      if (counts[z.zoneType] !== undefined) counts[z.zoneType]++
      if (z.id?.toString().startsWith('ml_')) counts.ml++
      else counts.manual++
    })
    return counts
  }, [riskData.zones])

  const mapCenter = useMemo(() => {
    if (liveLocation) return liveLocation
    if (filteredZones.length > 0) return [filteredZones[0].lat, filteredZones[0].lon]
    return [23.2599, 77.4126] // Bhopal default
  }, [liveLocation, filteredZones])

  return (
    <div className="page-main-container">
      <Topbar title="Safety Heatmap" sub="Real-time risk analysis & emergency monitoring" />

      <div className="page-content">
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <div className="card-header" style={{ padding: '12px 20px', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ display: 'flex', gap: 12 }}>
              <div className="filter-group">
                <span style={{ fontSize: 11, fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', marginRight: 8 }}>View:</span>
                <div className="btn-group">
                  {[
                    { key: 'zones', label: '🛡️ Zones' },
                    { key: 'sos', label: '🚨 SOS' },
                    { key: 'both', label: '📍 Both' },
                  ].map(l => (
                    <button
                      key={l.key}
                      className={`btn btn-sm ${layer === l.key ? 'btn-primary' : 'btn-ghost'}`}
                      onClick={() => setLayer(l.key)}
                    >
                      {l.label}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
              <div style={{
                display: 'flex', background: 'var(--bg-hover)', padding: '4px', borderRadius: '12px', gap: '4px',
                border: '1px solid var(--border)'
              }}>
                {[
                  { key: 'all', label: 'All', count: riskData.zones.length },
                  { key: 'critical', label: '🔴 Crit', count: zoneStats.critical },
                  { key: 'high', label: '🟠 High', count: zoneStats.high },
                  { key: 'moderate', label: '🟡 Mod', count: zoneStats.moderate },
                  { key: 'safe', label: '🟢 Safe', count: zoneStats.safe },
                ].map(f => (
                  <button
                    key={f.key}
                    className={`btn btn-sm ${filterType === f.key ? 'btn-primary' : 'btn-ghost'}`}
                    style={{
                      display: 'flex', alignItems: 'center', gap: 6,
                      padding: '6px 12px', borderRadius: '8px', border: 'none',
                      background: filterType === f.key ? 'var(--brand-primary)' : 'transparent',
                      color: filterType === f.key ? '#fff' : 'var(--text-secondary)',
                      transition: 'var(--transition)',
                      fontWeight: 700, fontSize: '12px'
                    }}
                    onClick={() => setFilter(f.key)}
                  >
                    {f.label}
                    <span style={{
                      fontSize: 10, fontWeight: 800, padding: '1px 6px', borderRadius: 6,
                      background: filterType === f.key ? 'rgba(255,255,255,0.2)' : 'var(--bg-base)',
                      color: filterType === f.key ? '#fff' : 'var(--text-primary)',
                      minWidth: '20px', textAlign: 'center'
                    }}>
                      {f.count}
                    </span>
                  </button>
                ))}
              </div>
            </div>
          </div>

          <div style={{ display: 'flex' }}>
            {/* Map Sidebar - Zone List */}
            <div style={{
              width: 320, borderRight: '1px solid var(--border)',
              display: 'flex', flexDirection: 'column', height: 600,
              background: 'var(--bg-surface)'
            }}>
              <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--border)', background: 'var(--bg-hover)' }}>
                <p style={{ fontSize: 13, fontWeight: 800, color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: 8 }}>
                  <LuMap size={16} /> Regional Surveillance
                </p>
                <p style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 2 }}>Monitoring {filteredZones.length} hotspots</p>
              </div>

              <div className="zone-list" style={{ flex: 1, overflowY: 'auto', padding: '10px' }}>
                {filteredZones.length === 0 ? (
                  <div style={{ padding: 40, textAlign: 'center', opacity: 0.5 }}>
                    <LuShieldCheck size={32} style={{ marginBottom: 12 }} />
                    <p style={{ fontSize: 13, fontWeight: 600 }}>No zones in filter</p>
                  </div>
                ) : (
                  filteredZones.sort((a, b) => b.riskScore - a.riskScore).map(zone => (
                    <div
                      key={zone.id}
                      className="zone-item"
                      style={{
                        padding: '12px 16px', borderRadius: 12, marginBottom: 8,
                        border: '1px solid var(--border)', background: 'var(--bg-base)',
                        cursor: 'pointer', transition: 'var(--transition)'
                      }}
                      onClick={() => {
                        setFlyToPos([zone.lat, zone.lon])
                      }}
                    >
                      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                        <span style={{ fontSize: 14, fontWeight: 800, color: 'var(--text-primary)' }}>{zone.name}</span>
                        <span style={{
                          fontSize: 10, fontWeight: 800, padding: '2px 6px', borderRadius: 6,
                          background: `${zone.zoneColor}15`, color: zone.zoneColor
                        }}>{zone.riskScore} PTS</span>
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                        <div style={{ width: 6, height: 6, borderRadius: '50%', background: zone.zoneColor }} />
                        <span style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-muted)', textTransform: 'capitalize' }}>
                          {zone.zoneType} Risk Level
                        </span>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>

            {/* Map Content */}
            <div style={{ flex: 1, position: 'relative', height: 600 }}>
              {loading ? (
                <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--bg-base)' }}>
                  <div className="spinner"></div>
                </div>
              ) : (
                <MapContainer
                  center={mapCenter}
                  zoom={12}
                  style={{ height: '100%', width: '100%' }}
                  zoomControl={false}
                >
                  <TileLayer
                    url="https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}"
                    attribution='&copy; Google Maps'
                    maxZoom={19}
                  />
                  <ZoomControl position="bottomright" />
                  <FitBounds zones={filteredZones} liveLocation={liveLocation} liveUsers={liveUsers} />
                  <MapFlyTo pos={flyToPos} />

                  {liveLocation && (
                    <CircleMarker
                      center={liveLocation}
                      radius={8}
                      pathOptions={{ fillColor: '#3b82f6', fillOpacity: 1, color: '#fff', weight: 2 }}
                    />
                  )}

                  {liveUsers.map((user) => (
                    <CircleMarker
                      key={user.phone}
                      center={[user.lat, user.lon]}
                      radius={7}
                      pathOptions={{ fillColor: user.isOnline ? '#10b981' : '#64748b', fillOpacity: 0.9, color: '#fff', weight: 2 }}
                    >
                      <Popup closeButton={false}><LiveUserPopup user={user} /></Popup>
                    </CircleMarker>
                  ))}

                  {(layer === 'zones' || layer === 'both') && filteredZones.map(zone => (
                    <Circle
                      key={zone.id}
                      center={[zone.lat, zone.lon]}
                      radius={zone.radius * 1000}
                      pathOptions={{ fillColor: zone.zoneColor, fillOpacity: 0.25, color: zone.zoneColor, weight: 2 }}
                    >
                      <Popup closeButton={false}><ZonePopupContent zone={zone} /></Popup>
                    </Circle>
                  ))}

                  {(layer === 'sos' || layer === 'both') && sosPoints.map((p, i) => {
                    const statusClass = p.status === 'active' ? 'sos-pulse-active' : (p.status === 'false_alarm' ? 'sos-pulse-false' : 'sos-pulse-resolved');
                    const icon = L.divIcon({
                      className: 'sos-marker-container',
                      html: `<div class="sos-pulse ${statusClass}"></div>`,
                      iconSize: [20, 20]
                    });
                    return (
                      <Marker key={i} position={[p.lat, p.lon]} icon={icon}>
                        <Popup closeButton={false}><SOSPopupContent point={p} /></Popup>
                      </Marker>
                    )
                  })}
                </MapContainer>
              )}
            </div>
          </div>

          {/* Legend */}
          <div style={{
            padding: '12px 20px', borderTop: '1px solid var(--border)',
            display: 'flex', gap: 18, flexWrap: 'wrap', alignItems: 'center',
            fontSize: 12, color: 'var(--text-secondary)', background: 'var(--bg-hover)'
          }}>
            <span style={{ fontWeight: 700, color: 'var(--text-primary)' }}>Legend:</span>
            {Object.entries(ZONE_CONFIG).map(([t, c]) => (
              <LegendDot key={t} color={c.color} label={c.label} />
            ))}
            {(layer === 'sos' || layer === 'both') && Object.entries(SOS_COLORS).map(([k, c]) => (
              <LegendDot key={k} color={c} label={k.replace('_', ' ')} filled />
            ))}
            <div style={{ marginLeft: 'auto', display: 'flex', gap: 12, alignItems: 'center' }}>
              <span style={{ fontSize: 11, background: 'var(--bg-active)', padding: '2px 8px', borderRadius: 4 }}>Time: {riskData.currentHour}:00</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

function LegendDot({ color, label, filled = false }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
      <div style={{
        width: 10, height: 10, borderRadius: '50%', background: color,
        border: `1.5px solid ${filled ? 'white' : color}`,
        boxShadow: filled ? '0 0 0 1px #e2e8f0' : 'none'
      }} />
      <span style={{ fontWeight: 600 }}>{label}</span>
    </div>
  )
}

function ZonePopupContent({ zone }) {
  return (
    <div style={{ minWidth: 160, padding: '4px 0' }}>
      <p style={{ margin: 0, fontSize: 14, fontWeight: 800, color: 'var(--text-primary)', borderBottom: '1px solid var(--border)', paddingBottom: 6, marginBottom: 8 }}>
        {ZONE_CONFIG[zone.zoneType].emoji} {zone.name}
      </p>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
        <span style={{ color: 'var(--text-muted)', fontSize: 11 }}>Risk Score</span>
        <span style={{ fontWeight: 700, color: zone.zoneColor }}>{zone.riskScore}/100</span>
      </div>
      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
        <span style={{ color: 'var(--text-muted)', fontSize: 11 }}>Category</span>
        <span style={{ fontWeight: 600, fontSize: 11, color: zone.zoneColor, textTransform: 'capitalize' }}>{zone.zoneType}</span>
      </div>
    </div>
  )
}

function SOSPopupContent({ point }) {
  return (
    <div style={{ minWidth: 180, padding: '4px 0' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8, borderBottom: '1px solid var(--border)', paddingBottom: 6 }}>
        <div style={{ width: 8, height: 8, borderRadius: '50%', background: SOS_COLORS[point.status] || '#ef4444' }} />
        <p style={{ margin: 0, fontSize: 13, fontWeight: 800, color: '#1e293b', textTransform: 'uppercase' }}>
          Emergency Alert
        </p>
      </div>
      <div style={{ marginBottom: 10 }}>
        <p style={{ margin: 0, fontSize: 11, color: 'var(--text-muted)' }}>Triggered By</p>
        <p style={{ margin: 0, fontSize: 12, fontWeight: 700, color: 'var(--text-primary)' }}>{point.user_phone || 'Anonymous User'}</p>
      </div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span style={{ fontSize: 10, color: 'var(--text-muted)' }}>{formatRelativeTime(point.timestamp || point.createdAt)}</span>
        <span style={{
          fontSize: 9, fontWeight: 800, padding: '2px 6px', borderRadius: 4,
          background: (SOS_COLORS[point.status] || '#ef4444') + '15',
          color: SOS_COLORS[point.status] || '#ef4444',
          textTransform: 'uppercase'
        }}>
          {point.status?.replace('_', ' ') || 'active'}
        </span>
      </div>
    </div>
  )
}

function LiveUserPopup({ user }) {
  return (
    <div style={{ minWidth: 150, padding: '4px 0' }}>
      <p style={{ margin: 0, fontSize: 13, fontWeight: 800, color: 'var(--text-primary)', marginBottom: 6 }}>
        👤 {user.name || 'Citizen'}
      </p>
      <p style={{ margin: 0, fontSize: 11, color: 'var(--text-secondary)', marginBottom: 8 }}>
        {user.phone}
      </p>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span style={{ fontSize: 10, color: 'var(--text-muted)' }}>{formatRelativeTime(user.last_seen || user.updatedAt)}</span>
        <span style={{
          fontSize: 9, fontWeight: 800, padding: '2px 6px', borderRadius: 4,
          background: user.isOnline ? '#10b98115' : '#64748b15',
          color: user.isOnline ? '#10b981' : '#64748b'
        }}>
          {user.isOnline ? 'ONLINE' : 'OFFLINE'}
        </span>
      </div>
    </div>
  )
}
