import { useEffect, useState } from 'react'
import toast from 'react-hot-toast'
import {
  AreaChart, Area,
  BarChart, Bar,
  PieChart, Pie, Cell, Legend,
  XAxis, YAxis, Tooltip, CartesianGrid, ResponsiveContainer,
} from 'recharts'
import { fetchIncidentsByDay, fetchIncidentsByStatus } from '../api'
import { Topbar } from './Dashboard'
import { format, parseISO, subDays } from 'date-fns'
import { LuActivity, LuTrendingUp, LuTrendingDown } from 'react-icons/lu'

const STATUS_PALETTE = {
  active:     '#ef4444',
  resolved:   '#10b981',
  false_alarm:'#f59e0b',
}

export default function AnalyticsPage() {
  const [trendData, setTrend]   = useState([])
  const [statusData, setStatus] = useState([])
  const [loading, setLoading]   = useState(true)
  const [days, setDays]         = useState(30)

  useEffect(() => {
    setLoading(true)
    Promise.all([fetchIncidentsByDay(days), fetchIncidentsByStatus()])
      .then(([t, s]) => {

        // Fill missing dates with 0
        const filled = []
        for (let i = days - 1; i >= 0; i--) {
          const date = format(subDays(new Date(), i), 'yyyy-MM-dd')
          const found = t.find(d => d.date === date)
          filled.push({ date, count: found ? found.count : 0 })
        }
        setTrend(filled)
        setStatus(s)
      })
      .catch(() => toast.error('Failed to load analytics'))
      .finally(() => setLoading(false))
  }, [days])

  const totalInPeriod = trendData.reduce((a, b) => a + b.count, 0)
  const peak = trendData.reduce((a, b) => (b.count > a.count ? b : a), { count: 0, date: '' })
  const avg  = trendData.length ? (totalInPeriod / trendData.length).toFixed(1) : 0

  const pieLabelRenderer = ({ name, percent }) =>
    `${name} ${(percent * 100).toFixed(0)}%`

  return (
    <>
      <Topbar title="Analytics" sub="Incident trends and distribution" />
      <div className="page-content">

        {/* Period Selector */}
        <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 20 }}>
          {[7, 14, 30, 60, 90].map(d => (
            <button
              key={d}
              className={`btn btn-sm ${days === d ? 'btn-primary' : 'btn-ghost'}`}
              style={{ marginLeft: 8 }}
              onClick={() => setDays(d)}
            >
              {d}d
            </button>
          ))}
        </div>

        {/* Summary Pills */}
        <div className="stats-grid" style={{ gridTemplateColumns: 'repeat(3,1fr)', marginBottom: 28 }}>
          {[
            { label: `Total in ${days} days`, value: totalInPeriod, icon: <LuActivity />, color: '#3b82f6' },
            { label: 'Peak Day',   value: peak.count, icon: <LuTrendingUp />, color: '#ef4444', sub: peak.date ? format(parseISO(peak.date), 'MMM d') : '—' },
            { label: 'Daily Avg',  value: avg,        icon: <LuTrendingDown />, color: '#8b5cf6' },
          ].map(s => (
            <div key={s.label} className="stat-card">
              <div className="stat-icon" style={{ background: `${s.color}20` }}>{s.icon}</div>
              <div className="stat-body">
                <p className="stat-label">{s.label}</p>
                <p className="stat-value" style={{ color: s.color }}>{s.value}</p>
                {s.sub && <p className="stat-sub">{s.sub}</p>}
              </div>
            </div>
          ))}
        </div>

        {/* Trend Chart */}
        <div className="card" style={{ marginBottom: 20 }}>
          <div className="card-header">
            <div>
              <p className="card-title">Incident Trend — Last {days} Days</p>
              <p className="card-subtitle">Daily SOS alert count</p>
            </div>
          </div>
          {loading ? (
            <div className="loading-spinner"><div className="spinner" /></div>
          ) : trendData.every(d => d.count === 0) ? (
            <div className="empty-state"><p className="empty-icon"><LuActivity size={32} color="#9ca3af" /></p><p>No incidents in this period</p></div>
          ) : (
            <ResponsiveContainer width="100%" height={260}>
              <AreaChart data={trendData} margin={{ left: -20 }}>
                <defs>
                  <linearGradient id="areaGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%"  stopColor="#3b82f6" stopOpacity={0.4} />
                    <stop offset="95%" stopColor="#3b82f6" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f3f4f6" />
                <XAxis
                  dataKey="date"
                  tickFormatter={d => { try { return format(parseISO(d), 'MMM d') } catch { return d } }}
                  interval={Math.floor(trendData.length / 7)}
                  axisLine={false} tickLine={false} tick={{fill: '#6b7280'}}
                />
                <YAxis allowDecimals={false} axisLine={false} tickLine={false} tick={{fill: '#6b7280'}} />
                <Tooltip
                  formatter={v => [v, 'Incidents']}
                  labelFormatter={l => { try { return format(parseISO(l), 'MMMM d, yyyy') } catch { return l } }}
                  contentStyle={{ borderRadius: 8, border: '1px solid #e5e7eb', background: '#ffffff', boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)' }}
                />
                <Area type="monotone" dataKey="count" stroke="#3b82f6" strokeWidth={3} fill="url(#areaGrad)" dot={false} activeDot={{ r: 6, fill: '#3b82f6', stroke: '#fff', strokeWidth: 2 }} />
              </AreaChart>
            </ResponsiveContainer>
          )}
        </div>

        <div className="grid-2">
          {/* Bar chart for bar distribution */}
          <div className="card">
            <div className="card-header">
              <div>
                <p className="card-title">Daily Bar Chart</p>
                <p className="card-subtitle">Visualise volume spikes</p>
              </div>
            </div>
            {loading ? (
              <div className="loading-spinner"><div className="spinner" /></div>
            ) : (
              <ResponsiveContainer width="100%" height={230}>
                <BarChart data={trendData.slice(-21)} margin={{ left: -20, top: 10 }}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f3f4f6" />
                  <XAxis dataKey="date" axisLine={false} tickLine={false} tick={{fill: '#6b7280'}} tickFormatter={d => { try { return format(parseISO(d), 'dd') } catch { return d } }} />
                  <YAxis allowDecimals={false} axisLine={false} tickLine={false} tick={{fill: '#6b7280'}} />
                  <Tooltip
                    formatter={v => [v, 'Incidents']}
                    labelFormatter={l => { try { return format(parseISO(l), 'MMM d') } catch { return l } }}
                    contentStyle={{ borderRadius: 8, border: '1px solid #e5e7eb', background: '#ffffff', boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)' }}
                    cursor={{ fill: '#f9fafb' }}
                  />
                  <Bar dataKey="count" fill="#8b5cf6" radius={[4, 4, 0, 0]}>
                    {trendData.slice(-21).map((e, i) => (
                      <Cell key={i} fill={e.count === peak.count ? '#3b82f6' : '#8b5cf6'} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            )}
          </div>

          {/* Status Pie */}
          <div className="card">
            <div className="card-header">
              <div>
                <p className="card-title">Status Distribution</p>
                <p className="card-subtitle">All-time breakdown</p>
              </div>
            </div>
            {loading ? (
              <div className="loading-spinner"><div className="spinner" /></div>
            ) : statusData.length === 0 ? (
              <div className="empty-state"><p className="empty-icon"><LuActivity size={32} color="#9ca3af" /></p><p>No data yet</p></div>
            ) : (
              <ResponsiveContainer width="100%" height={230}>
                <PieChart>
                  <Pie
                    data={statusData}
                    dataKey="count"
                    nameKey="status"
                    cx="50%" cy="50%"
                    outerRadius={80}
                    label={pieLabelRenderer}
                    labelLine={false}
                  >
                    {statusData.map((s, i) => (
                      <Cell key={i} fill={STATUS_PALETTE[s.status] || '#cbd5e1'} stroke="#ffffff" strokeWidth={2} />
                    ))}
                  </Pie>
                  <Tooltip formatter={(v, n) => [v, n.replace('_', ' ')]} contentStyle={{ borderRadius: 8, border: '1px solid #e5e7eb', background: '#ffffff', boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)' }} />
                  <Legend
                    formatter={v => v.replace('_', ' ')}
                    wrapperStyle={{ fontSize: 12, color: 'var(--text-secondary)' }}
                  />
                </PieChart>
              </ResponsiveContainer>
            )}
          </div>
        </div>

      </div>
    </>
  )
}
