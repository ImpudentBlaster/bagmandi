import { useEffect, useMemo, useState } from 'react'
import {
  ActionButton,
  AlertBanner,
  Card,
  EmptyState,
  LoadingBlock,
  PageHeader,
  StatusBadge,
  Tabs,
} from '@/components/ui/Primitives'
import { formatDate, formatINR } from '@/lib/mappers'
import { deleteMarketplaceItem, fetchMarketplace } from '@/services/adminApi'
import type { MarketplaceItem } from '@/types'

const categories = [
  { id: 'all', label: 'All' },
  { id: 'Raw Material', label: 'Raw Material' },
  { id: 'Dead Stock', label: 'Dead Stock' },
  { id: 'Machines', label: 'Machines' },
  { id: 'Services', label: 'Services' },
]

export function MarketplacePage() {
  const [tab, setTab] = useState('all')
  const [items, setItems] = useState<MarketplaceItem[]>([])
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [busyId, setBusyId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [ok, setOk] = useState<string | null>(null)

  const load = async () => {
    setLoading(true)
    setError(null)
    try {
      setItems(await fetchMarketplace(tab === 'all' ? undefined : tab))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load marketplace')
      setItems([])
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void load()
  }, [tab])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return items
    return items.filter((i) =>
      [i.title, i.sellerName, i.description, i.location, i.category]
        .join(' ')
        .toLowerCase()
        .includes(q),
    )
  }, [items, search])

  return (
    <div>
      <PageHeader
        title="Marketplace"
        subtitle="Moderate Raw Material, Dead Stock, Machines and Services listings"
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
        <Tabs value={tab} onChange={setTab} items={categories} />
      </div>

      <Card className="p-4 mb-4">
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search listing, seller, location…"
          className="w-full rounded-xl border border-border px-4 py-3 outline-none focus:ring-2 focus:ring-primary/25"
        />
      </Card>

      {loading ? (
        <LoadingBlock />
      ) : filtered.length === 0 ? (
        <Card>
          <EmptyState title="No listings" hint="Manufacturer marketplace posts appear here" />
        </Card>
      ) : (
        <div className="space-y-3">
          {filtered.map((item) => (
            <Card
              key={item.id}
              className="p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-3"
            >
              <div className="min-w-0">
                <div className="flex flex-wrap items-center gap-2">
                  <StatusBadge status={item.category} />
                  <span className="text-xs text-muted">{formatDate(item.createdAt)}</span>
                </div>
                <div className="font-display font-semibold text-lg mt-2">{item.title}</div>
                <p className="text-sm text-muted mt-1">{item.description}</p>
                <p className="text-sm text-muted mt-2">
                  {item.sellerName} · {item.location || '—'}
                </p>
              </div>
              <div className="text-right shrink-0 space-y-2">
                <div className="font-semibold text-primary text-lg">
                  {item.price > 0 ? `${formatINR(item.price)} / ${item.unit}` : 'Requirement'}
                </div>
                <div className="text-sm text-muted">
                  Qty: {item.quantity} {item.unit}
                </div>
                <ActionButton
                  variant="danger"
                  busy={busyId === item.id}
                  onClick={async () => {
                    if (!confirm(`Delete listing “${item.title}”?`)) return
                    setBusyId(item.id)
                    setError(null)
                    try {
                      await deleteMarketplaceItem(item.id)
                      setOk('Listing deleted')
                      await load()
                    } catch (e) {
                      setError(e instanceof Error ? e.message : 'Delete failed')
                    } finally {
                      setBusyId(null)
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
