import { useEffect, useState } from 'react'
import {
  ActionButton,
  AlertBanner,
  Card,
  EmptyState,
  LoadingBlock,
  PageHeader,
  StatusBadge,
} from '@/components/ui/Primitives'
import { formatDate } from '@/lib/mappers'
import {
  createBanner,
  deleteBanner,
  fetchBanners,
  setBannerActive,
} from '@/services/adminApi'
import type { Banner } from '@/types'

export function BannersPage() {
  const [items, setItems] = useState<Banner[]>([])
  const [loading, setLoading] = useState(true)
  const [title, setTitle] = useState('')
  const [imageUrl, setImageUrl] = useState('')
  const [link, setLink] = useState('')
  const [saving, setSaving] = useState(false)
  const [busyId, setBusyId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [ok, setOk] = useState<string | null>(null)

  const load = async () => {
    setLoading(true)
    setError(null)
    try {
      setItems(await fetchBanners())
    } catch (e) {
      setError(
        e instanceof Error
          ? e.message
          : 'Could not load banners. Ensure Firestore banners rules are deployed.',
      )
      setItems([])
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void load()
  }, [])

  const onCreate = async (e: React.FormEvent) => {
    e.preventDefault()
    setSaving(true)
    setError(null)
    setOk(null)
    try {
      await createBanner({ title, imageUrl, link })
      setTitle('')
      setImageUrl('')
      setLink('')
      setOk('Banner created')
      await load()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create banner')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div>
      <PageHeader title="Banners" subtitle="Promotional banners CMS (store image URL)" />

      <Card className="p-5 mb-6">
        <h2 className="font-display font-semibold mb-4">Add banner</h2>
        <form onSubmit={onCreate} className="grid md:grid-cols-3 gap-3">
          <input
            required
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Title"
            className="rounded-xl border border-border px-3 py-2.5 outline-none focus:ring-2 focus:ring-primary/25"
          />
          <input
            required
            value={imageUrl}
            onChange={(e) => setImageUrl(e.target.value)}
            placeholder="Image URL"
            className="rounded-xl border border-border px-3 py-2.5 outline-none focus:ring-2 focus:ring-primary/25"
          />
          <input
            value={link}
            onChange={(e) => setLink(e.target.value)}
            placeholder="Link (optional)"
            className="rounded-xl border border-border px-3 py-2.5 outline-none focus:ring-2 focus:ring-primary/25"
          />
          <button
            type="submit"
            disabled={saving}
            className="md:col-span-3 rounded-xl bg-primary text-white py-2.5 font-medium disabled:opacity-50"
          >
            {saving ? 'Saving…' : 'Create banner'}
          </button>
        </form>
        {error && (
          <div className="mt-3">
            <AlertBanner>{error}</AlertBanner>
          </div>
        )}
        {ok && (
          <div className="mt-3">
            <AlertBanner tone="success">{ok}</AlertBanner>
          </div>
        )}
      </Card>

      {loading ? (
        <LoadingBlock />
      ) : items.length === 0 ? (
        <Card>
          <EmptyState title="No banners yet" hint="Add your first promotional banner above" />
        </Card>
      ) : (
        <div className="space-y-3">
          {items.map((b) => (
            <Card key={b.id} className="p-4 flex flex-col sm:flex-row gap-4 sm:items-center">
              {b.imageUrl ? (
                <img
                  src={b.imageUrl}
                  alt={b.title}
                  className="h-20 w-36 object-cover rounded-lg border border-border bg-bg"
                />
              ) : (
                <div className="h-20 w-36 rounded-lg bg-bg border border-border" />
              )}
              <div className="flex-1 min-w-0">
                <div className="font-medium">{b.title}</div>
                <div className="text-sm text-muted truncate">{b.link || 'No link'}</div>
                <div className="mt-2 flex gap-2 items-center">
                  <StatusBadge status={b.isActive ? 'active' : 'inactive'} />
                  <span className="text-xs text-muted">{formatDate(b.createdAt)}</span>
                </div>
              </div>
              <div className="flex flex-wrap gap-2">
                <ActionButton
                  busy={busyId === b.id}
                  onClick={async () => {
                    setBusyId(b.id)
                    setError(null)
                    try {
                      await setBannerActive(b.id, !b.isActive)
                      setOk(b.isActive ? 'Banner disabled' : 'Banner enabled')
                      await load()
                    } catch (e) {
                      setError(e instanceof Error ? e.message : 'Update failed')
                    } finally {
                      setBusyId(null)
                    }
                  }}
                >
                  {b.isActive ? 'Disable' : 'Enable'}
                </ActionButton>
                <ActionButton
                  variant="danger"
                  busy={busyId === b.id}
                  onClick={async () => {
                    if (!confirm(`Delete banner “${b.title}”?`)) return
                    setBusyId(b.id)
                    setError(null)
                    try {
                      await deleteBanner(b.id)
                      setOk('Banner deleted')
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
