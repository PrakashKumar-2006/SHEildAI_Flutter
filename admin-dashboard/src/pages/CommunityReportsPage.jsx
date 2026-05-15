import { useState, useEffect } from 'react'
import { fetchCommunityReports } from '../api'
import { LuMessageSquare, LuMapPin, LuClock, LuTriangleAlert } from 'react-icons/lu'

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
    <div className="page-content">
      <div className="topbar-left" style={{ marginBottom: 30 }}>
        <h2>Community Reports</h2>
        <p>Real-time citizen-reported safety incidents</p>
      </div>

      <div className="card">
        {loading ? (
          <div className="loading-spinner"><div className="spinner"></div></div>
        ) : reports.length === 0 ? (
          <div className="empty-state">
            <div className="empty-icon"><LuMessageSquare size={32} /></div>
            <p>No community reports found</p>
          </div>
        ) : (
          <div className="table-wrapper">
            <table>
              <thead>
                <tr>
                  <th>Incident Type</th>
                  <th>Severity</th>
                  <th>Reporter</th>
                  <th style={{ width: '40%' }}>Description</th>
                  <th>Coordinates</th>
                  <th>Reported At</th>
                </tr>
              </thead>
              <tbody>
                {reports.map((r, i) => {
                  const coords = getReportCoordinates(r)
                  const isAnon = r.anonymous !== false && r.anonymous !== 'false' && !r.reporterName
                  const reporterText = isAnon ? '🔒 Anonymous' : (r.reporterName || r.phone || '👤 Citizen')
                  
                  // Map severity (1-3 or 1-5) to colors
                  const sev = Number(r.severity) || 2
                  let sevBg = '#fef3c7', sevColor = '#b45309', sevLabel = 'Medium'
                  if (sev >= 3) { sevBg = '#fee2e2'; sevColor = '#b91c1c'; sevLabel = 'High' }
                  else if (sev <= 1) { sevBg = '#ecfdf5'; sevColor = '#047857'; sevLabel = 'Low' }

                  return (
                    <tr key={r._id || i} style={{ alignItems: 'flex-start' }}>
                      <td>
                        <span className="badge" style={{ background: '#f3f4f6', color: '#374151', border: '1px solid #e5e7eb', fontWeight: 700 }}>
                          <LuTriangleAlert size={12} style={{ color: sevColor }} /> 
                          {r.incident_type || r.incidentType || 'General'}
                        </span>
                      </td>
                      <td>
                        <span className="badge" style={{ background: sevBg, color: sevColor, border: `1px solid ${sevColor}20` }}>
                          {sevLabel} (L{sev})
                        </span>
                      </td>
                      <td style={{ fontWeight: 600, color: isAnon ? 'var(--text-muted)' : 'var(--text-primary)' }}>
                        {reporterText}
                        {r.phone && !isAnon && <div style={{ fontSize: 11, color: 'var(--text-muted)', fontWeight: 500 }}>{r.phone}</div>}
                      </td>
                      <td style={{ whiteSpace: 'normal', wordBreak: 'break-word', lineHeight: 1.5, minWidth: 240, padding: '12px 16px' }}>
                        {r.description || <span style={{ color: 'var(--text-muted)', fontStyle: 'italic' }}>No description text provided</span>}
                      </td>
                      <td className="td-mono" style={{ fontSize: 12 }}>
                        <LuMapPin size={12} style={{ marginRight: 4, color: '#3b82f6' }} /> 
                        {coords ? `${coords.lat.toFixed(4)}, ${coords.lon.toFixed(4)}` : '—'}
                      </td>
                      <td className="td-muted" style={{ fontSize: 12, whiteSpace: 'nowrap' }}>
                        <LuClock size={12} style={{ marginRight: 4 }} />
                        {new Date(r.timestamp || r.createdAt).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}
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
  )
}
