import { useEffect, useState } from 'react'
import { fetchStats, fetchIncidentsByDay } from '../api'
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts'
import { format, parseISO } from 'date-fns'
import {
  LuUsers, LuTriangleAlert, LuCheck, LuOctagonAlert,
  LuPhone, LuTrendingUp, LuMap, LuShieldAlert, LuActivity
} from 'react-icons/lu'

export default function Dashboard() {
  const [stats, setStats] = useState(null)
  const [trend, setTrend] = useState([])
  const [loading, setLoading] = useState(true)
  const [currentTime, setCurrentTime] = useState(new Date())

  useEffect(() => {
    const load = () => {
      Promise.all([fetchStats(), fetchIncidentsByDay(14)])
        .then(([s, t]) => { setStats(s); setTrend(t) })
        .finally(() => setLoading(false))
    }

    load()
    const itv = setInterval(load, 30000)
    const timeItv = setInterval(() => setCurrentTime(new Date()), 1000)
    window.addEventListener('realtime_update', load)

    return () => {
      clearInterval(itv)
      clearInterval(timeItv)
      window.removeEventListener('realtime_update', load)
    }
  }, [])

  if (loading) return (
    <div className="page-container">
      <Topbar title="Command Center" sub="Initializing surveillance protocols..." />
      <div className="page-content"><div className="spinner" /></div>
    </div>
  )

  const activeSOS = stats?.activeSOS ?? 0
  const resolution = stats?.totalSOS > 0 ? ((stats.resolvedSOS / stats.totalSOS) * 100).toFixed(1) : 0

  return (
    <div className="page-main-container">
      <Topbar
        title="Command Center"
        sub={`Overview as of ${format(currentTime, 'MMMM do, HH:mm:ss')}`}
      />

      <div className="page-content">

        {/* Welcome & System Status */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <h2 style={{ fontSize: 24, fontWeight: 900, color: 'var(--text-primary)', marginBottom: 4 }}>
              Welcome Back, Admin
            </h2>
            <p style={{ fontSize: 13, color: 'var(--text-muted)' }}>
              All systems operational. <span style={{ color: '#10b981', fontWeight: 700 }}>● Live Sync Active</span>
            </p>
          </div>

          {activeSOS > 0 && (
            <div className="pulse-alert" style={{
              background: '#ef444415', border: '1px solid #ef444430',
              padding: '10px 20px', borderRadius: 12, display: 'flex', alignItems: 'center', gap: 12
            }}>
              <div className="pulse" style={{ background: '#ef4444' }}></div>
              <p style={{ color: '#ef4444', fontWeight: 800, fontSize: 13, margin: 0 }}>
                {activeSOS} CRITICAL INCIDENTS
              </p>
              <a href="/sos" className="btn btn-sm" style={{ background: '#ef4444', color: '#fff', border: 'none', marginLeft: 8 }}>Respond Now</a>
            </div>
          )}
        </div>

        {/* Intelligence Grid */}
        <div className="stats-grid" style={{ gridTemplateColumns: 'repeat(5, 1fr)', gap: 16, marginBottom: 24 }}>
          {[
            { label: 'Total Citizens', value: stats?.totalUsers ?? 0, icon: <LuUsers />, color: '#3b82f6' },
            { label: 'Total SOS', value: stats?.totalSOS ?? 0, icon: <LuTriangleAlert />, color: '#ef4444' },
            { label: 'Active Alerts', value: activeSOS, icon: <LuShieldAlert />, color: '#ef4444', pulse: activeSOS > 0 },
            { label: 'Resolved', value: stats?.resolvedSOS ?? 0, icon: <LuCheck />, color: '#10b981' },
            { label: 'Efficiency', value: `${resolution}%`, icon: <LuTrendingUp />, color: '#8b5cf6' },
          ].map((s, i) => (
            <div key={i} className="card" style={{ padding: 20, position: 'relative', overflow: 'hidden' }}>
              <div style={{ color: s.color, marginBottom: 12 }}>{s.icon}</div>
              <p style={{ fontSize: 11, fontWeight: 800, color: 'var(--text-muted)', textTransform: 'uppercase', marginBottom: 4 }}>{s.label}</p>
              <p style={{ fontSize: 26, fontWeight: 900, color: 'var(--text-primary)' }}>{s.value.toLocaleString()}</p>
              {s.pulse && <div className="pulse" style={{ position: 'absolute', top: 15, right: 15, background: s.color }} />}
            </div>
          ))}
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1.8fr 1fr', gap: 24, marginBottom: 24 }}>
          {/* Main Operational Chart */}
          <div className="card" style={{ padding: 0 }}>
            <div style={{ padding: '20px 24px', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <p style={{ fontWeight: 800, fontSize: 15 }}>Operational Pulse</p>
                <p style={{ fontSize: 11, color: 'var(--text-muted)' }}>14-day emergency volume tracking</p>
              </div>
              <div style={{ padding: '6px 12px', background: 'var(--bg-hover)', borderRadius: 8, fontSize: 10, fontWeight: 800, color: 'var(--text-muted)' }}>
                LIVE FEED
              </div>
            </div>
            <div style={{ padding: '24px 10px 10px' }}>
              <ResponsiveContainer width="100%" height={270}>
                <AreaChart data={trend}>
                  <defs>
                    <linearGradient id="dashGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="var(--brand-primary)" stopOpacity={0.3} />
                      <stop offset="95%" stopColor="var(--brand-primary)" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="var(--border)" opacity={0.3} />
                  <XAxis
                    dataKey="date"
                    tickFormatter={d => { try { return d.split('-')[2] } catch (e) { return d } }}
                    axisLine={false} tickLine={false} tick={{ fontSize: 11, fontWeight: 600, fill: 'var(--text-muted)' }}
                  />
                  <YAxis axisLine={false} tickLine={false} tick={{ fontSize: 11, fill: 'var(--text-muted)' }} width={35} />
                  <Tooltip
                    contentStyle={{ borderRadius: 12, border: 'none', background: 'var(--bg-surface)', boxShadow: 'var(--shadow-lg)', padding: '12px 16px' }}
                    itemStyle={{ fontWeight: 900, fontSize: 15 }}
                  />
                  <Area
                    type="monotone"
                    dataKey="count"
                    name="Alerts"
                    stroke="var(--brand-primary)"
                    strokeWidth={4}
                    fillOpacity={1}
                    fill="url(#dashGrad)"
                    activeDot={{ r: 6, strokeWidth: 0, fill: 'var(--brand-primary)' }}
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Quick Actions / Integration */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
            <div className="card" style={{ padding: 24, background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)', color: '#fff', border: 'none', display: 'flex', flexDirection: 'column', justifyContent: 'center', flex: 1 }}>
              <LuShieldAlert size={32} style={{ marginBottom: 16, opacity: 0.8 }} />
              <h3 style={{ fontWeight: 900, fontSize: 18, marginBottom: 8 }}>Enterprise Safety</h3>
              <p style={{ fontSize: 13, opacity: 0.9, lineHeight: 1.5, marginBottom: 20 }}>
                Unified city-wide emergency protocols and citizen metrics.
              </p>
              <a href="/heatmap" className="btn" style={{ background: '#fff', color: '#1d4ed8', border: 'none', fontWeight: 800, width: 'fit-content', padding: '10px 24px' }}>
                Open Global Map
              </a>
            </div>

            <div className="card" style={{ padding: 20 }}>
              <p style={{ fontWeight: 800, fontSize: 14, marginBottom: 16 }}>Quick Access</p>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                {[
                  { label: 'Incidents', icon: <LuTriangleAlert />, to: '/sos' },
                  { label: 'Citizens', icon: <LuUsers />, to: '/users' },
                  { label: 'Analytics', icon: <LuTrendingUp />, to: '/analytics' },
                  { label: 'Hotspots', icon: <LuMap />, to: '/heatmap' },
                ].map(a => (
                  <a key={a.to} href={a.to} style={{
                    textDecoration: 'none', padding: '16px 12px', borderRadius: 12, border: '1px solid var(--border)',
                    display: 'flex', alignItems: 'center', gap: 10, background: 'var(--bg-hover)', transition: 'all 0.2s'
                  }}>
                    <div style={{ color: 'var(--brand-primary)' }}>{a.icon}</div>
                    <span style={{ fontSize: 12, fontWeight: 800, color: 'var(--text-primary)' }}>{a.label}</span>
                  </a>
                ))}
              </div>
            </div>
          </div>
        </div>

      </div>
    </div>
  )
}

export function Topbar({ title, sub, subtitle, right }) {
  const displaySub = sub || subtitle;
  return (
    <div className="topbar" style={{
      height: '76px', background: 'var(--bg-surface)', borderBottom: '1px solid var(--border)',
      padding: '0 32px', display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      position: 'sticky', top: 0, zIndex: 1000, backdropFilter: 'blur(16px)',
      boxShadow: '0 4px 10px -4px rgba(15, 23, 42, 0.04)'
    }}>
      <div className="topbar-left">
        <h2 style={{ fontSize: 20, fontWeight: 900, color: 'var(--text-primary)', letterSpacing: '-0.02em', margin: 0 }}>{title}</h2>
        {displaySub && <p style={{ fontSize: 12, color: 'var(--text-muted)', fontWeight: 600, margin: '2px 0 0 0', textTransform: 'uppercase', letterSpacing: '0.04em' }}>{displaySub}</p>}
      </div>
      <div className="topbar-right" style={{ display: 'flex', alignItems: 'center', gap: 24 }}>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 10, padding: '6px 14px',
          borderRadius: 20, background: 'var(--bg-hover)', border: '1px solid var(--border)',
          boxShadow: 'inset 0 1px 2px rgba(0,0,0,0.02)'
        }}>
          <div className="pulse" style={{ width: 8, height: 8, background: '#10b981', boxShadow: '0 0 10px rgba(16, 185, 129, 0.4)' }}></div>
          <span style={{ fontSize: 11, fontWeight: 900, color: 'var(--text-primary)', textTransform: 'uppercase', letterSpacing: '0.08em' }}>
            Live
          </span>
        </div>
        {right}
      </div>
    </div>
  )
}
