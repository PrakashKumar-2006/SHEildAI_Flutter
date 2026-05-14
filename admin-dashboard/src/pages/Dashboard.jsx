import { useEffect, useState } from 'react'
import { fetchStats, fetchIncidentsByDay } from '../api'
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts'
import { format, parseISO } from 'date-fns'
import { LuUsers, LuTriangleAlert, LuCheck, LuOctagonAlert, LuPhone, LuTrendingUp, LuMap, LuShieldAlert } from 'react-icons/lu'

export default function Dashboard() {
  const [stats, setStats]   = useState(null)
  const [trend, setTrend]   = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const load = () => {
      Promise.all([fetchStats(), fetchIncidentsByDay(14)])
        .then(([s, t]) => { setStats(s); setTrend(t) })
        .finally(() => setLoading(false))
    }
    
    load()

    const interval = setInterval(load, 30000)
    window.addEventListener('realtime_update', load)

    return () => {
      clearInterval(interval)
      window.removeEventListener('realtime_update', load)
    }
  }, [])

  if (loading) return (
    <>
      <Topbar title="Dashboard" sub="Overview of the SHEildAI platform" />
      <div className="page-content">
        <div className="loading-spinner"><div className="spinner" /></div>
      </div>
    </>
  )

  const statCards = [
    { label: 'Total Users',       value: stats?.totalUsers ?? 0,        icon: <LuUsers />,         color: '#3b82f6', sub: `+${stats?.newUsersThisMonth ?? 0} this month` },
    { label: 'Total SOS Alerts',  value: stats?.totalSOS ?? 0,          icon: <LuTriangleAlert />, color: '#ef4444', sub: `${stats?.sosLast24h ?? 0} in last 24h` },
    { label: 'Active Incidents',  value: stats?.activeSOS ?? 0,         icon: <LuShieldAlert />,   color: '#ef4444', sub: 'Needs attention' },
    { label: 'Resolved',          value: stats?.resolvedSOS ?? 0,       icon: <LuCheck />,   color: '#10b981', sub: 'Successfully closed' },
    { label: 'False Alarms',      value: stats?.falseAlarmSOS ?? 0,     icon: <LuOctagonAlert />,  color: '#f59e0b', sub: 'Marked false alarm' },
  ]

  const resolution = stats?.totalSOS > 0
    ? ((stats.resolvedSOS / stats.totalSOS) * 100).toFixed(1)
    : 0

  return (
    <>
      <Topbar title="Dashboard Overview" sub="Real-time surveillance & statistics" />
      <div className="page-content">

        {/* Stats Grid */}
        <div className="stats-grid">
          {statCards.map((s) => (
            <div key={s.label} className="stat-card" style={{ borderTop: `3px solid ${s.color}` }}>
              <div className="stat-icon" style={{ color: s.color, backgroundColor: `${s.color}08`, borderColor: `${s.color}20` }}>
                {s.icon}
              </div>
              <div className="stat-body">
                <p className="stat-label">{s.label}</p>
                <p className="stat-value">{s.value.toLocaleString()}</p>
                <p className="stat-sub">{s.sub}</p>
              </div>
            </div>
          ))}
        </div>

        <div className="grid-60-40" style={{ marginBottom: 24 }}>
          {/* Incident Trend */}
          <div className="card">
            <div className="card-header">
              <div>
                <p className="card-title">Incident Trend — Last 14 Days</p>
                <p className="card-subtitle">Daily SOS alert volume</p>
              </div>
            </div>
            {trend.length === 0 ? (
              <div className="empty-state"><p className="empty-icon"><LuTrendingUp size={32} color="#9ca3af" /></p><p>No incident data yet</p></div>
            ) : (
              <ResponsiveContainer width="100%" height={260}>
                <AreaChart data={trend} margin={{ left: -20, top: 10 }}>
                  <defs>
                    <linearGradient id="grad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%"  stopColor="#3b82f6" stopOpacity={0.4} />
                      <stop offset="95%" stopColor="#3b82f6" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f3f4f6" />
                  <XAxis dataKey="date" tickFormatter={d => d.split('-')[2]} axisLine={false} tickLine={false} tick={{fill: '#6b7280'}} />
                  <YAxis allowDecimals={false} axisLine={false} tickLine={false} tick={{fill: '#6b7280'}} />
                  <Tooltip
                    formatter={v => [v, 'Alerts']}
                    labelFormatter={l => format(parseISO(l), 'MMM d')}
                    contentStyle={{ borderRadius: 8, border: '1px solid #e5e7eb', background: '#ffffff', boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)' }}
                  />
                  <Area type="monotone" dataKey="count" stroke="#3b82f6" strokeWidth={3} fill="url(#grad)" activeDot={{ r: 6, fill: '#3b82f6', stroke: '#fff', strokeWidth: 2 }} />
                </AreaChart>
              </ResponsiveContainer>
            )}
          </div>

          {/* Summary */}
          <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div>
              <p className="card-title">Resolution Rate</p>
              <p className="card-subtitle">Overall incident closure performance</p>
            </div>

            <div style={{ textAlign: 'center', padding: '12px 0' }}>
              <p style={{ fontSize: 52, fontWeight: 900, color: 'var(--status-resolved)', letterSpacing: -2 }}>{resolution}%</p>
              <p style={{ fontSize: 12, color: 'var(--text-muted)', marginTop: 4 }}>of {stats?.totalSOS ?? 0} total incidents resolved</p>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {[
                { label: 'Active',     val: stats?.activeSOS ?? 0,     cls: 'badge-active' },
                { label: 'Resolved',   val: stats?.resolvedSOS ?? 0,   cls: 'badge-resolved' },
                { label: 'False Alarm',val: stats?.falseAlarmSOS ?? 0, cls: 'badge-false' },
              ].map(({ label, val, cls }) => (
                <div key={label} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 14px', background: 'var(--bg-hover)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border)' }}>
                  <span className={`badge ${cls}`}>{label}</span>
                  <span style={{ fontWeight: 800, fontSize: 15, color: 'var(--text-primary)' }}>{val}</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Activity Feed placeholder */}
        <div className="card">
          <div className="card-header">
            <p className="card-title">Quick Actions</p>
          </div>
          <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
            {[
              { label: 'View Active SOS', icon: <LuShieldAlert />, to: '/sos' },
              { label: 'Manage Users',    icon: <LuUsers />,       to: '/users' },
              { label: 'Risk Heatmap',    icon: <LuMap />,         to: '/heatmap' },
              { label: 'Analytics',       icon: <LuTrendingUp />,  to: '/analytics' },
            ].map(({ label, icon, to }) => (
              <a key={to} href={to} className="btn btn-ghost" style={{ flexShrink: 0, display: 'flex', alignItems: 'center', gap: '8px' }}>
                {icon} {label}
              </a>
            ))}
          </div>
        </div>

      </div>
    </>
  )
}

export function Topbar({ title, sub, right }) {
  return (
    <div className="topbar">
      <div className="topbar-left">
        <h2>{title}</h2>
        {sub && <p>{sub}</p>}
      </div>
      <div className="topbar-right">
        <span className="topbar-badge badge-live">
          <span className="badge-dot" />
          Live
        </span>
        {right}
      </div>
    </div>
  )
}
