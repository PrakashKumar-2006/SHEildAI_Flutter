import { useState, useEffect, useCallback } from 'react'
import toast from 'react-hot-toast'
import { fetchSOS, updateSOS, deleteSOS } from '../api'
import { Topbar } from './Dashboard'
import { ConfirmModal } from './UsersPage'
import { format } from 'date-fns'
import { LuSearch, LuTriangleAlert, LuCheck, LuOctagonAlert, LuPen, LuTrash2 } from 'react-icons/lu'

const STATUS_OPTIONS = ['', 'active', 'resolved', 'false_alarm']

export default function SOSPage() {
  const [data, setData]             = useState({ sos: [], total: 0, totalPages: 1 })
  const [page, setPage]             = useState(1)
  const [search, setSearch]         = useState('')
  const [statusFilter, setStatus]   = useState('')
  const [loading, setLoading]       = useState(true)
  const [editItem, setEditItem]     = useState(null)
  const [deleteTarget, setDelete]   = useState(null)

  const load = useCallback(() => {
    setLoading(true)
    fetchSOS({ page, limit: 15, status: statusFilter, search })
      .then(setData)
      .catch(e => toast.error(e.response?.data?.error || 'Failed to load SOS data'))
      .finally(() => setLoading(false))
  }, [page, search, statusFilter])

  useEffect(() => { load() }, [load])

  // Auto-refresh active incidents every 20s
  useEffect(() => {
    const interval = setInterval(() => { load() }, 20000)
    return () => clearInterval(interval)
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

  return (
    <>
      <Topbar title="SOS Incidents" sub={`${data.total} total incidents`} />
      <div className="page-content">
        <div className="card">
          <div className="card-header">
            <p className="card-title">Incident Management</p>
          </div>

          <div className="filter-bar">
            <div className="search-bar" style={{ flex: 1, maxWidth: 320 }}>
              <span className="search-icon"><LuSearch size={16} /></span>
              <input
                placeholder="Search by phone…"
                value={search}
                onChange={e => { setSearch(e.target.value); setPage(1) }}
              />
            </div>
            <select
              className="select"
              style={{ width: 160 }}
              value={statusFilter}
              onChange={e => { setStatus(e.target.value); setPage(1) }}
            >
              <option value="">All Statuses</option>
              <option value="active">Active</option>
              <option value="resolved">Resolved</option>
              <option value="false_alarm">False Alarm</option>
            </select>
          </div>

          {loading ? (
            <div className="loading-spinner"><div className="spinner" /></div>
          ) : data.sos.length === 0 ? (
            <div className="empty-state">
              <p className="empty-icon"><LuTriangleAlert size={32} color="#9ca3af" /></p>
              <p>No incidents found</p>
            </div>
          ) : (
            <div className="table-wrapper">
              <table>
                <thead>
                  <tr>
                    <th>User Phone</th>
                    <th>Status</th>
                    <th>Message</th>
                    <th>Location</th>
                    <th>Triggered</th>
                    <th>Quick Action</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {data.sos.map(s => (
                    <tr key={s._id}>
                      <td className="td-mono">{s.user_phone}</td>
                      <td><StatusBadge status={s.status} /></td>
                      <td style={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {s.message || '—'}
                      </td>
                      <td className="td-mono" style={{ fontSize: 11 }}>
                        {s.location?.lat ? `${s.location.lat.toFixed(4)}, ${s.location.lon?.toFixed(4)}` : '—'}
                      </td>
                      <td className="td-muted" style={{ fontSize: 11, whiteSpace: 'nowrap' }}>
                        {s.createdAt ? format(new Date(s.createdAt), 'MMM d, HH:mm') : '—'}
                      </td>
                      <td>
                        <div className="action-btns">
                          {s.status !== 'resolved' && (
                            <button className="btn btn-sm" style={{ background: 'rgba(16,185,129,0.15)', color: '#10b981', border: '1px solid rgba(16,185,129,0.3)', fontSize: 11, display: 'flex', alignItems: 'center', gap: '4px' }} onClick={() => quickStatus(s._id, 'resolved')}>
                              <LuCheck size={14} /> Resolve
                            </button>
                          )}
                          {s.status !== 'false_alarm' && (
                            <button className="btn btn-sm" style={{ background: 'rgba(245,158,11,0.15)', color: '#f59e0b', border: '1px solid rgba(245,158,11,0.3)', fontSize: 11, display: 'flex', alignItems: 'center', gap: '4px' }} onClick={() => quickStatus(s._id, 'false_alarm')}>
                              <LuOctagonAlert size={14} /> False
                            </button>
                          )}
                        </div>
                      </td>
                      <td>
                        <div className="action-btns">
                          <button className="btn btn-ghost btn-sm" onClick={() => setEditItem(s)}><LuPen size={16} /></button>
                          <button className="btn btn-danger btn-sm" onClick={() => setDelete(s)}><LuTrash2 size={16} /></button>
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
    </>
  )
}

export function StatusBadge({ status }) {
  const map = {
    active:     { cls: 'badge-active',   label: <><span style={{width:6, height:6, borderRadius:3, background:'currentColor'}}/> Active</> },
    resolved:   { cls: 'badge-resolved', label: <><LuCheck size={12}/> Resolved</> },
    false_alarm:{ cls: 'badge-false',    label: <><LuOctagonAlert size={12}/> False Alarm</> },
  }
  const { cls, label } = map[status] || { cls: '', label: status }
  return <span className={`badge ${cls}`}>{label}</span>
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
