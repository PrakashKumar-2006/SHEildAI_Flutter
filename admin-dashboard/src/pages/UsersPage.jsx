import { useState, useEffect, useCallback } from 'react'
import toast from 'react-hot-toast'
import { fetchUsers, updateUser, deleteUser } from '../api'
import { Topbar } from '../components/Topbar'
import { format } from 'date-fns'
import { LuSearch, LuUsers, LuPen, LuTrash2, LuTriangleAlert } from 'react-icons/lu'

export default function UsersPage() {
  const [data, setData] = useState({ users: [], total: 0, totalPages: 1 })
  const [page, setPage] = useState(1)
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [editUser, setEditUser] = useState(null)
  const [deleteTarget, setDeleteTarget] = useState(null)

  const load = useCallback(() => {
    setLoading(true)
    fetchUsers({ page, limit: 15, search })
      .then(setData)
      .catch(e => toast.error(e.response?.data?.error || 'Failed to load users'))
      .finally(() => setLoading(false))
  }, [page, search])

  useEffect(() => { load() }, [load])

  const handleDelete = async () => {
    try {
      await deleteUser(deleteTarget._id)
      toast.success('User deleted successfully')
      setDeleteTarget(null)
      load()
    } catch (e) {
      toast.error(e.response?.data?.error || 'Delete failed')
    }
  }

  const handleUpdate = async (form) => {
    try {
      await updateUser(editUser._id, form)
      toast.success('User updated')
      setEditUser(null)
      load()
    } catch (e) {
      toast.error(e.response?.data?.error || 'Update failed')
    }
  }

  return (
    <div className="page-main-container">
      <Topbar title="Users" sub={`${data.total} registered users`} />
      <div className="page-content">
        <div className="card">
          <div className="card-header">
            <p className="card-title">All Users</p>
          </div>

          <div className="filter-bar">
            <div className="search-bar" style={{ flex: 1, maxWidth: 360 }}>
              <span className="search-icon"><LuSearch size={16} /></span>
              <input
                placeholder="Search by name, phone, email…"
                value={search}
                onChange={e => { setSearch(e.target.value); setPage(1) }}
              />
            </div>
          </div>

          {loading ? (
            <div className="loading-spinner"><div className="spinner" /></div>
          ) : data.users.length === 0 ? (
            <div className="empty-state">
              <p className="empty-icon"><LuUsers size={32} color="#9ca3af" /></p>
              <p>No users found</p>
            </div>
          ) : (
            <div className="table-wrapper">
              <table>
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Phone</th>
                    <th>Email</th>
                    <th>Last Seen</th>
                    <th>Location</th>
                    <th>Joined</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {data.users.map(u => {
                    const isEmailInPhone = u.phone?.includes('@');
                    const displayPhone = isEmailInPhone ? '—' : (u.phone || '—');
                    const displayEmail = u.email || (isEmailInPhone ? u.phone : '—');

                    return (
                      <tr key={u._id}>
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                            <div className="sidebar-avatar" style={{ width: 32, height: 32, fontSize: 13 }}>
                              {(u.name || 'U').charAt(0).toUpperCase()}
                            </div>
                            <span style={{ fontWeight: 700, color: 'var(--text-primary)' }}>{u.name || 'Anonymous User'}</span>
                          </div>
                        </td>
                        <td className="td-mono" style={{ color: 'var(--brand-secondary)', fontWeight: 600 }}>{displayPhone}</td>
                        <td className="td-muted" style={{ fontWeight: 500 }}>{displayEmail}</td>
                        <td className="td-muted" style={{ fontSize: 12 }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                            <div style={{ width: 6, height: 6, borderRadius: '50%', background: u.last_seen ? '#10b981' : '#94a3b8' }} />
                            {u.last_seen ? format(new Date(u.last_seen), 'MMM d, HH:mm') : 'Never'}
                          </div>
                        </td>
                        <td className="td-mono" style={{ fontSize: 11, color: 'var(--text-secondary)' }}>
                          {u.last_lat ? `${u.last_lat.toFixed(4)}, ${u.last_lon?.toFixed(4)}` : 'No Location'}
                        </td>
                        <td className="td-muted" style={{ fontSize: 12 }}>
                          {u.createdAt ? format(new Date(u.createdAt), 'MMM d, yyyy') : '—'}
                        </td>
                        <td>
                          <div className="action-btns">
                            <button className="btn btn-ghost btn-sm" style={{ padding: '6px 10px' }} onClick={() => setEditUser(u)}>
                              <LuPen size={14} />
                            </button>
                            <button className="btn btn-danger btn-sm" style={{ padding: '6px 10px', background: 'rgba(239, 68, 68, 0.1)', color: '#ef4444', border: 'none' }} onClick={() => setDeleteTarget(u)}>
                              <LuTrash2 size={14} />
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
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

      {/* Edit Modal */}
      {editUser && (
        <UserEditModal user={editUser} onClose={() => setEditUser(null)} onSave={handleUpdate} />
      )}

      {/* Delete Confirm */}
      {deleteTarget && (
        <ConfirmModal
          title="Delete User"
          message={`Are you sure you want to delete`}
          target={deleteTarget.name || deleteTarget.phone}
          warning="This will also remove all their SOS records and contacts."
          onCancel={() => setDeleteTarget(null)}
          onConfirm={handleDelete}
        />
      )}
    </div>
  )
}

function UserEditModal({ user, onClose, onSave }) {
  const [form, setForm] = useState({ name: user.name || '', email: user.email || '', phone: user.phone || '' })
  const set = (k, v) => setForm(f => ({ ...f, [k]: v }))

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal">
        <div className="modal-header">
          <p className="modal-title">Edit User</p>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>
        <div className="modal-form">
          <div className="input-group">
            <label className="input-label">Name</label>
            <input className="input" value={form.name} onChange={e => set('name', e.target.value)} />
          </div>
          <div className="input-group">
            <label className="input-label">Email</label>
            <input className="input" value={form.email} onChange={e => set('email', e.target.value)} />
          </div>
          <div className="input-group">
            <label className="input-label">Phone</label>
            <input className="input" value={form.phone} onChange={e => set('phone', e.target.value)} />
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

export function ConfirmModal({ title, message, target, warning, onCancel, onConfirm }) {
  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onCancel()}>
      <div className="modal" style={{ maxWidth: 420 }}>
        <div className="modal-header">
          <p className="modal-title">{title}</p>
          <button className="modal-close" onClick={onCancel}>✕</button>
        </div>
        <div className="confirm-dialog">
          <p>{message} <span className="confirm-target">"{target}"</span>?</p>
          {warning && <p style={{ color: 'var(--status-active)', fontSize: 12, marginTop: 8, display: 'flex', alignItems: 'center', gap: 4 }}><LuTriangleAlert size={14} /> {warning}</p>}
        </div>
        <div className="modal-actions" style={{ marginTop: 24 }}>
          <button className="btn btn-ghost" onClick={onCancel}>Cancel</button>
          <button className="btn btn-danger" onClick={onConfirm}>Yes, Delete</button>
        </div>
      </div>
    </div>
  )
}
