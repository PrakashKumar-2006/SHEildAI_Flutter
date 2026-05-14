import { BrowserRouter, Routes, Route, NavLink, Navigate } from 'react-router-dom'
import { Toaster, toast } from 'react-hot-toast'
import { useState, useEffect } from 'react'
import { io } from 'socket.io-client'
import { fetchStats } from './api'
import { LuLayoutDashboard, LuTrendingUp, LuMap, LuTriangleAlert, LuUsers, LuPhone, LuShieldCheck, LuMessageSquare, LuMegaphone, LuMoon, LuSun } from 'react-icons/lu'
import { sendBroadcast } from './api'

import Dashboard  from './pages/Dashboard'
import UsersPage  from './pages/UsersPage'
import SOSPage    from './pages/SOSPage'
import HeatmapPage  from './pages/HeatmapPage'
import AnalyticsPage from './pages/AnalyticsPage'
import ProfilePage   from './pages/ProfilePage'
import CommunityReportsPage from './pages/CommunityReportsPage'

export default function App() {
  const [activeSOS, setActiveSOS] = useState(0)
  const [isDarkMode, setIsDarkMode] = useState(false)
  const [showBroadcast, setShowBroadcast] = useState(false)
  const [broadcastData, setBroadcastData] = useState({ title: '', message: '', severity: 'high' })

  useEffect(() => {
    const load = () => fetchStats().then(s => setActiveSOS(s.activeSOS || 0)).catch(() => {})
    load()
    const interval = setInterval(load, 30000)

    const socket = io(import.meta.env.VITE_API_BASE_URL || 'http://localhost:5000')
    
    socket.on('new_sos_alert', (data) => {
      toast.error(`New SOS Alert from ${data.user_phone || 'User'}!`, {
        icon: '🚨',
        style: {
          border: '1px solid #ef4444',
          background: '#fee2e2',
          color: '#b91c1c'
        }
      })
      load()
      window.dispatchEvent(new Event('realtime_update'))
    })

    socket.on('sos_status_updated', () => {
      load()
      window.dispatchEvent(new Event('realtime_update'))
    })

    return () => {
      clearInterval(interval)
      socket.disconnect()
    }
  }, [])

  useEffect(() => {
    if (isDarkMode) {
      document.body.classList.add('dark-mode')
    } else {
      document.body.classList.remove('dark-mode')
    }
  }, [isDarkMode])

  const handleBroadcastSubmit = (e) => {
    e.preventDefault()
    if (!broadcastData.message) return toast.error('Message is required')
    sendBroadcast(broadcastData).then(() => {
      toast.success('Global broadcast sent successfully')
      setShowBroadcast(false)
      setBroadcastData({ title: '', message: '', severity: 'high' })
    }).catch(() => toast.error('Failed to send broadcast'))
  }

  return (
    <BrowserRouter>
      <Toaster
        position="top-right"
        toastOptions={{
          style: {
            background: 'var(--bg-surface)',
            color: 'var(--text-primary)',
            border: '1px solid var(--border)',
            boxShadow: 'var(--shadow-hover)',
            borderRadius: 'var(--radius-sm)',
            fontFamily: 'var(--font-sans)',
            fontSize: '13px',
            fontWeight: 600,
          },
        }}
      />
      <div className="layout">
        <Sidebar 
          activeSOS={activeSOS} 
          isDarkMode={isDarkMode} 
          setIsDarkMode={setIsDarkMode} 
          setShowBroadcast={setShowBroadcast}
        />
        <div className="main">
          <Routes>
            <Route path="/"           element={<Navigate to="/dashboard" replace />} />
            <Route path="/dashboard"  element={<Dashboard />} />
            <Route path="/users"      element={<UsersPage />} />
            <Route path="/sos"        element={<SOSPage />} />
            <Route path="/community"  element={<CommunityReportsPage />} />
            <Route path="/heatmap"    element={<HeatmapPage />} />
            <Route path="/analytics"  element={<AnalyticsPage />} />
            <Route path="/profile"    element={<ProfilePage />} />
          </Routes>
        </div>
      </div>
      
      {showBroadcast && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setShowBroadcast(false)}>
          <div className="modal">
            <div className="modal-header">
              <div>
                <p className="modal-title" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  📢 Send Global Broadcast
                </p>
                <p style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 4 }}>
                  Pushes a real-time urgent alert notification to all active Flutter mobile application users.
                </p>
              </div>
              <button className="modal-close" onClick={() => setShowBroadcast(false)}>✕</button>
            </div>
            
            <form onSubmit={handleBroadcastSubmit} className="modal-form">
              <div className="input-group">
                <label className="input-label">Alert Title (Optional)</label>
                <input 
                  type="text" 
                  className="input" 
                  value={broadcastData.title} 
                  onChange={e => setBroadcastData({...broadcastData, title: e.target.value})}
                  placeholder="e.g., Severe Flood Warning / Evacuation Alert"
                />
              </div>
              <div className="input-group">
                <label className="input-label">Emergency Message *</label>
                <textarea 
                  className="input" 
                  rows="4"
                  value={broadcastData.message} 
                  onChange={e => setBroadcastData({...broadcastData, message: e.target.value})}
                  placeholder="Clearly state the required citizen action or safety warning details..."
                  required
                />
              </div>
              <div className="modal-actions" style={{ marginTop: 12 }}>
                <button type="button" className="btn btn-ghost" onClick={() => setShowBroadcast(false)}>Cancel</button>
                <button type="submit" className="btn btn-primary" style={{ background: '#ef4444', borderColor: '#ef4444' }}>
                  Send Alert Now
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

    </BrowserRouter>
  )
}

function Sidebar({ activeSOS, isDarkMode, setIsDarkMode, setShowBroadcast }) {
  const links = [
    { to: '/dashboard',  icon: <LuLayoutDashboard />, label: 'Dashboard' },
    { to: '/analytics',  icon: <LuTrendingUp />,      label: 'Analytics' },
    { to: '/heatmap',    icon: <LuMap />,             label: 'Safety Zone Map' },
    { divider: 'Management' },
    { to: '/sos',        icon: <LuTriangleAlert />,   label: 'SOS Incidents', badge: activeSOS > 0 ? activeSOS : null },
    { to: '/community',  icon: <LuMessageSquare />,   label: 'Community Feed' },
    { to: '/users',      icon: <LuUsers />,           label: 'Users' },
  ]

  return (
    <nav className="sidebar">
      <div className="sidebar-logo">
        <div className="sidebar-logo-icon"><LuShieldCheck size={20} /></div>
        <h1>SHEildAI</h1>
      </div>

      <div className="sidebar-nav">
        {links.map((l, i) =>
          l.divider ? (
            <p key={i} className="sidebar-section-label">{l.divider}</p>
          ) : (
            <NavLink
              key={l.to}
              to={l.to}
              className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}
            >
              <span className="nav-icon">{l.icon}</span>
              {l.label}
              {l.badge && <span className="nav-badge">{l.badge}</span>}
            </NavLink>
          )
        )}
      </div>

      <div style={{ padding: '0 20px', marginBottom: 20 }}>
        <button 
          className="btn btn-primary" 
          style={{ width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, background: '#ef4444', borderColor: '#ef4444' }}
          onClick={() => setShowBroadcast(true)}
        >
          <LuMegaphone size={16} /> Broadcast Alert
        </button>
      </div>

      <div className="sidebar-footer">
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingBottom: 15, marginBottom: 15, borderBottom: '1px solid var(--border)' }}>
          <span style={{ fontSize: 13, fontWeight: 600 }}>Dark Mode</span>
          <div 
            style={{ 
              width: 40, height: 22, background: isDarkMode ? '#3b82f6' : '#e5e7eb', borderRadius: 20, 
              position: 'relative', cursor: 'pointer', transition: 'all 0.3s' 
            }}
            onClick={() => setIsDarkMode(!isDarkMode)}
          >
            <div style={{
              width: 18, height: 18, background: '#fff', borderRadius: '50%',
              position: 'absolute', top: 2, left: isDarkMode ? 20 : 2, transition: 'all 0.3s',
              display: 'flex', alignItems: 'center', justifyContent: 'center', color: isDarkMode ? '#3b82f6' : '#9ca3af'
            }}>
              {isDarkMode ? <LuMoon size={11} /> : <LuSun size={11} />}
            </div>
          </div>
        </div>

        <NavLink to="/profile" style={{ textDecoration: 'none', display: 'block' }}>
          <div className="sidebar-user">
            <div className="sidebar-avatar">A</div>
            <div className="sidebar-user-info">
              <p>Admin</p>
              <span>Super Administrator</span>
            </div>
          </div>
        </NavLink>
      </div>
    </nav>
  )
}
