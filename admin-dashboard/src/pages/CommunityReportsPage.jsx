import { useState, useEffect } from 'react'
import { fetchCommunityReports } from '../api'
import { LuMessageSquare, LuMapPin, LuClock, LuTriangleAlert } from 'react-icons/lu'
import { Topbar } from '../components/Topbar'

function getReportCoordinates(report) {
  const geo = report.location?.coordinates
  const lat = Number(report.latitude ?? report.lat ?? (Array.isArray(geo) ? geo[1] : undefined))
  const lon = Number(report.longitude ?? report.lon ?? report.lng ?? (Array.isArray(geo) ? geo[0] : undefined))
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null
  return { lat, lon }
}

export default function CommunityReportsPage() {
  const [reports, setReports] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    load()
    window.addEventListener('realtime_update', load)
    return () => window.removeEventListener('realtime_update', load)
  }, [])

  const load = () => {
    fetchCommunityReports().then(data => {
      setReports(data.reports || [])
      setLoading(false)
    }).catch(err => {
      console.error(err)
      setLoading(false)
    })
  }

  return (
    <div className="page-main-container">
      <Topbar title="Community Reports" sub="Real-time citizen-reported safety incidents" />
      <div className="page-content">
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          {loading ? (
            <div style={{ padding: 100 }} className="loading-spinner"><div className="spinner"></div></div>
          ) : reports.length === 0 ? (
            <div className="empty-state">
              <div className="empty-icon"><LuMessageSquare size={32} /></div>
              <p>No community reports found</p>
            </div>
          ) : (
            <div className="table-container">
              <table>
                <thead>
                  <tr>
                    <th>Incident Type</th>
                    <th>Severity</th>
                    <th>Reporter</th>
                    <th style={{ width: '35%' }}>Description</th>
                    <th>Coordinates</th>
                    <th>Reported At</th>
                  </tr>
                </thead>
                <tbody>
                  {reports.map((r, i) => {
                    const isAnon = r.anonymous !== false && r.anonymous !== 'false' && !r.reporterName
                    const reporterText = isAnon ? '🔒 Anonymous' : (r.reporterName || r.phone || '👤 Citizen')

                    const sev = Number(r.severity) || 2
                    let sevColor = '#b45309', sevLabel = 'Medium'
                    if (sev >= 3) { sevColor = '#ef4444'; sevLabel = 'High' }
                    else if (sev <= 1) { sevColor = '#10b981'; sevLabel = 'Low' }

                    return (
                      <tr key={r._id || i}>
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                            <div style={{ width: 8, height: 8, borderRadius: '50%', background: sevColor }} />
                            <span style={{ fontWeight: 700, color: 'var(--text-primary)' }}>
                              {r.incident_type || r.incidentType || 'General'}
                            </span>
                          </div>
                        </td>
                        <td>
                          <span className={`badge ${sev >= 3 ? 'badge-active' : sev <= 1 ? 'badge-resolved' : 'badge-false'}`}>
                            {sevLabel}
                          </span>
                        </td>
                        <td>
                          <div style={{ fontWeight: 700, color: isAnon ? 'var(--text-muted)' : 'var(--text-primary)' }}>
                            {reporterText}
                            {r.phone && !isAnon && <div style={{ fontSize: 11, color: 'var(--text-muted)', fontWeight: 500, marginTop: 2 }}>{r.phone}</div>}
                          </div>
                        </td>
                        <td style={{ fontSize: 13, color: 'var(--text-secondary)', lineHeight: 1.6, padding: '16px' }}>
                          {r.description || <span style={{ color: 'var(--text-muted)', fontStyle: 'italic' }}>No description provided</span>}
                        </td>
                        <td className="td-mono" style={{ fontSize: 12 }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: 'var(--brand-secondary)', fontWeight: 600 }}>
                            <LuMapPin size={13} />
                            {(() => {
                              const coords = getReportCoordinates(r)
                              return coords ? `${coords.lat.toFixed(4)}, ${coords.lon.toFixed(4)}` : '—'
                            })()}
                          </div>
                        </td>
                        <td className="td-muted" style={{ fontSize: 12 }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                            <LuClock size={13} />
                            {new Date(r.timestamp || r.createdAt).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}
                          </div>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}