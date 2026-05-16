import { useState, useEffect, useCallback } from 'react'
import toast from 'react-hot-toast'
import { fetchSOS, updateSOS, deleteSOS, fetchStats } from '../api'
import { Topbar } from '../components/Topbar'
import { ConfirmModal } from './UsersPage'
import { format } from 'date-fns'
import { LuSearch, LuTriangleAlert, LuCheck, LuOctagonAlert, LuPen, LuTrash2, LuDownload, LuClock, LuMapPin } from 'react-icons/lu'

const STATUS_OPTIONS = ['', 'active', 'resolved', 'false_alarm']

export default function SOSPage() {
  const [data, setData] = useState({ sos: [], total: 0, totalPages: 1 })
  const [page, setPage] = useState(1)
  const [search, setSearch] = useState('')
  const [statusFilter, setStatus] = useState('')
  const [loading, setLoading] = useState(true)
  const [stats, setStats] = useState(null)
  const [editItem, setEditItem] = useState(null)
  const [deleteTarget, setDelete] = useState(null)

  const load = useCallback((silent = false) => {
    if (!silent) setLoading(true)
    Promise.all([
      fetchSOS({ page, limit: 15, status: statusFilter, search }),
      fetchStats()
    ])
      .then(([sosData, statsData]) => {
        setData(sosData)
        setStats(statsData)
      })
      .catch(e => toast.error(e.response?.data?.error || 'Failed to load SOS data'))
      .finally(() => setLoading(false))
  }, [page, search, statusFilter])

  useEffect(() => { load() }, [load])

  // Auto-refresh active incidents every 45s for live monitoring
  useEffect(() => {
    const handleUpdate = () => load(true)
    window.addEventListener('realtime_update', handleUpdate)
    const interval = setInterval(() => { load(true) }, 45000)
    return () => {
      clearInterval(interval)
      window.removeEventListener('realtime_update', handleUpdate)
    }
  }, [load])

  const handleDelete = async () => {
    try {
      await deleteSOS(deleteTarget._id)
      toast.success('SOS record deleted')
      setDelete(null)
      load()
    } catch (e) {
      toast.error(e.response?.data?.error || 'Delete failed')
    }
  }

  const handleUpdate = async (form) => {
    try {
      await updateSOS(editItem._id, form)
      toast.success('SOS record updated')
      setEditItem(null)
      load()
    } catch (e) {
      toast.error(e.response?.data?.error || 'Update failed')
    }
  }

  const quickStatus = async (id, status) => {
    try {
      await updateSOS(id, { status })
      toast.success(`Marked as ${status}`)
      load()
    } catch (e) {
      toast.error('Failed to update status')
    }
  }

  const handleExport = async () => {
    try {
      const exportData = await fetchSOS({ page: 1, limit: 10000, status: statusFilter, search })
      if (!exportData.sos || exportData.sos.length === 0) return toast.error('No data to export')

      const csvLines = []
      csvLines.push('ID,User Phone,Status,Message,Latitude,Longitude,Created At,Updated At')
      exportData.sos.forEach(s => {
        const row = [
          s._id,
          s.user_phone,
          s.status,
          `"${(s.message || '').replace(/"/g, '""')}"`,
          s.location?.lat || '',
          s.location?.lon || '',
          s.createdAt || '',
          s.updatedAt || ''
        ]
        csvLines.push(row.join(','))
      })

      const blob = new Blob([csvLines.join('\n')], { type: 'text/csv' })
      const url = window.URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `sos_export_${format(new Date(), 'yyyyMMdd_HHmm')}.csv`
      a.click()
      window.URL.revokeObjectURL(url)
    } catch (e) {
      toast.error('Export failed')
    }
  }

  return (
    <div className="page-main-container">
      <Topbar title="SOS Incidents" sub={`Monitoring ${data.total} emergency trigger points`} />
      <div className="page-content">
        {/* Global Summary Bar */}
        <div className="stats-grid" style={{ gridTemplateColumns: 'repeat(3, 1fr)', gap: 16 }}>
          {[
            { label: 'Active Alerts', val: stats?.activeSOS ?? 0, color: '#ef4444', icon: <LuTriangleAlert />, glow: 'rgba(239, 68, 68, 0.1)' },
            { label: 'Total Resolved', val: stats?.resolvedSOS ?? 0, color: '#10b981', icon: <LuCheck />, glow: 'rgba(16, 185, 129, 0.08)' },
            { label: 'Historical Log', val: stats?.totalSOS ?? 0, color: '#3b82f6', icon: <LuClock />, glow: 'rgba(59, 130, 246, 0.08)' },
          ].map(s => (
            <div key={s.label} className="card" style={{ padding: 20, position: 'relative' }}>
              <div style={{ color: s.color, marginBottom: 12 }}>{s.icon}</div>
              <p style={{ fontSize: 11, fontWeight: 800, color: 'var(--text-muted)', textTransform: 'uppercase', marginBottom: 4 }}>{s.label}</p>
              <p style={{ fontSize: 26, fontWeight: 900, color: 'var(--text-primary)' }}>{s.val.toLocaleString()}</p>
              {s.label === 'Active Alerts' && s.val > 0 && <div className="pulse" style={{ position: 'absolute', top: 15, right: 15, background: s.color }} />}
            </div>
          ))}
        </div>

        <div className="card">
          <div className="card-header" style={{ borderBottom: '1px solid var(--border)', padding: '10px 16px' }}>
            <div>
              <p className="card-title" style={{ fontSize: 15 }}>Active Incidents</p>
              <p className="card-subtitle" style={{ fontSize: 11 }}>Manage and respond to emergency triggers</p>
            </div>
            <button className="btn btn-ghost btn-sm" onClick={handleExport} style={{ fontWeight: 700, padding: '4px 10px' }}>
              <LuDownload size={14} /> Export Logs
            </button>
          </div>

          <div className="filter-bar">
            <div className="search-bar" style={{ flex: 1, maxWidth: 360 }}>
              <span className="search-icon"><LuSearch size={16} /></span>
              <input
                placeholder="Search by phone number…"
                value={search}
                onChange={e => { setSearch(e.target.value); setPage(1) }}
              />
            </div>
            <select
              className="select"
              style={{ width: 180 }}
              value={statusFilter}
              onChange={e => { setStatus(e.target.value); setPage(1) }}
            >
              <option value="">All Incidents</option>
              <option value="active">🔴 Active SOS</option>
              <option value="resolved">🟢 Resolved</option>
              <option value="false_alarm">🟡 False Alarm</option>
            </select>
          </div>

          {loading ? (
            <div style={{ padding: 100 }} className="loading-spinner"><div className="spinner" /></div>
          ) : data.sos.length === 0 ? (
            <div className="empty-state">
              <p className="empty-icon"><LuTriangleAlert size={48} color="var(--text-muted)" /></p>
              <p style={{ fontWeight: 700, fontSize: 18 }}>No incidents found</p>
              <p style={{ color: 'var(--text-muted)' }}>Everything looks clear for now.</p>
            </div>
          ) : (
            <div className="table-container">
              <table>
                <thead>
                  <tr>
                    <th>User / Responder</th>
                    <th>Status</th>
                    <th>Alert Message</th>
                    <th>Live Location</th>
                    <th>Triggered At</th>
                    <th style={{ textAlign: 'center' }}>Action</th>
                    <th>Manage</th>
                  </tr>
                </thead>
                <tbody>
                  {data.sos.map(s => (
                    <tr key={s._id} style={{
                      background: s.status === 'active' ? 'rgba(239, 68, 68, 0.02)' : 'transparent',
                    }}>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                          <div className={`sidebar-avatar ${s.status === 'active' ? 'sos-pulse-active' : ''}`} style={{
                            width: 32, height: 32, fontSize: 13,
                            background: s.status === 'active' ? '#ef4444' : 'var(--bg-hover)',
                            color: s.status === 'active' ? '#fff' : 'var(--text-muted)',
                            boxShadow: s.status === 'active' ? '0 4px 12px rgba(239, 68, 68, 0.3)' : 'none'
                          }}>
                            {s.status === 'active' ? <LuTriangleAlert size={14} /> : <LuCheck size={14} />}
                          </div>
                          <div style={{ display: 'flex', flexDirection: 'column' }}>
                            <span style={{ fontWeight: 800, color: 'var(--text-primary)', fontSize: 13, letterSpacing: '-0.01em' }}>{s.user_phone}</span>
                            <span style={{ fontSize: 10, color: 'var(--text-muted)', fontWeight: 600 }}>Emergency Call</span>
                          </div>
                        </div>
                      </td>
                      <td><StatusBadge status={s.status} /></td>
                      <td style={{ maxWidth: 220 }}>
                        <p style={{ fontSize: 13, color: 'var(--text-secondary)', lineHeight: 1.5, fontWeight: 500 }}>
                          {s.message || <span style={{ opacity: 0.5 }}>Standard emergency signal</span>}
                        </p>
                      </td>
                      <td className="td-mono">
                        <a
                          href={`https://www.google.com/maps?q=${s.location?.lat},${s.location?.lon}`}
                          target="_blank" rel="noreferrer"
                          className="btn-ghost"
                          style={{
                            display: 'inline-flex', alignItems: 'center', gap: 8,
                            color: 'var(--brand-secondary)', textDecoration: 'none',
                            fontWeight: 700, fontSize: 12, padding: '8px 12px',
                            borderRadius: 10, background: 'rgba(59, 130, 246, 0.05)'
                          }}
                        >
                          <LuMapPin size={14} />
                          {s.location?.lat ? `${s.location.lat.toFixed(4)}, ${s.location.lon?.toFixed(4)}` : 'N/A'}
                        </a>
                      </td>
                      <td className="td-muted">
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                          <span style={{ fontSize: 13, fontWeight: 700, color: 'var(--text-primary)' }}>{s.createdAt ? format(new Date(s.createdAt), 'HH:mm:ss') : '—'}</span>
                          <span style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-muted)' }}>{s.createdAt ? format(new Date(s.createdAt), 'MMM d, yyyy') : '—'}</span>
                        </div>
                      </td>
                      <td style={{ textAlign: 'center' }}>
                        <div style={{ display: 'flex', gap: 8, justifyContent: 'center' }}>
                          {s.status === 'active' ? (
                            <>
                              <button className="btn btn-primary btn-sm" style={{
                                background: '#10b981', border: 'none',
                                boxShadow: '0 4px 12px rgba(16, 185, 129, 0.2)',
                                borderRadius: 10, padding: '6px 12px',
                                fontWeight: 800
                              }} onClick={() => quickStatus(s._id, 'resolved')}>
                                <LuCheck size={14} /> RESOLVE
                              </button>
                              <button className="btn btn-sm" style={{
                                background: '#f59e0b', color: '#fff', border: 'none',
                                boxShadow: '0 4px 12px rgba(245, 158, 11, 0.2)',
                                borderRadius: 10, padding: '6px 12px',
                                fontWeight: 800
                              }} onClick={() => quickStatus(s._id, 'false_alarm')}>
                                <LuOctagonAlert size={14} /> FALSE
                              </button>
                            </>
                          ) : (
                            <span style={{ fontSize: 10, fontWeight: 900, color: 'var(--text-muted)', letterSpacing: '0.05em' }}>COMPLETED</span>
                          )}
                        </div>
                      </td>
                      <td>
                        <div className="action-btns">
                          <button className="btn btn-ghost btn-sm" style={{ borderRadius: 10 }} onClick={() => setEditItem(s)}><LuPen size={14} /></button>
                          <button className="btn btn-danger btn-sm" style={{
                            borderRadius: 10, background: 'rgba(239, 68, 68, 0.08)',
                            color: '#ef4444', border: 'none'
                          }} onClick={() => setDelete(s)}><LuTrash2 size={14} /></button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          <div className="pagination">
            <span>Showing {((page - 1) * 15) + 1}–{Math.min(page * 15, data.total)} of {data.total}</span>
            <div className="pagination-controls">
              <button className="btn btn-ghost btn-sm" disabled={page <= 1} onClick={() => setPage(p => p - 1)}>← Prev</button>
              <button className="btn btn-ghost btn-sm" disabled={page >= data.totalPages} onClick={() => setPage(p => p + 1)}>Next →</button>
            </div>
          </div>
        </div>
      </div>

      {editItem && (
        <SOSEditModal item={editItem} onClose={() => setEditItem(null)} onSave={handleUpdate} />
      )}

      {deleteTarget && (
        <ConfirmModal
          title="Delete Incident"
          message="Permanently delete SOS record from"
          target={deleteTarget.user_phone}
          onCancel={() => setDelete(null)}
          onConfirm={handleDelete}
        />
      )}
    </div>
  )
}

export function StatusBadge({ status }) {
  const map = {
    active: { cls: 'badge-active', label: 'ACTIVE SOS' },
    resolved: { cls: 'badge-resolved', label: 'RESOLVED' },
    false_alarm: { cls: 'badge-false', label: 'FALSE ALARM' },
  }
  const { cls, label } = map[status] || { cls: '', label: status?.toUpperCase() }
  return (
    <span className={`badge ${cls}`} style={{ letterSpacing: '0.05em', fontWeight: 800, padding: '6px 12px' }}>
      {status === 'active' && <span className="badge-dot" style={{ background: '#fff', marginRight: 8, animation: 'pulse 1.5s infinite' }} />}
      {label}
    </span>
  )
}

function SOSEditModal({ item, onClose, onSave }) {
  const [form, setForm] = useState({ status: item.status, message: item.message || '' })
  const set = (k, v) => setForm(f => ({ ...f, [k]: v }))

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal" style={{ maxWidth: 440 }}>
        <div className="modal-header">
          <p className="modal-title">Edit Incident</p>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>
        <div className="modal-form">
          <div className="input-group">
            <label className="input-label">Status</label>
            <select className="select" value={form.status} onChange={e => set('status', e.target.value)}>
              <option value="active">Active</option>
              <option value="resolved">Resolved</option>
              <option value="false_alarm">False Alarm</option>
            </select>
          </div>
          <div className="input-group">
            <label className="input-label">Message / Notes</label>
            <input className="input" value={form.message} onChange={e => set('message', e.target.value)} placeholder="Admin notes…" />
          </div>
          <div className="modal-actions">
            <button className="btn btn-ghost" onClick={onClose}>Cancel</button>
            <button className="btn btn-primary" onClick={() => onSave(form)}>Save Changes</button>
          </div>
        </div>
      </div>
    </div>
  )
}
