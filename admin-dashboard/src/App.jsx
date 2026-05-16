import { BrowserRouter, Routes, Route, NavLink, Navigate, useLocation } from 'react-router-dom'
import { Toaster, toast } from 'react-hot-toast'
import { useState, useEffect } from 'react'
import { io } from 'socket.io-client'
import { fetchStats, sendBroadcast } from './api'
import {
  LuLayoutDashboard, LuTrendingUp, LuMap, LuTriangleAlert,
  LuUsers, LuPhone, LuShieldCheck, LuMessageSquare,
  LuMegaphone, LuMoon, LuSun, LuLogOut, LuX, LuChevronRight
} from 'react-icons/lu'

import Dashboard from './pages/Dashboard'
import UsersPage from './pages/UsersPage'
import SOSPage from './pages/SOSPage'
import HeatmapPage from './pages/HeatmapPage'
import AnalyticsPage from './pages/AnalyticsPage'
import ProfilePage from './pages/ProfilePage'
import CommunityReportsPage from './pages/CommunityReportsPage'
import ContactsPage from './pages/ContactsPage'
import LoginPage from './pages/LoginPage'

export default function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(!!localStorage.getItem('admin_auth'))
  const [user, setUser] = useState(() => {
    const saved = localStorage.getItem('admin_user')
    return saved ? JSON.parse(saved) : { name: 'Admin Maurya', role: 'Global Administrator' }
  })
  const [activeSOS, setActiveSOS] = useState(0)
  const [isDarkMode, setIsDarkMode] = useState(false)
  const [showBroadcast, setShowBroadcast] = useState(false)
  const [broadcastData, setBroadcastData] = useState({ title: '', message: '', severity: 'high' })

  useEffect(() => {
    if (!isAuthenticated) return
    const load = () => fetchStats().then(s => setActiveSOS(s.activeSOS || 0)).catch(() => { })
    load()
    const interval = setInterval(load, 30000)
    const socket = io(import.meta.env.VITE_API_BASE_URL || 'http://localhost:5000')
    socket.on('new_sos_alert', () => {
      toast.error(`New SOS Alert!`, { icon: '🚨' })
      load()
    })
    return () => {
      clearInterval(interval)
      socket.disconnect()
    }
  }, [isAuthenticated])

  useEffect(() => {
    if (isDarkMode) document.body.classList.add('dark-mode')
    else document.body.classList.remove('dark-mode')
  }, [isDarkMode])

  const logout = () => {
    localStorage.removeItem('admin_auth')
    localStorage.removeItem('admin_token')
    localStorage.removeItem('admin_user')
    setIsAuthenticated(false)
    toast.success('Session Terminated')
  }

  const handleBroadcastSubmit = (e) => {
    e.preventDefault()
    sendBroadcast(broadcastData).then(() => {
      toast.success('Broadcast sent')
      setShowBroadcast(false)
      setBroadcastData({ title: '', message: '', severity: 'high' })
    }).catch(() => toast.error('Broadcast failed'))
  }

  return (
    <BrowserRouter>
      <Toaster
        position="top-right"
        toastOptions={{
          style: { background: 'var(--bg-surface)', color: 'var(--text-primary)', border: '1px solid var(--border)', borderRadius: '12px' }
        }}
      />

      {!isAuthenticated ? (
        <Routes>
          <Route path="*" element={<LoginPage onLogin={() => setIsAuthenticated(true)} />} />
        </Routes>
      ) : (
        <div className="layout">
          <Sidebar
            user={user}
            activeSOS={activeSOS}
            isDarkMode={isDarkMode}
            setIsDarkMode={setIsDarkMode}
            onShowBroadcast={() => setShowBroadcast(true)}
          />

          <div className="main">
            <Routes>
              <Route path="/" element={<Navigate to="/dashboard" replace />} />
              <Route path="/dashboard" element={<Dashboard />} />
              <Route path="/users" element={<UsersPage />} />
              <Route path="/sos" element={<SOSPage />} />
              <Route path="/community" element={<CommunityReportsPage />} />
              <Route path="/heatmap" element={<HeatmapPage />} />
              <Route path="/analytics" element={<AnalyticsPage />} />
              <Route path="/contacts" element={<ContactsPage />} />
              <Route path="/profile" element={<ProfilePage user={user} setUser={setUser} onLogout={logout} />} />
            </Routes>
          </div>

          {showBroadcast && (
            <div className="modal-overlay" style={{
              position: 'fixed', top: 0, left: 0, width: '100%', height: '100%',
              background: 'rgba(0,0,0,0.5)', backdropFilter: 'blur(8px)',
              display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 9999
            }} onClick={() => setShowBroadcast(false)}>
              <div className="modal" style={{ width: '100%', maxWidth: 500, background: 'var(--bg-surface)', borderRadius: 24, padding: 0, overflow: 'hidden' }} onClick={e => e.stopPropagation()}>
                <div className="modal-header" style={{ padding: '24px 32px', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <h3 className="modal-title" style={{ margin: 0, fontSize: 20, fontWeight: 800 }}>Emergency Broadcast</h3>
                  <button onClick={() => setShowBroadcast(false)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)' }}>
                    <LuX size={24} />
                  </button>
                </div>
                <form className="modal-form" style={{ padding: 32 }} onSubmit={handleBroadcastSubmit}>
                  <div className="input-group" style={{ marginBottom: 24 }}>
                    <label className="input-label" style={{ display: 'block', marginBottom: 8, fontSize: 13, fontWeight: 700, color: 'var(--text-secondary)' }}>Severity Level</label>
                    <select className="input" style={{ width: '100%', padding: '12px', borderRadius: 12, border: '1px solid var(--border)', background: 'var(--bg-hover)' }} value={broadcastData.severity} onChange={e => setBroadcastData({ ...broadcastData, severity: e.target.value })}>
                      <option value="high">🚨 Critical / SOS</option>
                      <option value="medium">⚠️ Warning</option>
                      <option value="low">ℹ️ Information</option>
                    </select>
                  </div>
                  <div className="input-group" style={{ marginBottom: 32 }}>
                    <label className="input-label" style={{ display: 'block', marginBottom: 8, fontSize: 13, fontWeight: 700, color: 'var(--text-secondary)' }}>Broadcast Content</label>
                    <textarea className="input" style={{ width: '100%', height: 120, padding: '12px', borderRadius: 12, border: '1px solid var(--border)', background: 'var(--bg-hover)', resize: 'none' }} value={broadcastData.message} onChange={e => setBroadcastData({ ...broadcastData, message: e.target.value })} placeholder="Message will be sent to all active users..." required />
                  </div>
                  <button type="submit" className="btn btn-primary" style={{ width: '100%', padding: '16px', borderRadius: 16, fontWeight: 800, background: '#ef4444', border: 'none', color: '#fff' }}>
                    Initiate Global Broadcast
                  </button>
                </form>
              </div>
            </div>
          )}
        </div>
      )}
    </BrowserRouter>
  )
}

function Sidebar({ user, activeSOS, isDarkMode, setIsDarkMode, onShowBroadcast }) {
  const links = [
    { to: '/dashboard', icon: <LuLayoutDashboard />, label: 'Dashboard' },
    { to: '/analytics', icon: <LuTrendingUp />, label: 'Analytics' },
    { to: '/heatmap', icon: <LuMap />, label: 'Safety Zones' },
    { to: '/sos', icon: <LuTriangleAlert />, label: 'SOS Alerts', badge: activeSOS > 0 ? activeSOS : null },
    { to: '/community', icon: <LuMessageSquare />, label: 'Community' },
    { to: '/users', icon: <LuUsers />, label: 'Users' },
  ]

  return (
    <nav className="sidebar" style={{ width: 280 }}>
      <div className="sidebar-logo" style={{ padding: '32px 24px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 36, height: 36, borderRadius: 10, background: 'linear-gradient(135deg, #3b82f6, #2563eb)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', boxShadow: '0 4px 12px rgba(37,99,235,0.2)' }}>
            <LuShieldCheck size={20} />
          </div>
          <h1 style={{ fontSize: 19, fontWeight: 900, color: 'var(--text-primary)', margin: 0, letterSpacing: '-0.02em' }}>SHEildAI</h1>
        </div>
        <button onClick={() => setIsDarkMode(!isDarkMode)} style={{ background: 'var(--bg-hover)', border: '1px solid var(--border)', width: 36, height: 36, borderRadius: 10, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', color: 'var(--text-primary)' }}>
          {isDarkMode ? <LuSun size={18} /> : <LuMoon size={18} />}
        </button>
      </div>

      <div className="sidebar-nav" style={{ padding: '0 12px' }}>
        {links.map((l, i) => (
          <NavLink key={l.to} to={l.to} className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`} style={{ marginBottom: 4 }}>
            {l.icon} {l.label}
            {l.badge && <span className="badge pulse" style={{ marginLeft: 'auto', background: '#ef4444', color: '#fff', fontSize: 10, padding: '2px 8px' }}>{l.badge}</span>}
          </NavLink>
        ))}

        <div style={{ padding: '16px 12px 0' }}>
          <button onClick={onShowBroadcast} className="btn btn-primary" style={{
            width: '100%', borderRadius: 14, gap: 10, background: '#ef4444', height: 48,
            border: 'none', boxShadow: '0 4px 12px rgba(239, 68, 68, 0.2)',
            display: 'flex', alignItems: 'center', justifyContent: 'flex-start', padding: '0 16px',
            fontSize: 14, fontWeight: 700
          }}>
            <LuMegaphone size={18} /> Global Broadcast
          </button>
        </div>
      </div>

      <div className="sidebar-footer" style={{ marginTop: 'auto', padding: '24px 20px', borderTop: '1px solid var(--border)' }}>
        <NavLink to="/profile" style={{ textDecoration: 'none' }}>
          <div className="sidebar-user" style={{
            display: 'flex', alignItems: 'center', gap: 12, padding: '12px',
            borderRadius: 16, background: 'var(--bg-hover)', border: '1px solid var(--border)',
            transition: 'all 0.2s ease'
          }}>
            <div className="sidebar-avatar" style={{ width: 42, height: 42, borderRadius: '50%', background: 'linear-gradient(135deg, #3b82f6, #6366f1)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 18, fontWeight: 800, border: '2px solid var(--bg-surface)' }}>
              {user.name.charAt(0)}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <p style={{ fontSize: 14, fontWeight: 800, color: 'var(--text-primary)', margin: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{user.name}</p>
              <p style={{ fontSize: 11, color: 'var(--text-secondary)', margin: 0, fontWeight: 600 }}>{user.role}</p>
            </div>
            <LuChevronRight size={16} color="var(--text-muted)" />
          </div>
        </NavLink>
      </div>
    </nav>
  )
}
