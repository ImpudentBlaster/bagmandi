import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { Card, EmptyState, LoadingBlock, PageHeader } from '@/components/ui/Primitives'
import { formatDate, formatINR } from '@/lib/mappers'
import { deleteMarketplaceItem, fetchMarketplace } from '@/services/adminApi'
import type { MarketplaceItem } from '@/types'

export function DeadStockPage() {
  const [items, setItems] = useState<MarketplaceItem[]>([])
  const [loading, setLoading] = useState(true)

  const load = async () => {
    setLoading(true)
    try {
      setItems(await fetchMarketplace('Dead Stock'))
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void load()
  }, [])

  return (
    <div>
      <PageHeader
        title="Dead Stock"
        subtitle="Excess inventory listings — full marketplace moderation is under Marketplace"
        action={
          <Link
            to="/marketplace"
            className="rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:opacity-90"
          >
            Open Marketplace
          </Link>
        }
      />
      {loading ? (
        <LoadingBlock />
      ) : items.length === 0 ? (
        <Card>
          <EmptyState title="No dead stock listings" hint="Manufacturer posts will show here" />
        </Card>
      ) : (
        <div className="space-y-3">
          {items.map((item) => (
            <Card
              key={item.id}
              className="p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-3"
            >
              <div>
                <div className="font-display font-semibold text-lg">{item.title}</div>
                <p className="text-sm text-muted mt-1">{item.description}</p>
                <p className="text-sm text-muted mt-2">
                  {item.sellerName} · {item.location} · {formatDate(item.createdAt)}
                </p>
              </div>
              <div className="text-right space-y-2">
                <div className="font-semibold text-primary text-lg">
                  {formatINR(item.price)} / {item.unit}
                </div>
                <div className="text-sm text-muted">
                  Qty: {item.quantity} {item.unit}
                </div>
                <button
                  className="rounded-lg border border-error/30 px-3 py-1.5 text-sm text-error hover:bg-red-50"
                  onClick={async () => {
                    if (!confirm('Remove this listing?')) return
                    await deleteMarketplaceItem(item.id)
                    await load()
                  }}
                >
                  Remove
                </button>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  )
}
