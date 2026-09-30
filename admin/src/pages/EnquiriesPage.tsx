import { useEffect, useState } from 'react'
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
import {
  fetchEnquiries,
  fetchQuotesForEnquiry,
  updateEnquiryStatus,
} from '@/services/adminApi'
import type { Enquiry, EnquiryStatus, Quote } from '@/types'

const filters = [
  { id: 'all', label: 'All' },
  { id: 'open', label: 'Open' },
  { id: 'quoted', label: 'Quoted' },
  { id: 'closed', label: 'Closed' },
]

export function EnquiriesPage() {
  const [filter, setFilter] = useState('all')
  const [items, setItems] = useState<Enquiry[]>([])
  const [loading, setLoading] = useState(true)
  const [selected, setSelected] = useState<Enquiry | null>(null)
  const [quotes, setQuotes] = useState<Quote[]>([])
  const [quotesLoading, setQuotesLoading] = useState(false)
  const [busyId, setBusyId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [ok, setOk] = useState<string | null>(null)

  const load = async () => {
    setLoading(true)
    setError(null)
    try {
      setItems(await fetchEnquiries(filter as EnquiryStatus | 'all'))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load enquiries')
      setItems([])
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void load()
  }, [filter])

  const openDetail = async (enq: Enquiry) => {
    setSelected(enq)
    setQuotesLoading(true)
    try {
      setQuotes(await fetchQuotesForEnquiry(enq.id))
    } catch {
      setQuotes([])
    } finally {
      setQuotesLoading(false)
    }
  }

  return (
    <div>
      <PageHeader title="Enquiry Management" subtitle="Monitor buyer requirements and quote activity" />

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

      {loading ? (
        <LoadingBlock />
      ) : items.length === 0 ? (
        <Card>
          <EmptyState title="No enquiries" hint="New buyer requirements will appear here" />
        </Card>
      ) : (
        <div className="space-y-3">
          {items.map((enq) => (
            <Card key={enq.id} className="p-5">
              <div className="flex flex-col lg:flex-row lg:items-start justify-between gap-4">
                <div>
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="text-xs font-medium text-muted">
                      REQ #{shortId(enq.id)}
                    </span>
                    <StatusBadge status={enq.status} />
                  </div>
                  <h3 className="mt-2 font-display text-lg font-semibold">{enq.bagType}</h3>
                  <p className="text-sm text-muted mt-1">
                    {enq.buyerName} · {enq.deliveryLocation}
                  </p>
                  <div className="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-sm text-muted">
                    <span>Size: {enq.size}</span>
                    <span>GSM: {enq.gsm}</span>
                    <span>Color: {enq.color}</span>
                    <span>Printing: {enq.printing}</span>
                    <span>Qty: {enq.quantityKg} KG</span>
                    <span>Date: {formatDate(enq.createdAt)}</span>
                    <span>Quotes: {enq.quoteCount}</span>
                  </div>
                </div>
                <div className="flex flex-wrap gap-2">
                  <ActionButton onClick={() => openDetail(enq)}>View quotes</ActionButton>
                  {(['open', 'quoted', 'closed'] as EnquiryStatus[]).map((s) => (
                    <ActionButton
                      key={s}
                      disabled={enq.status === s}
                      busy={busyId === enq.id}
                      onClick={async () => {
                        setBusyId(enq.id)
                        setError(null)
                        setOk(null)
                        try {
                          await updateEnquiryStatus(enq.id, s)
                          setOk(`Enquiry marked ${s}`)
                          await load()
                        } catch (e) {
                          setError(e instanceof Error ? e.message : 'Status update failed')
                        } finally {
                          setBusyId(null)
                        }
                      }}
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

      {selected && (
        <div className="fixed inset-0 z-50 bg-black/40 grid place-items-center p-4">
          <Card className="w-full max-w-2xl p-6 max-h-[85vh] overflow-auto">
            <div className="flex items-start justify-between gap-3">
              <div>
                <h3 className="font-display text-xl font-semibold">{selected.bagType}</h3>
                <p className="text-sm text-muted">
                  {selected.buyerName} · REQ #{shortId(selected.id)}
                </p>
              </div>
              <button className="text-muted" onClick={() => setSelected(null)}>
                Close
              </button>
            </div>
            {selected.additionalNotes && (
              <p className="mt-3 text-sm rounded-xl bg-bg p-3">{selected.additionalNotes}</p>
            )}
            <h4 className="mt-5 font-semibold">Quotes ({quotes.length})</h4>
            {quotesLoading ? (
              <LoadingBlock />
            ) : quotes.length === 0 ? (
              <p className="text-sm text-muted mt-2">No quotes yet</p>
            ) : (
              <div className="mt-3 space-y-3">
                {quotes.map((q) => (
                  <div key={q.id} className="rounded-xl border border-border p-3">
                    <div className="flex items-center justify-between gap-2">
                      <div className="font-medium">{q.manufacturerName}</div>
                      <StatusBadge status={q.status} />
                    </div>
                    <p className="text-sm text-muted mt-1">
                      {formatINR(q.totalApprox)} · {q.deliveryDays} days · {q.paymentTerms}
                    </p>
                    <p className="text-xs text-muted mt-1">{formatDate(q.createdAt, true)}</p>
                  </div>
                ))}
              </div>
            )}
          </Card>
        </div>
      )}
    </div>
  )
}
