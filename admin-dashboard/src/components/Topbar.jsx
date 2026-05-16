import React from 'react'

export function Topbar({ title, sub }) {
  return (
    <div className="topbar" style={{
      height: '84px', background: 'var(--bg-surface)', borderBottom: '1px solid var(--border)',
      padding: '0 40px', display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      position: 'sticky', top: 0, zIndex: 1000, backdropFilter: 'blur(16px)',
      width: '100%'
    }}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
        <h1 style={{ fontSize: 22, fontWeight: 900, color: 'var(--text-primary)', margin: 0, letterSpacing: '-0.02em' }}>{title}</h1>
        {sub && <p style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-secondary)', margin: 0 }}>{sub}</p>}
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: 24 }}>
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
      </div>
    </div>
  )
}
