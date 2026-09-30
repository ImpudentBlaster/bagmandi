import type { ReactNode } from 'react'

export function PageHeader({
  title,
  subtitle,
  action,
}: {
  title: string
  subtitle?: string
  action?: ReactNode
}) {
  return (
    <div className="mb-6 flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3">
      <div>
        <h1 className="font-display text-2xl font-semibold tracking-tight">{title}</h1>
        {subtitle && <p className="mt-1 text-sm text-muted">{subtitle}</p>}
      </div>
      {action}
    </div>
  )
}

export function Card({ children, className = '' }: { children: ReactNode; className?: string }) {
  return (
    <div className={`bg-surface rounded-2xl border border-border shadow-[0_4px_16px_rgba(0,0,0,0.04)] ${className}`}>
      {children}
    </div>
  )
}

export function StatCard({
  label,
  value,
  accent = 'primary',
}: {
  label: string
  value: string | number
  accent?: 'primary' | 'info' | 'warning' | 'purple'
}) {
  const accents = {
    primary: 'bg-primary-light text-primary',
    info: 'bg-blue-50 text-info',
    warning: 'bg-amber-50 text-warning',
    purple: 'bg-violet-50 text-[#4C4B9E]',
  }
  return (
    <Card className="p-5">
      <div className={`inline-flex text-xs font-medium px-2.5 py-1 rounded-full ${accents[accent]}`}>
        {label}
      </div>
      <div className="mt-4 font-display text-3xl font-semibold tabular-nums">{value}</div>
    </Card>
  )
}

export function StatusBadge({ status }: { status: string }) {
  const map: Record<string, string> = {
    open: 'bg-blue-50 text-info',
    quoted: 'bg-primary-light text-primary',
    closed: 'bg-gray-100 text-muted',
    rejected: 'bg-red-50 text-error',
    pending: 'bg-amber-50 text-warning',
    accepted: 'bg-primary-light text-primary',
    verified: 'bg-primary-light text-primary',
    active: 'bg-primary-light text-primary',
    inactive: 'bg-gray-100 text-muted',
    confirmed: 'bg-blue-50 text-info',
    ongoing: 'bg-amber-50 text-warning',
    completed: 'bg-primary-light text-primary',
    cancelled: 'bg-red-50 text-error',
    broadcast: 'bg-violet-50 text-[#4C4B9E]',
    admin: 'bg-gray-100 text-muted',
  }
  const cls = map[status.toLowerCase()] ?? 'bg-gray-100 text-muted'
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium capitalize ${cls}`}>
      {status}
    </span>
  )
}

export function Tabs({
  items,
  value,
  onChange,
}: {
  items: { id: string; label: string }[]
  value: string
  onChange: (id: string) => void
}) {
  return (
    <div className="flex flex-wrap gap-2">
      {items.map((item) => (
        <button
          key={item.id}
          onClick={() => onChange(item.id)}
          className={`rounded-full px-4 py-2 text-sm font-medium transition ${
            value === item.id
              ? 'bg-primary text-white'
              : 'bg-surface border border-border text-muted hover:text-text'
          }`}
        >
          {item.label}
        </button>
      ))}
    </div>
  )
}

export function EmptyState({ title, hint }: { title: string; hint?: string }) {
  return (
    <div className="py-16 text-center">
      <div className="font-medium text-text">{title}</div>
      {hint && <p className="mt-1 text-sm text-muted">{hint}</p>}
    </div>
  )
}

export function LoadingBlock() {
  return (
    <div className="py-20 text-center text-muted text-sm">Loading…</div>
  )
}

export function AlertBanner({
  tone = 'error',
  children,
}: {
  tone?: 'error' | 'success' | 'info'
  children: ReactNode
}) {
  const cls =
    tone === 'success'
      ? 'bg-primary/10 text-primary'
      : tone === 'info'
        ? 'bg-blue-50 text-info'
        : 'bg-error/10 text-error'
  return <div className={`rounded-xl px-4 py-3 text-sm ${cls}`}>{children}</div>
}

export function ActionButton({
  children,
  onClick,
  variant = 'default',
  disabled,
  busy,
}: {
  children: ReactNode
  onClick: () => void | Promise<void>
  variant?: 'default' | 'primary' | 'danger'
  disabled?: boolean
  busy?: boolean
}) {
  const styles = {
    default: 'border border-border hover:bg-bg',
    primary: 'bg-primary text-white hover:bg-primary/90 border border-transparent',
    danger: 'border border-red-200 text-error hover:bg-red-50',
  }
  return (
    <button
      type="button"
      disabled={disabled || busy}
      onClick={() => void onClick()}
      className={`rounded-lg px-3 py-2 text-sm capitalize disabled:opacity-40 ${styles[variant]}`}
    >
      {busy ? '…' : children}
    </button>
  )
}
