import { useEffect, useMemo, useState } from 'react'
import {
  ActionButton,
  AlertBanner,
  Card,
  EmptyState,
  LoadingBlock,
  PageHeader,
} from '@/components/ui/Primitives'
import { fetchUsers, productCategories, setUserProducts } from '@/services/adminApi'
import type { AppUser } from '@/types'

export function ProductsPage() {
  const [makers, setMakers] = useState<AppUser[]>([])
  const [loading, setLoading] = useState(true)
  const [selected, setSelected] = useState<AppUser | null>(null)
  const [editProducts, setEditProducts] = useState<string[]>([])
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [ok, setOk] = useState<string | null>(null)
  const categories = productCategories()

  const load = async () => {
    setLoading(true)
    setError(null)
    try {
      setMakers(await fetchUsers('manufacturer'))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load')
      setMakers([])
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void load()
  }, [])

  const counts = useMemo(() => {
    const map: Record<string, number> = Object.fromEntries(categories.map((c) => [c, 0]))
    for (const m of makers) {
      for (const p of m.products) {
        map[p] = (map[p] ?? 0) + 1
      }
    }
    return map
  }, [makers, categories])

  const makersForCategory = (cat: string) =>
    makers.filter((m) => m.products.includes(cat))

  const saveProducts = async () => {
    if (!selected) return
    setBusy(true)
    setError(null)
    setOk(null)
    try {
      await setUserProducts(selected.id, editProducts)
      setOk('Products saved')
      setSelected(null)
      await load()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Save failed')
    } finally {
      setBusy(false)
    }
  }

  if (loading) return <LoadingBlock />

  return (
    <div>
      <PageHeader
        title="Products"
        subtitle="Manage bag categories offered by each manufacturer"
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

      <div className="grid sm:grid-cols-2 xl:grid-cols-3 gap-4 mb-8">
        {Object.entries(counts).map(([name, count]) => (
          <Card key={name} className="p-5">
            <div className="text-sm text-muted">Category</div>
            <div className="mt-1 font-display text-xl font-semibold">{name}</div>
            <div className="mt-4 text-sm">
              <span className="font-semibold text-primary">{count}</span> manufacturers
            </div>
            {makersForCategory(name).length > 0 && (
              <ul className="mt-3 space-y-1 text-xs text-muted">
                {makersForCategory(name)
                  .slice(0, 4)
                  .map((m) => (
                    <li key={m.id}>{m.businessName || m.name || m.phone}</li>
                  ))}
              </ul>
            )}
          </Card>
        ))}
      </div>

      <h2 className="font-display font-semibold text-lg mb-3">Edit manufacturer products</h2>
      {makers.length === 0 ? (
        <Card>
          <EmptyState title="No manufacturers" />
        </Card>
      ) : (
        <div className="space-y-3">
          {makers.map((m) => (
            <Card key={m.id} className="p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <div className="font-medium">{m.businessName || m.name || 'Unnamed'}</div>
                <div className="text-sm text-muted mt-1">
                  {m.products.length ? m.products.join(', ') : 'No products set'}
                </div>
              </div>
              <ActionButton
                onClick={() => {
                  setSelected(m)
                  setEditProducts(m.products)
                }}
              >
                Edit products
              </ActionButton>
            </Card>
          ))}
        </div>
      )}

      {selected && (
        <div className="fixed inset-0 z-50 bg-black/40 grid place-items-center p-4">
          <Card className="w-full max-w-lg p-6">
            <div className="flex justify-between gap-3">
              <h3 className="font-display text-xl font-semibold">
                {selected.businessName || selected.name}
              </h3>
              <button className="text-muted" onClick={() => setSelected(null)}>
                Close
              </button>
            </div>
            <div className="mt-4 flex flex-wrap gap-2">
              {categories.map((cat) => {
                const on = editProducts.includes(cat)
                return (
                  <button
                    key={cat}
                    type="button"
                    onClick={() =>
                      setEditProducts((prev) =>
                        on ? prev.filter((p) => p !== cat) : [...prev, cat],
                      )
                    }
                    className={`rounded-full px-3 py-1.5 text-xs font-medium border ${
                      on
                        ? 'bg-primary text-white border-primary'
                        : 'border-border text-muted hover:bg-bg'
                    }`}
                  >
                    {cat}
                  </button>
                )
              })}
            </div>
            <div className="mt-5">
              <ActionButton busy={busy} variant="primary" onClick={saveProducts}>
                Save products
              </ActionButton>
            </div>
          </Card>
        </div>
      )}
    </div>
  )
}
