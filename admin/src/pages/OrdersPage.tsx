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
import { formatDate, formatINR, shortId } from '@/lib/mappers'
import { fetchOrders, sendNotification, updateOrderStatus } from '@/services/adminApi'
import type { Order, OrderStatus } from '@/types'

const filters = [
  { id: 'all', label: 'All' },
  { id: 'confirmed', label: 'Confirmed' },
  { id: 'ongoing', label: 'Ongoing' },
  { id: 'completed', label: 'Completed' },
  { id: 'cancelled', label: 'Cancelled' },
]

export function OrdersPage() {
  const [filter, setFilter] = useState('all')
  const [items, setItems] = useState<Order[]>([])
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [busyId, setBusyId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [ok, setOk] = useState<string | null>(null)

  const load = async () => {
    setLoading(true)
    setError(null)
    try {
      setItems(await fetchOrders(filter as OrderStatus | 'all'))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load orders')
      setItems([])
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void load()
  }, [filter])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return items
    return items.filter((o) =>
      [o.buyerName, o.manufacturerName, o.id, o.enquiryId]
        .join(' ')
        .toLowerCase()
        .includes(q),
    )
  }, [items, search])

  const totalValue = filtered.reduce((s, o) => s + o.totalAmount, 0)

  const onStatus = async (o: Order, status: OrderStatus) => {
    if (status === 'cancelled' && !confirm(`Cancel order ${o.id}?`)) return
    setBusyId(o.id)
    setError(null)
    setOk(null)
    try {
      await updateOrderStatus(o.id, status)
      await Promise.all([
        sendNotification({
          userId: o.buyerId,
          title: `Order ${status}`,
          body: `Order ${o.id} is now ${status}.`,
          type: 'order',
          refId: o.id,
        }),
        sendNotification({
          userId: o.manufacturerId,
          title: `Order ${status}`,
          body: `Order ${o.id} is now ${status}.`,
          type: 'order',
          refId: o.id,
        }),
      ])
      setOk(`Order marked ${status}`)
      await load()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to update order')
    } finally {
      setBusyId(null)
    }
  }

  return (
    <div>
      <PageHeader
        title="Orders"
        subtitle="Track confirmed deals between buyers and manufacturers"
        action={
          <div className="text-sm text-muted">
            Showing <span className="font-semibold text-ink">{filtered.length}</span> ·{' '}
            <span className="font-semibold text-primary">{formatINR(totalValue)}</span>
          </div>
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
        <Tabs value={filter} onChange={setFilter} items={filters} />
      </div>

      <Card className="p-4 mb-4">
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search buyer, manufacturer, order id…"
          className="w-full rounded-xl border border-border px-4 py-3 outline-none focus:ring-2 focus:ring-primary/25"
        />
      </Card>

      {loading ? (
        <LoadingBlock />
      ) : filtered.length === 0 ? (
        <Card>
          <EmptyState title="No orders" hint="Accepted quotes become orders here" />
        </Card>
      ) : (
        <div className="space-y-3">
          {filtered.map((o) => (
            <Card key={o.id} className="p-5">
              <div className="flex flex-col lg:flex-row lg:items-start justify-between gap-4">
                <div>
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="text-xs font-medium text-muted">ORD #{shortId(o.id)}</span>
                    <StatusBadge status={o.status} />
                  </div>
                  <h3 className="mt-2 font-display text-lg font-semibold">
                    {o.buyerName} → {o.manufacturerName}
                  </h3>
                  <p className="text-sm text-muted mt-1">
                    Enquiry #{shortId(o.enquiryId)} · Quote #{shortId(o.quoteId)} ·{' '}
                    {formatDate(o.createdAt, true)}
                  </p>
                  <p className="mt-3 text-xl font-semibold text-primary">{formatINR(o.totalAmount)}</p>
                </div>
                <div className="flex flex-wrap gap-2">
                  {(['confirmed', 'ongoing', 'completed', 'cancelled'] as OrderStatus[]).map((s) => (
                    <ActionButton
                      key={s}
                      disabled={o.status === s}
                      busy={busyId === o.id}
                      variant={s === 'cancelled' ? 'danger' : s === 'completed' ? 'primary' : 'default'}
                      onClick={() => onStatus(o, s)}
                    >
                      {s}
                    </ActionButton>
                  ))}
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  )
}
