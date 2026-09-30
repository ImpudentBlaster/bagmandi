import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { AlertBanner, Card, LoadingBlock, PageHeader, StatCard } from '@/components/ui/Primitives'
import { formatDate, formatINR } from '@/lib/mappers'
import {
  ensurePPRates,
  fetchEnquiries,
  fetchPPRates,
  getAdminStats,
  updatePPRate,
} from '@/services/adminApi'
import type { AdminStats, Enquiry, PPRate } from '@/types'

const quickLinks = [
  { to: '/users', label: 'Users' },
  { to: '/enquiries', label: 'Enquiries' },
  { to: '/quotes', label: 'Quotes' },
  { to: '/orders', label: 'Orders' },
  { to: '/marketplace', label: 'Marketplace' },
  { to: '/market', label: 'PP Rates' },
  { to: '/notifications', label: 'Notify' },
]

export function DashboardPage() {
  const [stats, setStats] = useState<AdminStats | null>(null)
  const [rates, setRates] = useState<PPRate[]>([])
  const [enquiries, setEnquiries] = useState<Enquiry[]>([])
  const [loading, setLoading] = useState(true)
  const [updating, setUpdating] = useState(false)
  const [rateInput, setRateInput] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [ok, setOk] = useState<string | null>(null)

  const load = async () => {
    setLoading(true)
    setError(null)
    try {
      await ensurePPRates()
      const [s, r, e] = await Promise.all([getAdminStats(), fetchPPRates(), fetchEnquiries()])
      setStats(s)
      setRates(r)
      setEnquiries(e)
      const virgin = r.find((x) => x.id === 'virgin') ?? r[0]
      if (virgin) setRateInput(String(virgin.currentRate))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load dashboard')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void load()
  }, [])

  const virgin = rates.find((x) => x.id === 'virgin') ?? rates[0]

  const chartData = useMemo(() => {
    const buckets = Array.from({ length: 8 }, (_, i) => ({
      hour: `${i * 3}:00`,
      enquiries: 0,
      quotes: 0,
    }))
    const now = new Date()
    for (const enq of enquiries) {
      if (!enq.createdAt) continue
      const sameDay =
        enq.createdAt.getFullYear() === now.getFullYear() &&
        enq.createdAt.getMonth() === now.getMonth() &&
        enq.createdAt.getDate() === now.getDate()
      if (!sameDay) continue
      const idx = Math.min(7, Math.floor(enq.createdAt.getHours() / 3))
      buckets[idx].enquiries += 1
      buckets[idx].quotes += enq.quoteCount
    }
    return buckets
  }, [enquiries])

  const onUpdateRate = async () => {
    if (!virgin) return
    const next = Number(rateInput)
    if (!Number.isFinite(next) || next <= 0) {
      setError('Enter a valid PP rate')
      return
    }
    setUpdating(true)
    setError(null)
    setOk(null)
    try {
      await updatePPRate(virgin.id, next)
      setOk('PP rate updated')
      await load()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Rate update failed')
    } finally {
      setUpdating(false)
    }
  }

  if (loading) return <LoadingBlock />

  return (
    <div>
      <PageHeader title="Dashboard" subtitle="Platform overview for BagMandi" />

      {error && (
        <div className="mb-4">
          <AlertBanner>{error}</AlertBanner>
        </div>
      )}
      {ok && (
        <div className="mb-4">
          <AlertBanner tone="success">{ok}</AlertBanner>
        </div>
      )}

      <div className="mb-4 flex flex-wrap gap-2">
        {quickLinks.map((l) => (
          <Link
            key={l.to}
            to={l.to}
            className="rounded-full border border-border bg-surface px-4 py-2 text-sm font-medium hover:bg-bg"
          >
            {l.label}
          </Link>
        ))}
      </div>

      <div className="grid sm:grid-cols-2 xl:grid-cols-4 gap-4">
        <StatCard label="Total Users" value={stats?.totalUsers ?? 0} accent="primary" />
        <StatCard label="Manufacturers" value={stats?.manufacturers ?? 0} accent="purple" />
        <StatCard label="Buyers" value={stats?.buyers ?? 0} accent="info" />
        <StatCard label="Enquiries" value={stats?.enquiries ?? 0} accent="warning" />
      </div>
      <div className="grid sm:grid-cols-2 xl:grid-cols-4 gap-4 mt-4">
        <StatCard label="Quotes" value={stats?.quotes ?? 0} accent="info" />
        <StatCard label="Orders" value={stats?.orders ?? 0} accent="primary" />
        <StatCard label="Marketplace" value={stats?.marketplace ?? 0} accent="purple" />
        <StatCard
          label="Order value"
          value={formatINR(stats?.orderValue ?? 0)}
          accent="warning"
        />
      </div>

      <div className="mt-6 grid xl:grid-cols-3 gap-4">
        <Card className="xl:col-span-2 p-5">
          <div className="flex items-center justify-between mb-4">
            <h2 className="font-display font-semibold text-lg">Today&apos;s Overview</h2>
            <span className="text-xs text-muted">Enquiries / quotes by hour</span>
          </div>
          <div className="h-72">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
                <XAxis dataKey="hour" tick={{ fontSize: 12 }} stroke="#9CA3AF" />
                <YAxis tick={{ fontSize: 12 }} stroke="#9CA3AF" allowDecimals={false} />
                <Tooltip />
                <Line type="monotone" dataKey="enquiries" stroke="#189F43" strokeWidth={2} dot={false} />
                <Line type="monotone" dataKey="quotes" stroke="#3B82F6" strokeWidth={2} dot={false} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </Card>

        <Card className="overflow-hidden">
          <div className="bg-rate text-white p-5">
            <div className="text-sm text-white/60">
              {virgin ? `PP Rate (${virgin.materialType})` : 'PP Rate'}
            </div>
            <div className="mt-2 font-display text-3xl font-semibold">
              {virgin ? formatINR(virgin.currentRate) : '—'}
              <span className="text-base font-normal text-white/60"> / KG</span>
            </div>
            <div
              className={`mt-2 text-sm ${
                (virgin?.changePercent ?? 0) >= 0 ? 'text-emerald-300' : 'text-red-300'
              }`}
            >
              {(virgin?.changePercent ?? 0) >= 0 ? '+' : ''}
              {(virgin?.changePercent ?? 0).toFixed(2)}%
            </div>
            <div className="mt-4 flex gap-2">
              <input
                value={rateInput}
                onChange={(e) => setRateInput(e.target.value)}
                className="flex-1 rounded-lg bg-white/10 border border-white/15 px-3 py-2 text-sm outline-none"
                placeholder="New rate"
              />
              <button
                onClick={() => void onUpdateRate()}
                disabled={updating || !virgin}
                className="rounded-lg bg-primary px-3 py-2 text-sm font-medium disabled:opacity-50"
              >
                {updating ? '…' : 'Update Rate'}
              </button>
            </div>
          </div>
          <div className="p-5">
            <div className="text-sm font-medium mb-3">Rate History</div>
            <div className="space-y-3 max-h-48 overflow-auto">
              {(virgin?.history ?? [])
                .slice()
                .reverse()
                .slice(0, 8)
                .map((h, i) => (
                  <div key={`${h.rate}-${i}`} className="flex items-center justify-between text-sm">
                    <span className="text-muted">{formatDate(h.date)}</span>
                    <span className="font-medium tabular-nums">{formatINR(h.rate)}</span>
                  </div>
                ))}
              {!virgin?.history?.length && (
                <p className="text-sm text-muted">No history yet</p>
              )}
            </div>
          </div>
        </Card>
      </div>
    </div>
  )
}
