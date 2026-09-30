import { useState } from 'react'
import { AlertBanner, Card, PageHeader } from '@/components/ui/Primitives'
import { useAuth } from '@/context/AuthContext'
import { firebaseReady } from '@/lib/firebase'
import { ensurePPRates, findUserByPhone, setUserRole } from '@/services/adminApi'

export function SettingsPage() {
  const { adminUser, logout } = useAuth()
  const [phone, setPhone] = useState('')
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  const makeAdmin = async () => {
    setBusy(true)
    setError(null)
    setMessage(null)
    try {
      const user = await findUserByPhone(phone)
      if (!user) throw new Error('User not found. They must login in the app once first.')
      await setUserRole(user.id, 'admin')
      setMessage(`${user.name || user.phone} is now admin`)
      setPhone('')
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed')
    } finally {
      setBusy(false)
    }
  }

  const seedRates = async () => {
    setBusy(true)
    setError(null)
    setMessage(null)
    try {
      await ensurePPRates()
      setMessage('PP rate docs ready (virgin + recycled). Update values in PP Rates.')
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to seed rates')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div>
      <PageHeader title="Settings" subtitle="Admin account, invites and platform tools" />

      {error && (
        <div className="mb-4">
          <AlertBanner>{error}</AlertBanner>
        </div>
      )}
      {message && (
        <div className="mb-4">
          <AlertBanner tone="success">{message}</AlertBanner>
        </div>
      )}

      <div className="grid lg:grid-cols-2 gap-4">
        <Card className="p-6 space-y-3 text-sm">
          <h2 className="font-display font-semibold text-lg">Signed-in admin</h2>
          <div>
            <div className="text-muted">Name</div>
            <div className="font-medium">{adminUser?.name || '—'}</div>
          </div>
          <div>
            <div className="text-muted">Phone</div>
            <div className="font-medium">{adminUser?.phone}</div>
          </div>
          <div>
            <div className="text-muted">Role</div>
            <div className="font-medium">{adminUser?.role}</div>
          </div>
          <button
            onClick={() => void logout()}
            className="mt-2 rounded-xl bg-sidebar text-white px-4 py-2.5 font-medium"
          >
            Logout
          </button>
        </Card>

        <Card className="p-6 space-y-3 text-sm">
          <h2 className="font-display font-semibold text-lg">Firebase</h2>
          <div>
            <div className="text-muted">Project</div>
            <div className="font-medium">{import.meta.env.VITE_FIREBASE_PROJECT_ID}</div>
          </div>
          <div>
            <div className="text-muted">Web config</div>
            <div className="font-medium">
              {firebaseReady ? 'Connected to bagmandi' : 'Missing .env values'}
            </div>
          </div>
          <div>
            <div className="text-muted">Admin URL</div>
            <div className="font-medium break-all">https://admin.bagmandi.com</div>
          </div>
          <button
            disabled={busy}
            onClick={() => void seedRates()}
            className="rounded-xl border border-border px-4 py-2.5 font-medium hover:bg-bg disabled:opacity-50"
          >
            {busy ? 'Working…' : 'Seed PP rate documents'}
          </button>
        </Card>

        <Card className="p-6 space-y-3 text-sm lg:col-span-2">
          <h2 className="font-display font-semibold text-lg">Make another admin</h2>
          <p className="text-muted">
            User must already exist in Firestore (logged into the app at least once).
          </p>
          <div className="flex flex-col sm:flex-row gap-3 max-w-lg">
            <div className="flex flex-1 rounded-xl border border-border overflow-hidden">
              <span className="px-3 grid place-items-center bg-bg text-muted border-r border-border">
                +91
              </span>
              <input
                value={phone}
                onChange={(e) => setPhone(e.target.value.replace(/\D/g, '').slice(0, 10))}
                placeholder="10-digit mobile"
                className="flex-1 px-3 py-2.5 outline-none"
              />
            </div>
            <button
              disabled={busy || phone.length !== 10}
              onClick={() => void makeAdmin()}
              className="rounded-xl bg-primary text-white px-5 py-2.5 font-medium disabled:opacity-50"
            >
              {busy ? 'Saving…' : 'Make admin'}
            </button>
          </div>
        </Card>
      </div>
    </div>
  )
}
