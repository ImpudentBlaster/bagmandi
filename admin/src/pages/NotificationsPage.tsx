import { useEffect, useState } from 'react'
import {
  Card,
  EmptyState,
  LoadingBlock,
  PageHeader,
  StatusBadge,
} from '@/components/ui/Primitives'
import { formatDate, shortId } from '@/lib/mappers'
import {
  broadcastNotification,
  fetchRecentNotifications,
  fetchUsers,
  sendNotification,
} from '@/services/adminApi'
import type { AdminNotification, AppUser } from '@/types'

export function NotificationsPage() {
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [audience, setAudience] = useState<'all' | 'buyer' | 'manufacturer' | 'user'>('all')
  const [userId, setUserId] = useState('')
  const [users, setUsers] = useState<AppUser[]>([])
  const [recent, setRecent] = useState<AdminNotification[]>([])
  const [loading, setLoading] = useState(true)
  const [sending, setSending] = useState(false)
  const [message, setMessage] = useState<string | null>(null)

  const load = async () => {
    setLoading(true)
    try {
      const [u, n] = await Promise.all([
        Promise.all([fetchUsers('buyer'), fetchUsers('manufacturer')]).then(([a, b]) => [...a, ...b]),
        fetchRecentNotifications(40),
      ])
      setUsers(u)
      setRecent(n)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void load()
  }, [])

  const onSend = async () => {
    if (!title.trim() || !body.trim()) {
      setMessage('Title and message are required')
      return
    }
    setSending(true)
    setMessage(null)
    try {
      if (audience === 'user') {
        if (!userId) {
          setMessage('Select a user')
          return
        }
        await sendNotification({ userId, title: title.trim(), body: body.trim() })
        setMessage('Notification sent to selected user')
      } else {
        const count = await broadcastNotification({
          title: title.trim(),
          body: body.trim(),
          role: audience,
        })
        setMessage(`Broadcast sent to ${count} users`)
      }
      setTitle('')
      setBody('')
      await load()
    } catch (e) {
      setMessage(e instanceof Error ? e.message : 'Failed to send')
    } finally {
      setSending(false)
    }
  }

  return (
    <div>
      <PageHeader
        title="Notifications"
        subtitle="Send alerts to buyers, manufacturers, or a specific user"
      />

      <div className="grid lg:grid-cols-2 gap-6">
        <Card className="p-5 space-y-4">
          <h3 className="font-display font-semibold text-lg">Compose</h3>
          <div>
            <label className="text-sm text-muted">Audience</label>
            <select
              value={audience}
              onChange={(e) => setAudience(e.target.value as typeof audience)}
              className="mt-1 w-full rounded-xl border border-border px-4 py-3 outline-none focus:ring-2 focus:ring-primary/25"
            >
              <option value="all">All buyers & manufacturers</option>
              <option value="buyer">Buyers only</option>
              <option value="manufacturer">Manufacturers only</option>
              <option value="user">Specific user</option>
            </select>
          </div>
          {audience === 'user' && (
            <div>
              <label className="text-sm text-muted">User</label>
              <select
                value={userId}
                onChange={(e) => setUserId(e.target.value)}
                className="mt-1 w-full rounded-xl border border-border px-4 py-3 outline-none focus:ring-2 focus:ring-primary/25"
              >
                <option value="">Select user…</option>
                {users.map((u) => (
                  <option key={u.id} value={u.id}>
                    {(u.businessName || u.name || 'User') + ` · ${u.phone} · ${u.role}`}
                  </option>
                ))}
              </select>
            </div>
          )}
          <div>
            <label className="text-sm text-muted">Title</label>
            <input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="mt-1 w-full rounded-xl border border-border px-4 py-3 outline-none focus:ring-2 focus:ring-primary/25"
              placeholder="e.g. PP rate update"
            />
          </div>
          <div>
            <label className="text-sm text-muted">Message</label>
            <textarea
              value={body}
              onChange={(e) => setBody(e.target.value)}
              rows={4}
              className="mt-1 w-full rounded-xl border border-border px-4 py-3 outline-none focus:ring-2 focus:ring-primary/25"
              placeholder="Write the notification body…"
            />
          </div>
          {message && <p className="text-sm text-primary font-medium">{message}</p>}
          <button
            disabled={sending}
            onClick={() => void onSend()}
            className="rounded-xl bg-primary text-white px-4 py-3 text-sm font-medium hover:bg-primary/90 disabled:opacity-50"
          >
            {sending ? 'Sending…' : 'Send notification'}
          </button>
        </Card>

        <Card className="p-5">
          <h3 className="font-display font-semibold text-lg mb-4">Recent</h3>
          {loading ? (
            <LoadingBlock />
          ) : recent.length === 0 ? (
            <EmptyState title="No notifications yet" />
          ) : (
            <div className="space-y-3 max-h-[560px] overflow-auto">
              {recent.map((n) => (
                <div key={n.id} className="rounded-xl border border-border p-3">
                  <div className="flex items-center justify-between gap-2">
                    <div className="font-medium">{n.title}</div>
                    <StatusBadge status={n.type} />
                  </div>
                  <p className="text-sm text-muted mt-1">{n.body}</p>
                  <p className="text-xs text-muted mt-2">
                    User #{shortId(n.userId)} · {formatDate(n.createdAt, true)}
                  </p>
                </div>
              ))}
            </div>
          )}
        </Card>
      </div>
    </div>
  )
}
