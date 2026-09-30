import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import {
  LayoutDashboard,
  Users,
  Factory,
  Package,
  MessageSquareText,
  FileText,
  ShoppingCart,
  Store,
  Bell,
  Image,
  Settings,
  LogOut,
  Menu,
  X,
} from 'lucide-react'
import { useState } from 'react'
import { BrandLogo } from '@/components/BrandLogo'
import { useAuth } from '@/context/AuthContext'

const nav = [
  { to: '/', label: 'Dashboard', icon: LayoutDashboard, end: true },
  { to: '/users', label: 'Users', icon: Users },
  { to: '/manufacturers', label: 'Manufacturers', icon: Factory },
  { to: '/enquiries', label: 'Enquiries', icon: MessageSquareText },
  { to: '/quotes', label: 'Quotes', icon: FileText },
  { to: '/orders', label: 'Orders', icon: ShoppingCart },
  { to: '/marketplace', label: 'Marketplace', icon: Store },
  { to: '/products', label: 'Products', icon: Package },
  { to: '/market', label: 'PP Rates', icon: Store },
  { to: '/notifications', label: 'Notifications', icon: Bell },
  { to: '/banners', label: 'Banners', icon: Image },
  { to: '/settings', label: 'Settings', icon: Settings },
]

export function AdminLayout() {
  const { adminUser, logout } = useAuth()
  const navigate = useNavigate()
  const [open, setOpen] = useState(false)

  const onLogout = async () => {
    await logout()
    navigate('/login')
  }

  return (
    <div className="min-h-screen bg-bg flex">
      <aside
        className={`fixed inset-y-0 left-0 z-40 w-64 bg-sidebar text-white transition-transform lg:static lg:translate-x-0 ${
          open ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        <div className="h-16 px-5 flex items-center gap-3 border-b border-white/10">
          <BrandLogo size={36} className="bg-white" />
          <div>
            <div className="font-display font-semibold tracking-tight">BagMandi</div>
            <div className="text-[11px] text-white/50">Admin Panel</div>
          </div>
          <button className="ml-auto lg:hidden" onClick={() => setOpen(false)} aria-label="Close menu">
            <X size={18} />
          </button>
        </div>

        <nav className="p-3 space-y-1 overflow-y-auto max-h-[calc(100vh-8.5rem)]">
          {nav.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              onClick={() => setOpen(false)}
              className={({ isActive }) =>
                `flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition ${
                  isActive
                    ? 'bg-primary text-white'
                    : 'text-white/70 hover:bg-sidebar-hover hover:text-white'
                }`
              }
            >
              <item.icon size={18} />
              {item.label}
            </NavLink>
          ))}
        </nav>

        <div className="absolute bottom-0 inset-x-0 p-3 border-t border-white/10 bg-sidebar">
          <div className="px-3 py-2 mb-2">
            <div className="text-sm font-medium truncate">{adminUser?.name || 'Admin'}</div>
            <div className="text-xs text-white/50 truncate">{adminUser?.phone}</div>
          </div>
          <button
            onClick={onLogout}
            className="w-full flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm text-white/70 hover:bg-white/5 hover:text-white"
          >
            <LogOut size={18} />
            Logout
          </button>
        </div>
      </aside>

      {open && (
        <button
          className="fixed inset-0 z-30 bg-black/40 lg:hidden"
          onClick={() => setOpen(false)}
          aria-label="Close overlay"
        />
      )}

      <div className="flex-1 min-w-0 flex flex-col">
        <header className="h-16 bg-surface border-b border-border px-4 lg:px-8 flex items-center gap-3">
          <button className="lg:hidden p-2 rounded-lg hover:bg-bg" onClick={() => setOpen(true)}>
            <Menu size={20} />
          </button>
          <div className="font-display font-semibold text-lg">Admin Console</div>
        </header>
        <main className="flex-1 p-4 lg:p-8 overflow-auto">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
