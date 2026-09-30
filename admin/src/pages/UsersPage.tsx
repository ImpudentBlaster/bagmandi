import { useEffect, useMemo, useState } from 'react'
import {
  ActionButton,
  AlertBanner,
  Card,
  EmptyState,
  LoadingBlock,
  PageHeader,
  StatusBadge,
} from '@/components/ui/Primitives'
import { formatDate, shortId } from '@/lib/mappers'
import {
  fetchUsers,
  fetchUsersByRoles,
  productCategories,
  sendNotification,
  setUserActive,
  setUserProducts,
  setUserVerified,
} from '@/services/adminApi'
import type { AppUser } from '@/types'

type PageRole = 'buyer' | 'manufacturer'

export function UsersPage({ lockedRole = 'buyer' }: { lockedRole?: PageRole }) {
  const [users, setUsers] = useState<AppUser[]>([])
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [selected, setSelected] = useState<AppUser | null>(null)
  const [busyId, setBusyId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [ok, setOk] = useState<string | null>(null)
  const [editProducts, setEditProducts] = useState<string[]>([])

  const isManufacturerPage = lockedRole === 'manufacturer'

  const load = async () => {
    setLoading(true)
    setError(null)
    try {
      if (isManufacturerPage) {
        setUsers(await fetchUsers('manufacturer'))
      } else {
        // End users only — never manufacturers/admins
        setUsers(await fetchUsersByRoles(['buyer', 'guest']))
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load users')
      setUsers([])
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void load()
  }, [lockedRole])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return users
    return users.filter((u) =>
      [u.businessName, u.name, u.phone, u.location, u.gstNumber, u.businessType, u.id]
        .filter(Boolean)
        .some((v) => String(v).toLowerCase().includes(q)),
    )
  }, [users, search])

  const run = async (uid: string, fn: () => Promise<void>, success: string) => {
    setBusyId(uid)
    setError(null)
    setOk(null)
    try {
      await fn()
      setOk(success)
      await load()
      if (selected?.id === uid) {
        const list = isManufacturerPage
          ? await fetchUsers('manufacturer')
          : await fetchUsersByRoles(['buyer', 'guest'])
        const refreshed = list.find((u) => u.id === uid)
        if (refreshed) {
          setSelected(refreshed)
          setEditProducts(refreshed.products)
        }
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Action failed'
      setError(
        msg.includes('permission') || msg.includes('Permission')
          ? 'Permission denied. Make sure you are logged in as an admin account (role: admin), then refresh.'
          : msg,
      )
    } finally {
      setBusyId(null)
    }
  }

  return (
    <div>
      <PageHeader
        title={isManufacturerPage ? 'Manufacturers / Vendors' : 'Users'}
        subtitle={
          isManufacturerPage
            ? 'Only manufacturer & vendor accounts — verify, enable, manage products'
            : 'Only buyer / end-user accounts'
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

      <Card className="p-4 mb-4">
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder={
            isManufacturerPage
              ? 'Search manufacturer, phone, GST, location…'
              : 'Search user name, phone, location…'
          }
          className="w-full rounded-xl border border-border px-4 py-3 outline-none focus:ring-2 focus:ring-primary/25"
        />
      </Card>

      {loading ? (
        <LoadingBlock />
      ) : (
        <Card className="divide-y divide-border">
          {filtered.length === 0 && (
            <EmptyState
              title={isManufacturerPage ? 'No manufacturers found' : 'No users found'}
            />
          )}
          {filtered.map((user) => (
            <div
              key={user.id}
              className="p-4 flex flex-col sm:flex-row sm:items-center gap-3 justify-between"
            >
              <div className="min-w-0">
                <div className="font-medium truncate">
                  {user.businessName || user.name || 'Unnamed'}
                </div>
                <div className="text-sm text-muted truncate">
                  {user.businessType ? `${user.businessType} · ` : ''}
                  {user.location || 'Location not set'} · {user.phone}
                </div>
                <div className="mt-2 flex flex-wrap gap-2">
                  <StatusBadge status={user.isVerified ? 'verified' : 'pending'} />
                  <StatusBadge status={user.isActive ? 'active' : 'inactive'} />
                </div>
              </div>
              <div className="flex flex-wrap gap-2">
                <ActionButton
                  onClick={() => {
                    setSelected(user)
                    setEditProducts(user.products)
                  }}
                >
                  View
                </ActionButton>
                {isManufacturerPage && (
                  <ActionButton
                    busy={busyId === user.id}
                    variant="primary"
                    onClick={() =>
                      run(
                        user.id,
                        () => setUserVerified(user.id, !user.isVerified),
                        user.isVerified ? 'Unverified' : 'Verified',
                      )
                    }
                  >
                    {user.isVerified ? 'Unverify' : 'Verify'}
                  </ActionButton>
                )}
                <ActionButton
                  busy={busyId === user.id}
                  variant={user.isActive ? 'danger' : 'default'}
                  onClick={() => {
                    if (
                      user.isActive &&
                      !confirm(`Disable ${user.businessName || user.name || user.phone}?`)
                    ) {
                      return
                    }
                    void run(
                      user.id,
                      () => setUserActive(user.id, !user.isActive),
                      user.isActive ? 'Disabled' : 'Enabled',
                    )
                  }}
                >
                  {user.isActive ? 'Disable' : 'Enable'}
                </ActionButton>
              </div>
            </div>
          ))}
        </Card>
      )}

      {selected && (
        <div className="fixed inset-0 z-50 bg-black/40 grid place-items-center p-4">
          <Card className="w-full max-w-lg p-6 max-h-[90vh] overflow-auto">
            <div className="flex items-start justify-between gap-3">
              <div>
                <h3 className="font-display text-xl font-semibold">
                  {selected.businessName || selected.name}
                </h3>
                <p className="text-sm text-muted">ID {shortId(selected.id)}</p>
              </div>
              <button className="text-muted" onClick={() => setSelected(null)}>
                Close
              </button>
            </div>
            <dl className="mt-5 grid grid-cols-2 gap-3 text-sm">
              <div>
                <dt className="text-muted">Phone</dt>
                <dd className="font-medium">{selected.phone}</dd>
              </div>
              <div>
                <dt className="text-muted">Role</dt>
                <dd className="font-medium capitalize">{selected.role}</dd>
              </div>
              <div>
                <dt className="text-muted">Contact</dt>
                <dd className="font-medium">{selected.contactNumber || selected.phone || '—'}</dd>
              </div>
              <div>
                <dt className="text-muted">Email</dt>
                <dd className="font-medium break-all">{selected.email || '—'}</dd>
              </div>
              <div>
                <dt className="text-muted">Business type</dt>
                <dd className="font-medium">{selected.businessType || '—'}</dd>
              </div>
              <div>
                <dt className="text-muted">Joined</dt>
                <dd className="font-medium">{formatDate(selected.createdAt)}</dd>
              </div>
              <div>
                <dt className="text-muted">GSTIN</dt>
                <dd className="font-medium">
                  {selected.gstNumber ||
                    (selected.gstType === 'Not Registered' ? 'No GST (skipped)' : '—')}
                </dd>
              </div>
              <div>
                <dt className="text-muted">GST type</dt>
                <dd className="font-medium">{selected.gstType || '—'}</dd>
              </div>
              <div className="col-span-2">
                <dt className="text-muted">Address</dt>
                <dd className="font-medium">
                  {[
                    selected.addressLine1,
                    selected.addressLine2,
                    selected.city,
                    selected.state,
                    selected.pincode,
                    selected.country,
                  ]
                    .filter(Boolean)
                    .join(', ') ||
                    selected.location ||
                    '—'}
                </dd>
              </div>
            </dl>

            {isManufacturerPage && (
              <div className="mt-5">
                <div className="text-sm font-medium mb-2">Products offered</div>
                <div className="flex flex-wrap gap-2">
                  {productCategories().map((cat) => {
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
                <div className="mt-3 flex flex-wrap gap-2">
                  <ActionButton
                    busy={busyId === selected.id}
                    variant="primary"
                    onClick={() =>
                      run(
                        selected.id,
                        () => setUserProducts(selected.id, editProducts),
                        'Products updated',
                      )
                    }
                  >
                    Save products
                  </ActionButton>
                  <ActionButton
                    busy={busyId === selected.id}
                    variant="primary"
                    onClick={() =>
                      run(
                        selected.id,
                        () => setUserVerified(selected.id, !selected.isVerified),
                        selected.isVerified ? 'Unverified' : 'Verified',
                      )
                    }
                  >
                    {selected.isVerified ? 'Unverify' : 'Verify'}
                  </ActionButton>
                </div>
              </div>
            )}

            <div className="mt-5 flex flex-wrap gap-2">
              <ActionButton
                busy={busyId === selected.id}
                onClick={() =>
                  run(
                    selected.id,
                    () =>
                      sendNotification({
                        userId: selected.id,
                        title: 'Message from BagMandi Admin',
                        body: 'Please check the BagMandi app for updates.',
                      }),
                    'Notification sent',
                  )
                }
              >
                Notify user
              </ActionButton>
            </div>
          </Card>
        </div>
      )}
    </div>
  )
}
