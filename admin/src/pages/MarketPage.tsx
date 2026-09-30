import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  ActionButton,
  AlertBanner,
  Card,
  EmptyState,
  LoadingBlock,
  PageHeader,
  Tabs,
} from '@/components/ui/Primitives'
import { formatDate, formatINR } from '@/lib/mappers'
import {
  deleteMarketplaceItem,
  ensurePPRates,
  fetchMarketplace,
  fetchPPRates,
  updatePPRate,
  updatePPRateName,
} from '@/services/adminApi'
import type { MarketplaceItem, PPRate } from '@/types'

export function MarketPage() {
  const [tab, setTab] = useState('virgin')
  const [rates, setRates] = useState<PPRate[]>([])
  const [listings, setListings] = useState<MarketplaceItem[]>([])
  const [loading, setLoading] = useState(true)
  const [rateInput, setRateInput] = useState('')
  const [nameInput, setNameInput] = useState('')
  const [saving, setSaving] = useState(false)
  const [renaming, setRenaming] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [ok, setOk] = useState<string | null>(null)

  const load = async () => {
    setLoading(true)
    setError(null)
    try {
      await ensurePPRates()
      const [r, m] = await Promise.all([fetchPPRates(), fetchMarketplace('Raw Material')])
      setRates(r)
      setListings(m)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load market data')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void load()
  }, [])

  useEffect(() => {
    const current = rates.find((r) => r.id === tab)
    if (current) {
      setRateInput(String(current.currentRate))
      setNameInput(current.materialType || current.id)
    }
  }, [tab, rates])

  const activeRate = rates.find((r) => r.id === tab)
  const rateTabs =
    rates.length > 0
      ? rates.map((r) => ({ id: r.id, label: r.materialType || r.id }))
      : [
          { id: 'virgin', label: 'Virgin PP' },
          { id: 'recycled', label: 'Recycled PP' },
        ]

  const onUpdate = async () => {
    if (!activeRate) return
    const next = Number(rateInput)
    if (!Number.isFinite(next) || next <= 0) {
      setError('Enter a valid rate greater than 0')
      return
    }
    setSaving(true)
    setError(null)
    setOk(null)
    try {
      await updatePPRate(activeRate.id, next)
      setOk(`${activeRate.materialType || activeRate.id} rate updated to ₹${next}`)
      await load()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to update rate')
    } finally {
      setSaving(false)
    }
  }

  const onRename = async () => {
    if (!activeRate) return
    const next = nameInput.trim()
    if (!next) {
      setError('Enter a rate name')
      return
    }
    setRenaming(true)
    setError(null)
    setOk(null)
    try {
      await updatePPRateName(activeRate.id, next)
      setOk(`Rate name updated to “${next}”`)
      await load()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to rename rate')
    } finally {
      setRenaming(false)
    }
  }

  if (loading) return <LoadingBlock />

  return (
    <div>
      <PageHeader
        title="PP Rates"
        subtitle="Rename rates and update values shown in the mobile app"
        action={
          <Link
            to="/marketplace"
            className="rounded-lg border border-border px-4 py-2 text-sm hover:bg-bg"
          >
            Open Marketplace
          </Link>
        }
      />

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

      <div className="mb-4">
        <Tabs value={tab} onChange={setTab} items={rateTabs} />
      </div>

      <Card className="p-6 mb-6">
        <div className="text-sm text-muted mb-2">Rate name (shown in app)</div>
        <div className="flex flex-col sm:flex-row gap-3 max-w-xl mb-6">
          <input
            value={nameInput}
            onChange={(e) => setNameInput(e.target.value)}
            className="flex-1 rounded-xl border border-border px-4 py-3 outline-none focus:ring-2 focus:ring-primary/25"
            placeholder="e.g. Virgin PP"
          />
          <button
            onClick={() => void onRename()}
            disabled={!activeRate || renaming}
            className="rounded-xl border border-border px-5 py-3 font-medium hover:bg-bg disabled:opacity-50"
          >
            {renaming ? 'Saving…' : 'Change Name'}
          </button>
        </div>

        <div className="text-sm text-muted">Current Rate</div>
        <div className="mt-2 font-display text-4xl font-semibold">
          {activeRate ? formatINR(activeRate.currentRate) : '—'}
          <span className="text-lg text-muted font-normal"> / KG</span>
        </div>
        <div className="mt-1 text-sm text-muted">
          Change:{' '}
          <span className={(activeRate?.changePercent ?? 0) >= 0 ? 'text-primary' : 'text-error'}>
            {(activeRate?.changePercent ?? 0) >= 0 ? '+' : ''}
            {(activeRate?.changePercent ?? 0).toFixed(2)}%
          </span>
        </div>
        <div className="mt-5 flex flex-col sm:flex-row gap-3 max-w-md">
          <input
            value={rateInput}
            onChange={(e) => setRateInput(e.target.value)}
            className="flex-1 rounded-xl border border-border px-4 py-3 outline-none focus:ring-2 focus:ring-primary/25"
            placeholder="New rate ₹/KG"
          />
          <button
            onClick={() => void onUpdate()}
            disabled={!activeRate || saving}
            className="rounded-xl bg-primary hover:bg-primary-dark text-white px-5 py-3 font-medium disabled:opacity-50"
          >
            {saving ? 'Updating…' : 'Update Rate'}
          </button>
        </div>

        <div className="mt-8 overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-muted border-b border-border">
                <th className="py-3 font-medium">Date</th>
                <th className="py-3 font-medium">Rate (₹/KG)</th>
                <th className="py-3 font-medium">Note</th>
              </tr>
            </thead>
            <tbody>
              {(activeRate?.history ?? [])
                .slice()
                .reverse()
                .map((h, i) => (
                  <tr key={`${h.rate}-${i}`} className="border-b border-border/70">
                    <td className="py-3">{formatDate(h.date)}</td>
                    <td className="py-3 font-medium tabular-nums">{formatINR(h.rate)}</td>
                    <td className="py-3 text-muted">Updated by admin</td>
                  </tr>
                ))}
              {!activeRate?.history?.length && (
                <tr>
                  <td colSpan={3} className="py-8 text-center text-muted">
                    No rate history — set a rate above
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </Card>

      <h2 className="font-display font-semibold text-lg mb-3">Raw material listings</h2>
      {listings.length === 0 ? (
        <Card>
          <EmptyState title="No raw material listings" hint="Manage all categories in Marketplace" />
        </Card>
      ) : (
        <div className="grid md:grid-cols-2 gap-3">
          {listings.map((item) => (
            <Card key={item.id} className="p-4">
              <div className="text-xs text-muted">{item.category}</div>
              <div className="font-medium mt-1">{item.title}</div>
              <div className="text-sm text-muted mt-1 line-clamp-2">{item.description}</div>
              <div className="mt-3 flex justify-between text-sm">
                <span className="font-semibold text-primary">
                  {formatINR(item.price)} / {item.unit}
                </span>
                <span className="text-muted">
                  {item.quantity} {item.unit}
                </span>
              </div>
              <div className="mt-2 text-xs text-muted">
                {item.sellerName} · {item.location} · {formatDate(item.createdAt)}
              </div>
              <div className="mt-3">
                <ActionButton
                  variant="danger"
                  onClick={async () => {
                    if (!confirm(`Delete “${item.title}”?`)) return
                    try {
                      await deleteMarketplaceItem(item.id)
                      setOk('Listing deleted')
                      await load()
                    } catch (e) {
                      setError(e instanceof Error ? e.message : 'Delete failed')
                    }
                  }}
                >
                  Delete
                </ActionButton>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  )
}
