import { Navigate, Outlet, Route, Routes } from 'react-router-dom'
import { AdminLayout } from '@/components/layout/AdminLayout'
import { useAuth } from '@/context/AuthContext'
import { BannersPage } from '@/pages/BannersPage'
import { DashboardPage } from '@/pages/DashboardPage'
import { DeadStockPage } from '@/pages/DeadStockPage'
import { EnquiriesPage } from '@/pages/EnquiriesPage'
import { LoginPage } from '@/pages/LoginPage'
import { MarketPage } from '@/pages/MarketPage'
import { MarketplacePage } from '@/pages/MarketplacePage'
import { NotificationsPage } from '@/pages/NotificationsPage'
import { OrdersPage } from '@/pages/OrdersPage'
import { ProductsPage } from '@/pages/ProductsPage'
import { QuotesPage } from '@/pages/QuotesPage'
import { SettingsPage } from '@/pages/SettingsPage'
import { UsersPage } from '@/pages/UsersPage'

function Protected() {
  const { phase } = useAuth()
  if (phase === 'loading') {
    return (
      <div className="min-h-screen grid place-items-center text-muted text-sm">
        Checking admin session…
      </div>
    )
  }
  if (phase !== 'authenticated') return <Navigate to="/login" replace />
  return <Outlet />
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route element={<Protected />}>
        <Route element={<AdminLayout />}>
          <Route index element={<DashboardPage />} />
          <Route path="users" element={<UsersPage lockedRole="buyer" />} />
          <Route path="manufacturers" element={<UsersPage lockedRole="manufacturer" />} />
          <Route path="products" element={<ProductsPage />} />
          <Route path="enquiries" element={<EnquiriesPage />} />
          <Route path="quotes" element={<QuotesPage />} />
          <Route path="orders" element={<OrdersPage />} />
          <Route path="marketplace" element={<MarketplacePage />} />
          <Route path="dead-stock" element={<DeadStockPage />} />
          <Route path="market" element={<MarketPage />} />
          <Route path="notifications" element={<NotificationsPage />} />
          <Route path="banners" element={<BannersPage />} />
          <Route path="settings" element={<SettingsPage />} />
        </Route>
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
