import { useState, useEffect } from 'react'
import toast from 'react-hot-toast'
import { Topbar } from '../components/Topbar'
import { LuKey, LuLogOut, LuCheck, LuShieldCheck, LuUser, LuMail, LuPhone, LuShieldAlert } from 'react-icons/lu'

export default function ProfilePage({ user, setUser, onLogout }) {
  // Safety check for user object
  const safeUser = user || { name: 'Admin', role: 'Administrator' }

  const [profile, setProfile] = useState({
    name: safeUser.name || '',
    email: safeUser.email || 'admin@sheildai.io',
    phone: safeUser.phone || '+91 98765 43210',
    role: safeUser.role || 'System Admin',
  })

  const [saving, setSaving] = useState(false)
  const [passForm, setPassForm] = useState({ current: '', newPass: '', confirm: '' })

  useEffect(() => {
    if (user) {
      setProfile({
        name: user.name || '',
        email: user.email || 'admin@sheildai.io',
        phone: user.phone || '+91 98765 43210',
        role: user.role || 'System Admin',
      })
    }
  }, [user])

  const handleSaveProfile = (e) => {
    e.preventDefault()
    setSaving(true)
    
    setTimeout(() => {
      const updatedUser = { ...safeUser, ...profile }
      setUser(updatedUser)
      localStorage.setItem('admin_user', JSON.stringify(updatedUser))
      setSaving(false)
      toast.success('Administrative profile synchronized successfully')
    }, 800)
  }

  const handlePasswordChange = (e) => {
    e.preventDefault()
    if (passForm.newPass !== passForm.confirm) {
      toast.error('Security keys do not match')
      return
    }
    if (passForm.newPass.length < 8) {
      toast.error('Security key must be at least 8 characters')
      return
    }
    
    setSaving(true)
    setTimeout(() => {
      toast.success('Security credentials rotated successfully')
      setPassForm({ current: '', newPass: '', confirm: '' })
      setSaving(false)
    }, 1000)
  }

  return (
    <div className="page-main-container">
      <Topbar title="Identity Management" sub="Secure governance & account authorization" />
      
      <div className="page-content" style={{ maxWidth: 1200 }}>
        
        {/* Identity Hero */}
        <div className="card" style={{ 
          padding: 0, overflow: 'hidden', border: 'none',
          background: 'linear-gradient(135deg, #0f172a 0%, #1e293b 100%)',
          boxShadow: 'var(--shadow-lg)',
          position: 'relative',
          marginBottom: 32
        }}>
          <div style={{ padding: '40px 48px', display: 'flex', alignItems: 'center', gap: 32, position: 'relative', zIndex: 1 }}>
            <div style={{ 
              width: 100, height: 100, borderRadius: 24, 
              background: 'linear-gradient(135deg, #3b82f6 0%, #2563eb 100%)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: '#fff', fontSize: 42, fontWeight: 900,
              boxShadow: '0 10px 25px rgba(37, 99, 235, 0.3)',
              border: '2px solid rgba(255,255,255,0.1)'
            }}>
              {profile.name ? profile.name.charAt(0) : 'A'}
            </div>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 8 }}>
                <h2 style={{ fontSize: 32, fontWeight: 900, color: '#fff', margin: 0, letterSpacing: '-0.03em' }}>{profile.name}</h2>
                <span style={{ background: 'rgba(16, 185, 129, 0.1)', color: '#10b981', padding: '4px 12px', borderRadius: 20, fontSize: 10, fontWeight: 800, border: '1px solid rgba(16, 185, 129, 0.2)' }}>SECURE ACCESS</span>
              </div>
              <p style={{ fontSize: 14, color: '#94a3b8', fontWeight: 600, margin: 0 }}>{profile.role}</p>
            </div>
          </div>
        </div>

        <div className="grid-2" style={{ gridTemplateColumns: '1.2fr 1fr', gap: 32 }}>
          
          {/* Main Info Form */}
          <div className="card">
            <div className="card-header" style={{ marginBottom: 32 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                <LuUser size={20} color="var(--brand-primary)" />
                <p className="card-title">Profile Parameters</p>
              </div>
            </div>

            <form onSubmit={handleSaveProfile} style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24 }}>
                <div className="input-group">
                  <label className="input-label">Administrative Alias</label>
                  <input className="input" value={profile.name} onChange={e => setProfile({...profile, name: e.target.value})} required />
                </div>
                <div className="input-group">
                  <label className="input-label">Identity Email</label>
                  <input className="input" type="email" value={profile.email} onChange={e => setProfile({...profile, email: e.target.value})} required />
                </div>
                <div className="input-group">
                  <label className="input-label">Contact Link</label>
                  <input className="input" value={profile.phone} onChange={e => setProfile({...profile, phone: e.target.value})} required />
                </div>
                <div className="input-group">
                  <label className="input-label">Authorized Role</label>
                  <input className="input" value={profile.role} readOnly style={{ opacity: 0.6, cursor: 'not-allowed' }} />
                </div>
              </div>

              <div style={{ borderTop: '1px solid var(--border)', paddingTop: 24, marginTop: 8, display: 'flex', justifyContent: 'flex-end' }}>
                <button type="submit" className="btn btn-primary" style={{ padding: '12px 32px', borderRadius: 12, fontWeight: 800 }} disabled={saving}>
                  {saving ? 'Syncing...' : 'Commit Changes'}
                </button>
              </div>
            </form>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 32 }}>
            
            {/* Password Change */}
            <div className="card">
              <div className="card-header" style={{ marginBottom: 24 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <LuShieldAlert size={18} color="var(--brand-primary)" />
                  <p className="card-title">Credential Governance</p>
                </div>
              </div>

              <form onSubmit={handlePasswordChange} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div className="input-group">
                  <label className="input-label">Current Security Key</label>
                  <input className="input" type="password" placeholder="••••••••" value={passForm.current} onChange={e => setPassForm({...passForm, current: e.target.value})} required />
                </div>
                <div className="input-group">
                  <label className="input-label">New Security Key</label>
                  <input className="input" type="password" placeholder="Min 8 characters" value={passForm.newPass} onChange={e => setPassForm({...passForm, newPass: e.target.value})} required />
                </div>
                <div className="input-group">
                  <label className="input-label">Verify New Key</label>
                  <input className="input" type="password" placeholder="Verify new key" value={passForm.confirm} onChange={e => setPassForm({...passForm, confirm: e.target.value})} required />
                </div>
                <button type="submit" className="btn btn-ghost" style={{ marginTop: 8, gap: 10 }} disabled={saving}>
                  <LuKey size={16} /> Update Security Credentials
                </button>
              </form>
            </div>

            {/* Account Management */}
            <div className="card" style={{ padding: '24px 32px' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <div>
                  <p style={{ fontSize: 15, fontWeight: 800, color: 'var(--text-primary)', margin: 0 }}>Terminal Access</p>
                  <p style={{ fontSize: 12, color: 'var(--text-secondary)', margin: '4px 0 0' }}>Close administrative session</p>
                </div>
                <button onClick={onLogout} className="btn btn-danger" style={{ padding: '10px 20px', borderRadius: 12, fontWeight: 800 }}>
                  <LuLogOut size={16} /> Sign Out
                </button>
              </div>
            </div>

          </div>

        </div>

      </div>
    </div>
  )
}
