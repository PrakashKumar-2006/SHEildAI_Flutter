import { useState, useEffect, useCallback } from 'react'
import toast from 'react-hot-toast'
import { fetchContacts, deleteContact } from '../api'
import { Topbar } from './Dashboard'
import { ConfirmModal } from './UsersPage'
import { format } from 'date-fns'
import { LuSearch, LuPhone, LuTrash2, LuStar } from 'react-icons/lu'

export default function ContactsPage() {
  const [data, setData]           = useState({ contacts: [], total: 0, totalPages: 1 })
  const [page, setPage]           = useState(1)
  const [search, setSearch]       = useState('')
  const [loading, setLoading]     = useState(true)
  const [deleteTarget, setDelete] = useState(null)

  const load = useCallback(() => {
    setLoading(true)
    fetchContacts({ page, limit: 15, search })
      .then(setData)
      .catch(e => toast.error(e.response?.data?.error || 'Failed to load contacts'))
      .finally(() => setLoading(false))
  }, [page, search])

  useEffect(() => { load() }, [load])

  const handleDelete = async () => {
    try {
      await deleteContact(deleteTarget._id)
      toast.success('Contact deleted')
      setDelete(null)
      load()
    } catch (e) {
      toast.error(e.response?.data?.error || 'Delete failed')
    }
  }

  return (
    <>
      <Topbar title="Emergency Contacts" sub={`${data.total} contacts across all users`} />
      <div className="page-content">
        <div className="card">
          <div className="card-header">
            <p className="card-title">All Emergency Contacts</p>
          </div>

          <div className="filter-bar">
            <div className="search-bar" style={{ flex: 1, maxWidth: 360 }}>
              <span className="search-icon"><LuSearch size={16} /></span>
              <input
                placeholder="Search by name or user phone…"
                value={search}
                onChange={e => { setSearch(e.target.value); setPage(1) }}
              />
            </div>
          </div>

          {loading ? (
            <div className="loading-spinner"><div className="spinner" /></div>
          ) : data.contacts.length === 0 ? (
            <div className="empty-state">
              <p className="empty-icon"><LuPhone size={32} color="#9ca3af" /></p>
              <p>No contacts found</p>
            </div>
          ) : (
            <div className="table-wrapper">
              <table>
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Contact Phone</th>
                    <th>Relationship</th>
                    <th>Primary?</th>
                    <th>Owner (User Phone)</th>
                    <th>Added On</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {data.contacts.map(c => (
                    <tr key={c._id}>
                      <td style={{ fontWeight: 600 }}>{c.name}</td>
                      <td className="td-mono">{c.phone}</td>
                      <td className="td-muted">{c.relationship || 'Other'}</td>
                      <td>
                        {c.isPrimary
                          ? <span className="badge badge-resolved" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}><LuStar size={12} fill="currentColor" /> Primary</span>
                          : <span style={{ color: 'var(--text-muted)', fontSize: 12 }}>No</span>}
                      </td>
                      <td className="td-mono" style={{ fontSize: 11 }}>{c.user_phone}</td>
                      <td className="td-muted" style={{ fontSize: 11 }}>
                        {c.createdAt ? format(new Date(c.createdAt), 'MMM d, yyyy') : '—'}
                      </td>
                      <td>
                        <button className="btn btn-danger btn-sm" onClick={() => setDelete(c)} style={{ display: 'flex', alignItems: 'center', gap: 4 }}><LuTrash2 size={16} /> Delete</button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          <div className="pagination">
            <span>Showing {Math.min(((page-1)*15)+1, data.total)}–{Math.min(page*15, data.total)} of {data.total}</span>
            <div className="pagination-controls">
              <button className="btn btn-ghost btn-sm" disabled={page <= 1} onClick={() => setPage(p => p - 1)}>← Prev</button>
              <button className="btn btn-ghost btn-sm" disabled={page >= data.totalPages} onClick={() => setPage(p => p + 1)}>Next →</button>
            </div>
          </div>
        </div>
      </div>

      {deleteTarget && (
        <ConfirmModal
          title="Remove Contact"
          message="Remove emergency contact"
          target={`${deleteTarget.name} (${deleteTarget.phone})`}
          onCancel={() => setDelete(null)}
          onConfirm={handleDelete}
        />
      )}
    </>
  )
}
