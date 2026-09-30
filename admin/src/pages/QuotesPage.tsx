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
import { acceptQuoteAsAdmin, fetchQuotes, updateQuoteStatus } from '@/services/adminApi'
import type { Quote, QuoteStatus } from '@/types'

const filters = [
  { id: 'all', label: 'All' },
  { id: 'pending', label: 'Pending' },
  { id: 'accepted', label: 'Accepted' },
  { id: 'rejected', label: 'Rejected' },
]

export function QuotesPage() {
  const [filter, setFilter] = useState('all')
  const [items, setItems] = useState<Quote[]>([])
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [busyId, setBusyId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [ok, setOk] = useState<string | null>(null)

  const load = async () => {
    setLoading(true)
    setError(null)
    try {
      setItems(await fetchQuotes(filter as QuoteStatus | 'all'))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load quotes')
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
    return items.filter((x) =>
      [x.manufacturerName, x.enquiryId, x.id].join(' ').toLowerCase().includes(q),
    )
  }, [items, search])

  const onStatus = async (q: Quote, status: QuoteStatus) => {
    setBusyId(q.id)
    setError(null)
    setOk(null)
    try {
      if (status === 'accepted') {
        if (!confirm(`Accept quote from ${q.manufacturerName}? This creates an order and closes the enquiry.`)) {
          return
        }
        const orderId = await acceptQuoteAsAdmin(q.id)
        setOk(`Quote accepted · Order ${orderId} created`)
      } else {
        await updateQuoteStatus(q.id, status)
        setOk(`Quote marked ${status}`)
      }
      await load()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Action failed')
    } finally {
      setBusyId(null)
    }
  }

  return (
    <div>
      <PageHeader
        title="Quotes"
        subtitle="Accepting a quote creates an order (same as the mobile app)"
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
          placeholder="Search manufacturer or enquiry…"
          className="w-full rounded-xl border border-border px-4 py-3 outline-none focus:ring-2 focus:ring-primary/25"
        />
      </Card>

      {loading ? (
        <LoadingBlock />
      ) : filtered.length === 0 ? (
        <Card>
          <EmptyState title="No quotes" hint="Quotes appear after manufacturers respond" />
        </Card>
      ) : (
        <div className="space-y-3">
          {filtered.map((q) => (
            <Card key={q.id} className="p-5">
              <div className="flex flex-col lg:flex-row lg:items-start justify-between gap-4">
                <div>
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="text-xs font-medium text-muted">QT #{shortId(q.id)}</span>
                    <StatusBadge status={q.status} />
                  </div>
                  <h3 className="mt-2 font-display text-lg font-semibold">{q.manufacturerName}</h3>
                  <p className="text-sm text-muted mt-1">
                    Enquiry #{shortId(q.enquiryId)} · {formatDate(q.createdAt, true)}
                  </p>
                  <div className="mt-3 grid sm:grid-cols-2 lg:grid-cols-3 gap-x-6 gap-y-1 text-sm text-muted">
                    <span>Bag: {formatINR(q.bagPricePerKg)}/KG</span>
                    <span>Printing: {formatINR(q.printingPricePerKg)}/KG</span>
                    <span>GST: {q.gstPercent}%</span>
                    <span>Transport: {formatINR(q.transportCharges)}</span>
                    <span>Delivery: {q.deliveryDays} days</span>
                    <span>Terms: {q.paymentTerms}</span>
                  </div>
                  <p className="mt-3 text-xl font-semibold text-primary">
                    Total ~ {formatINR(q.totalApprox)}
                  </p>
                </div>
                <div className="flex flex-wrap gap-2">
                  {(['pending', 'accepted', 'rejected'] as QuoteStatus[]).map((s) => (
                    <ActionButton
                      key={s}
                      disabled={q.status === s}
                      busy={busyId === q.id}
                      variant={s === 'accepted' ? 'primary' : s === 'rejected' ? 'danger' : 'default'}
                      onClick={() => onStatus(q, s)}
                    >
                      Mark {s}
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
