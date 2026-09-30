import type { Timestamp } from 'firebase/firestore'
import type {
  AppUser,
  Banner,
  Enquiry,
  MarketplaceItem,
  Order,
  PPRate,
  Quote,
  RateHistory,
  UserRole,
} from '@/types'

export function toDate(value: unknown): Date | null {
  if (!value) return null
  if (value instanceof Date) return value
  if (typeof value === 'object' && value !== null && 'toDate' in value) {
    return (value as Timestamp).toDate()
  }
  if (typeof value === 'string' || typeof value === 'number') {
    const d = new Date(value)
    return Number.isNaN(d.getTime()) ? null : d
  }
  return null
}

export function mapUser(id: string, data: Record<string, unknown>): AppUser {
  return {
    id,
    phone: String(data.phone ?? ''),
    name: (data.name as string) ?? null,
    email: (data.email as string) ?? null,
    role: (data.role as UserRole) ?? 'guest',
    businessName: (data.businessName as string) ?? null,
    businessType: (data.businessType as string) ?? null,
    location: (data.location as string) ?? null,
    city: (data.city as string) ?? null,
    state: (data.state as string) ?? null,
    profileImage: (data.profileImage as string) ?? null,
    aboutUs: (data.aboutUs as string) ?? null,
    products: Array.isArray(data.products) ? (data.products as string[]) : [],
    gsmRange: (data.gsmRange as string) ?? null,
    minOrderKg: data.minOrderKg != null ? Number(data.minOrderKg) : null,
    isVerified: Boolean(data.isVerified),
    isActive: data.isActive === undefined ? true : Boolean(data.isActive),
    gstNumber: (data.gstNumber as string) ?? null,
    gstType: (data.gstType as string) ?? null,
    gstRegistrationDate: toDate(data.gstRegistrationDate),
    addressLine1: (data.addressLine1 as string) ?? null,
    addressLine2: (data.addressLine2 as string) ?? null,
    pincode: (data.pincode as string) ?? null,
    country: (data.country as string) ?? null,
    contactNumber: (data.contactNumber as string) ?? null,
    website: (data.website as string) ?? null,
    createdAt: toDate(data.createdAt),
  }
}

export function mapEnquiry(id: string, data: Record<string, unknown>): Enquiry {
  return {
    id,
    buyerId: String(data.buyerId ?? ''),
    buyerName: String(data.buyerName ?? ''),
    bagType: String(data.bagType ?? ''),
    size: String(data.size ?? ''),
    color: String(data.color ?? ''),
    gsm: Number(data.gsm ?? 0),
    printing: String(data.printing ?? ''),
    quantityKg: Number(data.quantityKg ?? 0),
    deliveryLocation: String(data.deliveryLocation ?? ''),
    requiredBy: toDate(data.requiredBy),
    additionalNotes: (data.additionalNotes as string) ?? null,
    status: (data.status as Enquiry['status']) ?? 'open',
    quoteCount: Number(data.quoteCount ?? 0),
    createdAt: toDate(data.createdAt),
  }
}

export function mapQuote(id: string, data: Record<string, unknown>): Quote {
  return {
    id,
    enquiryId: String(data.enquiryId ?? ''),
    manufacturerId: String(data.manufacturerId ?? ''),
    manufacturerName: String(data.manufacturerName ?? ''),
    bagPricePerKg: Number(data.bagPricePerKg ?? 0),
    printingPricePerKg: Number(data.printingPricePerKg ?? 0),
    gstPercent: Number(data.gstPercent ?? 0),
    transportCharges: Number(data.transportCharges ?? 0),
    otherCharges: Number(data.otherCharges ?? 0),
    totalApprox: Number(data.totalApprox ?? 0),
    deliveryDays: Number(data.deliveryDays ?? 0),
    validity: String(data.validity ?? ''),
    paymentTerms: String(data.paymentTerms ?? ''),
    status: (data.status as Quote['status']) ?? 'pending',
    createdAt: toDate(data.createdAt),
  }
}

export function mapOrder(id: string, data: Record<string, unknown>): Order {
  return {
    id,
    enquiryId: String(data.enquiryId ?? ''),
    quoteId: String(data.quoteId ?? ''),
    buyerId: String(data.buyerId ?? ''),
    manufacturerId: String(data.manufacturerId ?? ''),
    buyerName: String(data.buyerName ?? ''),
    manufacturerName: String(data.manufacturerName ?? ''),
    totalAmount: Number(data.totalAmount ?? 0),
    status: (data.status as Order['status']) ?? 'confirmed',
    createdAt: toDate(data.createdAt),
  }
}

export function mapPPRate(id: string, data: Record<string, unknown>): PPRate {
  const historyRaw = Array.isArray(data.history) ? data.history : []
  const history: RateHistory[] = historyRaw.map((item) => {
    const row = item as Record<string, unknown>
    return {
      rate: Number(row.rate ?? 0),
      date: toDate(row.date),
    }
  })
  return {
    id,
    materialType: String(data.materialType ?? id),
    currentRate: Number(data.currentRate ?? 0),
    changePercent: Number(data.changePercent ?? 0),
    history,
    updatedAt: toDate(data.updatedAt),
  }
}

export function mapMarketplace(id: string, data: Record<string, unknown>): MarketplaceItem {
  return {
    id,
    sellerId: String(data.sellerId ?? ''),
    sellerName: String(data.sellerName ?? ''),
    category: String(data.category ?? ''),
    title: String(data.title ?? ''),
    description: String(data.description ?? ''),
    price: Number(data.price ?? 0),
    unit: String(data.unit ?? 'KG'),
    quantity: Number(data.quantity ?? 0),
    location: String(data.location ?? ''),
    createdAt: toDate(data.createdAt),
  }
}

export function mapBanner(id: string, data: Record<string, unknown>): Banner {
  return {
    id,
    title: String(data.title ?? ''),
    imageUrl: String(data.imageUrl ?? ''),
    link: String(data.link ?? ''),
    isActive: Boolean(data.isActive),
    order: Number(data.order ?? 0),
    createdAt: toDate(data.createdAt),
  }
}

export function formatDate(date: Date | null, withTime = false): string {
  if (!date) return '—'
  return date.toLocaleDateString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    ...(withTime ? { hour: '2-digit', minute: '2-digit' } : {}),
  })
}

export function formatINR(value: number): string {
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 2,
  }).format(value)
}

export function shortId(id: string): string {
  return id.length > 8 ? id.slice(-8).toUpperCase() : id.toUpperCase()
}
