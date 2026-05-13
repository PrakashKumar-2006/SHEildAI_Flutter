import { useState } from 'react'
import toast from 'react-hot-toast'
import { Topbar } from './Dashboard'
import { LuKey, LuLogOut, LuCheck } from 'react-icons/lu'

export default function ProfilePage() {
  const [profile, setProfile] = useState({
    name: 'Admin Maurya',
    email: 'admin@sheildai.system',
    phone: '+91 98765 43210',
    role: 'Global System Administrator',
  })

  const [saving, setSaving] = useState(false)
  const [passForm, setPassForm] = useState({ current: '', newPass: '', confirm: '' })

  const handleSaveProfile = (e) => {
    e.preventDefault()
    setSaving(true)
    setTimeout(() => {
      setSaving(false)
      toast.success('Admin profile preferences updated successfully')
    }, 500)
  }

  const handlePasswordChange = (e) => {
    e.preventDefault()
    if (passForm.newPass !== passForm.confirm) {
      toast.error('New passwords do not match')
      return
    }
    if (passForm.newPass.length < 8) {
      toast.error('Password must be at least 8 characters long')
      return
    }
    toast.success('Security credential updated successfully')
    setPassForm({ current: '', newPass: '', confirm: '' })
  }

  return (
    <>
      <Topbar title="Administrator Profile" sub="Manage profile details & account security" />
      <div className="page-content" style={{ maxWidth: 1000 }}>
        
        {/* Profile Hero Card */}
        <div className="card" style={{ padding: 0, overflow: 'hidden', marginBottom: 32 }}>
          <div style={{
            height: 120,
            background: 'linear-gradient(135deg, #1e293b 0%, #0f172a 100%)',
            display: 'flex',
            alignItems: 'center',
            padding: '0 32px'
          }}>
            <span className="badge" style={{ background: 'rgba(255,255,255,0.1)', color: '#fff', border: '1px solid rgba(255,255,255,0.2)' }}>
              Primary System Owner
            </span>
          </div>

          <div style={{ padding: '0 32px 32px', position: 'relative' }}>
            <div style={{ display: 'flex', alignItems: 'flex-end', gap: 20, marginTop: -40 }}>
              <div style={{
                width: 88,
                height: 88,
                borderRadius: 'var(--radius-md)',
                background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
                border: '4px solid #ffffff',
                boxShadow: 'var(--shadow-hover)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#ffffff',
                fontSize: 32,
                fontWeight: 800,
              }}>
                A
              </div>
              <div style={{ paddingBottom: 4 }}>
                <h2 style={{ fontSize: 22, fontWeight: 800, color: 'var(--text-primary)' }}>{profile.name}</h2>
                <p style={{ fontSize: 13, color: 'var(--text-secondary)', fontWeight: 600 }}>{profile.role}</p>
              </div>
            </div>
          </div>
        </div>

        {/* Clean Side-by-Side Forms */}
        <div className="grid-2" style={{ gap: 32 }}>
          
          {/* Account Profile Form */}
          <div className="card">
            <div className="card-header">
              <div>
                <p className="card-title">Profile Information</p>
                <p className="card-subtitle">Update your personal admin details</p>
              </div>
            </div>

            <form onSubmit={handleSaveProfile} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              <div className="input-group">
                <label className="input-label">Display Name</label>
                <input
                  className="input"
                  value={profile.name}
                  onChange={e => setProfile({...profile, name: e.target.value})}
                  required
                />
              </div>

              <div className="input-group">
                <label className="input-label">Primary Email</label>
                <input
                  type="email"
                  className="input"
                  value={profile.email}
                  onChange={e => setProfile({...profile, email: e.target.value})}
                  required
                />
              </div>

              <div className="input-group">
                <label className="input-label">Contact Phone</label>
                <input
                  className="input"
                  value={profile.phone}
                  onChange={e => setProfile({...profile, phone: e.target.value})}
                  required
                />
              </div>

              <button type="submit" className="btn btn-primary" style={{ marginTop: 8 }} disabled={saving}>
                {saving ? 'Saving…' : 'Update Profile'}
              </button>
            </form>
          </div>

          {/* Password & Security Actions */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
            <div className="card">
              <div className="card-header">
                <div>
                  <p className="card-title">Change Password</p>
                  <p className="card-subtitle">Ensure your account uses a secure key</p>
                </div>
              </div>

              <form onSubmit={handlePasswordChange} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div className="input-group">
                  <label className="input-label">Current Password</label>
                  <input
                    type="password"
                    className="input"
                    placeholder="••••••••••••"
                    value={passForm.current}
                    onChange={e => setPassForm({...passForm, current: e.target.value})}
                    required
                  />
                </div>
                <div className="input-group">
                  <label className="input-label">New Password</label>
                  <input
                    type="password"
                    className="input"
                    placeholder="Minimum 8 characters"
                    value={passForm.newPass}
                    onChange={e => setPassForm({...passForm, newPass: e.target.value})}
                    required
                  />
                </div>
                <div className="input-group">
                  <label className="input-label">Confirm Password</label>
                  <input
                    type="password"
                    className="input"
                    placeholder="Verify new password"
                    value={passForm.confirm}
                    onChange={e => setPassForm({...passForm, confirm: e.target.value})}
                    required
                  />
                </div>
                <button type="submit" className="btn btn-ghost" style={{ marginTop: 8, alignSelf: 'flex-start' }}>
                  <LuKey size={16} /> Update Password
                </button>
              </form>
            </div>

            {/* Logout Trigger */}
            <div className="card" style={{ padding: '20px 24px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div>
                <p style={{ fontSize: 14, fontWeight: 700, color: 'var(--text-primary)' }}>Account Access</p>
                <p style={{ fontSize: 12, color: 'var(--text-secondary)' }}>Sign out from this terminal</p>
              </div>
              <button
                className="btn btn-danger btn-sm"
                onClick={() => toast.success('Signed out securely')}
              >
                <LuLogOut size={14} /> Sign Out
              </button>
            </div>
          </div>

        </div>

      </div>
    </>
  )
}
