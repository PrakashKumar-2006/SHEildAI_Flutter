import { BrowserRouter, Routes, Route, NavLink, Navigate } from 'react-router-dom'
import { Toaster } from 'react-hot-toast'
import { useState, useEffect } from 'react'
import { fetchStats } from './api'
import { LuLayoutDashboard, LuTrendingUp, LuMap, LuTriangleAlert, LuUsers, LuPhone, LuShieldCheck } from 'react-icons/lu'

import Dashboard  from './pages/Dashboard'
import UsersPage  from './pages/UsersPage'
import SOSPage    from './pages/SOSPage'
import ContactsPage from './pages/ContactsPage'
import HeatmapPage  from './pages/HeatmapPage'
import AnalyticsPage from './pages/AnalyticsPage'
import ProfilePage   from './pages/ProfilePage'

export default function App() {
  const [activeSOS, setActiveSOS] = useState(0)

  useEffect(() => {
    const load = () => fetchStats().then(s => setActiveSOS(s.activeSOS || 0)).catch(() => {})
    load()
    const interval = setInterval(load, 30000)
    return () => clearInterval(interval)
  }, [])

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
        <Sidebar activeSOS={activeSOS} />
        <div className="main">
          <Routes>
            <Route path="/"           element={<Navigate to="/dashboard" replace />} />
            <Route path="/dashboard"  element={<Dashboard />} />
            <Route path="/users"      element={<UsersPage />} />
            <Route path="/sos"        element={<SOSPage />} />
            <Route path="/contacts"   element={<ContactsPage />} />
            <Route path="/heatmap"    element={<HeatmapPage />} />
            <Route path="/analytics"  element={<AnalyticsPage />} />
            <Route path="/profile"    element={<ProfilePage />} />
          </Routes>
        </div>
      </div>
    </BrowserRouter>
  )
}

function Sidebar({ activeSOS }) {
  const links = [
    { to: '/dashboard',  icon: <LuLayoutDashboard />, label: 'Dashboard' },
    { to: '/analytics',  icon: <LuTrendingUp />,      label: 'Analytics' },
    { to: '/heatmap',    icon: <LuMap />,             label: 'Safety Zone Map' },
    { divider: 'Management' },
    { to: '/sos',        icon: <LuTriangleAlert />,   label: 'SOS Incidents', badge: activeSOS > 0 ? activeSOS : null },
    { to: '/users',      icon: <LuUsers />,           label: 'Users' },
    { to: '/contacts',   icon: <LuPhone />,         label: 'Contacts' },
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

      <div className="sidebar-footer">
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
