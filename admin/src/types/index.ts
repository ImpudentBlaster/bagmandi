export type UserRole = 'buyer' | 'manufacturer' | 'admin' | 'guest'
export type EnquiryStatus = 'open' | 'quoted' | 'closed'
export type QuoteStatus = 'pending' | 'accepted' | 'rejected'
export type OrderStatus = 'confirmed' | 'ongoing' | 'completed' | 'cancelled'

export interface AppUser {
  id: string
  phone: string
  name: string | null
  email: string | null
  role: UserRole
  businessName: string | null
  businessType: string | null
  location: string | null
  city: string | null
  state: string | null
  profileImage: string | null
  aboutUs: string | null
  products: string[]
  gsmRange: string | null
  minOrderKg: number | null
  isVerified: boolean
  isActive: boolean
  gstNumber: string | null
  gstType: string | null
  gstRegistrationDate: Date | null
  addressLine1: string | null
  addressLine2: string | null
  pincode: string | null
  country: string | null
  contactNumber: string | null
  website: string | null
  createdAt: Date | null
}

export interface Enquiry {
  id: string
  buyerId: string
  buyerName: string
  bagType: string
  size: string
  color: string
  gsm: number
  printing: string
  quantityKg: number
  deliveryLocation: string
  requiredBy: Date | null
  additionalNotes: string | null
  status: EnquiryStatus
  quoteCount: number
  createdAt: Date | null
}

export interface Quote {
  id: string
  enquiryId: string
  manufacturerId: string
  manufacturerName: string
  bagPricePerKg: number
  printingPricePerKg: number
  gstPercent: number
  transportCharges: number
  otherCharges: number
  totalApprox: number
  deliveryDays: number
  validity: string
  paymentTerms: string
  status: QuoteStatus
  createdAt: Date | null
}

export interface Order {
  id: string
  enquiryId: string
  quoteId: string
  buyerId: string
  manufacturerId: string
  buyerName: string
  manufacturerName: string
  totalAmount: number
  status: OrderStatus
  createdAt: Date | null
}

export interface RateHistory {
  rate: number
  date: Date | null
}

export interface PPRate {
  id: string
  materialType: string
  currentRate: number
  changePercent: number
  history: RateHistory[]
  updatedAt: Date | null
}

export interface MarketplaceItem {
  id: string
  sellerId: string
  sellerName: string
  category: string
  title: string
  description: string
  price: number
  unit: string
  quantity: number
  location: string
  createdAt: Date | null
}

export interface Banner {
  id: string
  title: string
  imageUrl: string
  link: string
  isActive: boolean
  order: number
  createdAt: Date | null
}

export interface AdminNotification {
  id: string
  userId: string
  title: string
  body: string
  type: string
  refId: string | null
  read: boolean
  createdAt: Date | null
}

export interface AdminStats {
  totalUsers: number
  manufacturers: number
  buyers: number
  enquiries: number
  quotes: number
  orders: number
  marketplace: number
  orderValue: number
}
