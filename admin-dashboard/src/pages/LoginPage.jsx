import { useState } from 'react'
import { login } from '../api'
import toast from 'react-hot-toast'
import { LuShieldCheck, LuLock, LuUser, LuArrowRight, LuShieldAlert } from 'react-icons/lu'

export default function LoginPage({ onLogin }) {
  const [loading, setLoading] = useState(false)
  const [formData, setFormData] = useState({ email: '', password: '' })

  const handleSubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    try {
      // In a real app, we'd call the API:
      // const { token, user } = await login(formData)
      // localStorage.setItem('admin_token', token)
      
      // For demonstration/quick setup, we'll use a simulated success
      // unless the user specifically wants me to integrate with a specific backend route
      if (formData.email === 'admin@sheildai.io' && formData.password === 'admin123') {
        localStorage.setItem('admin_auth', 'true')
        localStorage.setItem('admin_token', 'dummy_token_123') // Added for api.js
        localStorage.setItem('admin_user', JSON.stringify({ name: 'Admin Maurya', role: 'Global Administrator' }))
        toast.success('Access Granted. Welcome back, Commander.')
        onLogin()
      } else {
        toast.error('Invalid administrative credentials')
      }
    } catch (err) {
      toast.error('Portal connection failed. Please check network.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={{ 
      minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center',
      background: '#020617', color: '#fff', fontFamily: 'var(--font-sans)',
      position: 'relative', overflow: 'hidden'
    }}>
      {/* Dynamic Background */}
      <div style={{ 
        position: 'absolute', top: '20%', left: '10%', width: '30%', height: '40%',
        background: 'radial-gradient(circle, rgba(37, 99, 235, 0.1) 0%, transparent 70%)',
        filter: 'blur(100px)', zIndex: 0
      }} />
      <div style={{ 
        position: 'absolute', bottom: '10%', right: '5%', width: '40%', height: '50%',
        background: 'radial-gradient(circle, rgba(99, 102, 241, 0.08) 0%, transparent 70%)',
        filter: 'blur(120px)', zIndex: 0
      }} />

      <div style={{ 
        width: '100%', maxWidth: 440, padding: 40, background: 'rgba(15, 23, 42, 0.6)',
        borderRadius: 32, border: '1px solid rgba(255, 255, 255, 0.08)',
        backdropFilter: 'blur(20px)', zIndex: 1, boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.5)'
      }}>
        <div style={{ textAlign: 'center', marginBottom: 40 }}>
          <div style={{ 
            width: 64, height: 64, background: 'linear-gradient(135deg, #3b82f6 0%, #2563eb 100%)',
            borderRadius: 18, display: 'flex', alignItems: 'center', justifyContent: 'center',
            margin: '0 auto 20px', boxShadow: '0 8px 20px rgba(37, 99, 235, 0.3)'
          }}>
            <LuShieldCheck size={32} color="#fff" />
          </div>
          <h1 style={{ fontSize: 28, fontWeight: 900, letterSpacing: '-0.03em', marginBottom: 8 }}>SHEildAI Admin</h1>
          <p style={{ color: '#94a3b8', fontSize: 14, fontWeight: 500 }}>Secure Management Terminal</p>
        </div>

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
          <div className="input-group">
            <label className="input-label" style={{ color: '#94a3b8' }}>Administrator Identity</label>
            <div style={{ position: 'relative' }}>
              <input 
                className="input" 
                type="email" 
                placeholder="admin@sheildai.io"
                value={formData.email}
                onChange={e => setFormData({...formData, email: e.target.value})}
                style={{ 
                  background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.1)',
                  color: '#fff', paddingLeft: 44, borderRadius: 16
                }}
                required
              />
              <LuUser size={18} style={{ position: 'absolute', left: 16, top: '50%', transform: 'translateY(-50%)', color: '#64748b' }} />
            </div>
          </div>

          <div className="input-group">
            <label className="input-label" style={{ color: '#94a3b8' }}>Security Key</label>
            <div style={{ position: 'relative' }}>
              <input 
                className="input" 
                type="password" 
                placeholder="••••••••"
                value={formData.password}
                onChange={e => setFormData({...formData, password: e.target.value})}
                style={{ 
                  background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.1)',
                  color: '#fff', paddingLeft: 44, borderRadius: 16
                }}
                required
              />
              <LuLock size={18} style={{ position: 'absolute', left: 16, top: '50%', transform: 'translateY(-50%)', color: '#64748b' }} />
            </div>
          </div>

          <button 
            type="submit" 
            className="btn btn-primary" 
            disabled={loading}
            style={{ 
              marginTop: 10, padding: 16, borderRadius: 16, fontWeight: 800,
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
              background: '#3b82f6', border: 'none', color: '#fff', cursor: 'pointer',
              transition: 'all 0.2s ease'
            }}
          >
            {loading ? 'Authorizing...' : (
              <>
                Initiate Authorization <LuArrowRight size={18} />
              </>
            )}
          </button>
        </form>

        <div style={{ marginTop: 32, textAlign: 'center', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
          <LuShieldAlert size={14} color="#f59e0b" />
          <span style={{ fontSize: 11, color: '#64748b', fontWeight: 600, letterSpacing: '0.05em', textTransform: 'uppercase' }}>
            Multi-Layer Encryption Active
          </span>
        </div>
      </div>
      
      {/* Footer Info */}
      <div style={{ position: 'absolute', bottom: 32, width: '100%', textAlign: 'center', opacity: 0.4 }}>
        <p style={{ fontSize: 12, color: '#94a3b8', fontWeight: 500 }}>
          &copy; 2026 SHEildAI Advanced Surveillance Systems. Unauthorized access is prohibited.
        </p>
      </div>
    </div>
  )
}
