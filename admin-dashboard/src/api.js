import axios from 'axios'

const API = axios.create({ baseURL: (import.meta.env.VITE_API_BASE_URL || '') + '/api' })

// ── Stats ─────────────────────────────────────────────────────────────────
export const fetchStats           = ()           => API.get('/admin/stats').then(r => r.data)

// ── Users ─────────────────────────────────────────────────────────────────
export const fetchUsers           = (params)     => API.get('/admin/users', { params }).then(r => r.data)
export const updateUser           = (id, data)   => API.put(`/admin/users/${id}`, data).then(r => r.data)
export const deleteUser           = (id)         => API.delete(`/admin/users/${id}`).then(r => r.data)

// ── SOS ───────────────────────────────────────────────────────────────────
export const fetchSOS             = (params)     => API.get('/admin/sos', { params }).then(r => r.data)
export const updateSOS            = (id, data)   => API.put(`/admin/sos/${id}`, data).then(r => r.data)
export const deleteSOS            = (id)         => API.delete(`/admin/sos/${id}`).then(r => r.data)

// ── Contacts ──────────────────────────────────────────────────────────────
export const fetchContacts        = (params)     => API.get('/admin/contacts', { params }).then(r => r.data)
export const deleteContact        = (id)         => API.delete(`/admin/contacts/${id}`).then(r => r.data)

// ── Analytics ─────────────────────────────────────────────────────────────
export const fetchIncidentsByDay    = (days=30)  => API.get('/admin/analytics/incidents-by-day', { params: { days } }).then(r => r.data)
export const fetchIncidentsByStatus = ()         => API.get('/admin/analytics/incidents-by-status').then(r => r.data)
export const fetchHeatmapData       = ()         => API.get('/admin/analytics/heatmap').then(r => r.data)
export const fetchTopZones          = ()         => API.get('/admin/analytics/top-zones').then(r => r.data)


// ── Risk Zones (same as Flutter app home screen) ───────────────────────────
export const fetchRiskZones         = ()         => API.get('/admin/risk-zones').then(r => r.data)

// ── ML Hotspots (from huggingface ML model) ──────────────────────────────
export const fetchMLHotspots        = ()         => axios.get('https://prakashkumarbiswal-sheildai-ml.hf.space/api/hotspots').then(r => r.data)

// ── Community Reports & Broadcast ──────────────────────────────────────────
export const fetchCommunityReports  = (p=1, l=50)=> API.get(`/admin/community-reports?page=${p}&limit=${l}`).then(r => r.data)
export const sendBroadcast          = (data)     => API.post('/admin/broadcast', data).then(r => r.data)
export const fetchResponseTimeAnalytics = ()     => API.get('/admin/analytics/response-time').then(r => r.data)
