import {
  addDoc,
  arrayUnion,
  collection,
  deleteDoc,
  doc,
  getCountFromServer,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  type QueryConstraint,
} from 'firebase/firestore'
import { db } from '@/lib/firebase'
import {
  mapBanner,
  mapEnquiry,
  mapMarketplace,
  mapOrder,
  mapPPRate,
  mapQuote,
  mapUser,
  toDate,
} from '@/lib/mappers'
import type {
  AdminNotification,
  AdminStats,
  AppUser,
  Banner,
  Enquiry,
  EnquiryStatus,
  MarketplaceItem,
  Order,
  OrderStatus,
  PPRate,
  Quote,
  QuoteStatus,
  UserRole,
} from '@/types'

export async function getUserById(uid: string): Promise<AppUser | null> {
  const snap = await getDoc(doc(db, 'users', uid))
  if (!snap.exists()) return null
  return mapUser(snap.id, snap.data() as Record<string, unknown>)
}

export async function getAdminStats(): Promise<AdminStats> {
  async function safeCount(q: Parameters<typeof getCountFromServer>[0]): Promise<number> {
    try {
      const snap = await getCountFromServer(q)
      return snap.data().count
    } catch {
      try {
        // Fallback for older rules / empty edge cases
        const docs = await getDocs(q as Parameters<typeof getDocs>[0])
        return docs.size
      } catch {
        return 0
      }
    }
  }

  const [totalUsers, manufacturers, buyers, enquiries, quotes, orders, marketplace] =
    await Promise.all([
      safeCount(collection(db, 'users')),
      safeCount(query(collection(db, 'users'), where('role', '==', 'manufacturer'))),
      safeCount(query(collection(db, 'users'), where('role', '==', 'buyer'))),
      safeCount(collection(db, 'enquiries')),
      safeCount(collection(db, 'quotes')),
      safeCount(collection(db, 'orders')),
      safeCount(collection(db, 'marketplace')),
    ])

  let orderValue = 0
  try {
    const orderSnap = await getDocs(collection(db, 'orders'))
    orderValue = orderSnap.docs.reduce((sum, d) => sum + Number(d.data().totalAmount ?? 0), 0)
  } catch {
    orderValue = 0
  }

  return {
    totalUsers,
    manufacturers,
    buyers,
    enquiries,
    quotes,
    orders,
    marketplace,
    orderValue,
  }
}

export async function fetchUsers(role?: UserRole): Promise<AppUser[]> {
  try {
    const constraints: QueryConstraint[] = [orderBy('createdAt', 'desc')]
    if (role) constraints.unshift(where('role', '==', role))
    const snap = await getDocs(query(collection(db, 'users'), ...constraints))
    return snap.docs.map((d) => mapUser(d.id, d.data() as Record<string, unknown>))
  } catch {
    const snap = role
      ? await getDocs(query(collection(db, 'users'), where('role', '==', role)))
      : await getDocs(collection(db, 'users'))
    return snap.docs
      .map((d) => mapUser(d.id, d.data() as Record<string, unknown>))
      .sort((a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0))
  }
}

/** Buyers (+ optional guests) for Users page; manufacturers for Manufacturers page */
export async function fetchUsersByRoles(roles: UserRole[]): Promise<AppUser[]> {
  const chunks = await Promise.all(roles.map((r) => fetchUsers(r)))
  const map = new Map<string, AppUser>()
  for (const list of chunks) {
    for (const u of list) map.set(u.id, u)
  }
  return [...map.values()].sort(
    (a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0),
  )
}

export async function setUserVerified(uid: string, isVerified: boolean): Promise<void> {
  await updateDoc(doc(db, 'users', uid), { isVerified })
}

export async function setUserActive(uid: string, isActive: boolean): Promise<void> {
  await updateDoc(doc(db, 'users', uid), { isActive })
}

export async function fetchEnquiries(status?: EnquiryStatus | 'all'): Promise<Enquiry[]> {
  const constraints: QueryConstraint[] = [orderBy('createdAt', 'desc')]
  if (status && status !== 'all') constraints.unshift(where('status', '==', status))
  const snap = await getDocs(query(collection(db, 'enquiries'), ...constraints))
  return snap.docs.map((d) => mapEnquiry(d.id, d.data() as Record<string, unknown>))
}

export async function updateEnquiryStatus(id: string, status: EnquiryStatus): Promise<void> {
  await updateDoc(doc(db, 'enquiries', id), { status })
}

export async function fetchQuotes(status?: QuoteStatus | 'all'): Promise<Quote[]> {
  const constraints: QueryConstraint[] = [orderBy('createdAt', 'desc')]
  if (status && status !== 'all') constraints.unshift(where('status', '==', status))
  try {
    const snap = await getDocs(query(collection(db, 'quotes'), ...constraints))
    return snap.docs.map((d) => mapQuote(d.id, d.data() as Record<string, unknown>))
  } catch {
    const snap = await getDocs(collection(db, 'quotes'))
    const list = snap.docs.map((d) => mapQuote(d.id, d.data() as Record<string, unknown>))
    return list
      .filter((q) => !status || status === 'all' || q.status === status)
      .sort((a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0))
  }
}

export async function fetchQuotesForEnquiry(enquiryId: string): Promise<Quote[]> {
  try {
    const snap = await getDocs(
      query(collection(db, 'quotes'), where('enquiryId', '==', enquiryId), orderBy('createdAt', 'desc')),
    )
    return snap.docs.map((d) => mapQuote(d.id, d.data() as Record<string, unknown>))
  } catch {
    const snap = await getDocs(query(collection(db, 'quotes'), where('enquiryId', '==', enquiryId)))
    return snap.docs
      .map((d) => mapQuote(d.id, d.data() as Record<string, unknown>))
      .sort((a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0))
  }
}

export async function updateQuoteStatus(id: string, status: QuoteStatus): Promise<void> {
  await updateDoc(doc(db, 'quotes', id), { status })
}

/** Mirror mobile acceptQuote: create order, close enquiry, reject siblings, notify. */
export async function acceptQuoteAsAdmin(quoteId: string): Promise<string> {
  const quoteRef = doc(db, 'quotes', quoteId)
  const quoteSnap = await getDoc(quoteRef)
  if (!quoteSnap.exists()) throw new Error('Quote not found')
  const quote = mapQuote(quoteSnap.id, quoteSnap.data() as Record<string, unknown>)
  if (quote.status === 'accepted') throw new Error('Quote already accepted')

  const enquirySnap = await getDoc(doc(db, 'enquiries', quote.enquiryId))
  if (!enquirySnap.exists()) throw new Error('Enquiry not found')
  const enquiry = mapEnquiry(enquirySnap.id, enquirySnap.data() as Record<string, unknown>)

  const orderId = `ORD${String(Date.now()).slice(-7)}`
  await setDoc(doc(db, 'orders', orderId), {
    enquiryId: quote.enquiryId,
    quoteId: quote.id,
    buyerId: enquiry.buyerId,
    manufacturerId: quote.manufacturerId,
    buyerName: enquiry.buyerName,
    manufacturerName: quote.manufacturerName,
    totalAmount: quote.totalApprox,
    status: 'confirmed',
    createdAt: serverTimestamp(),
  })

  await updateDoc(quoteRef, { status: 'accepted' })
  await updateDoc(doc(db, 'enquiries', enquiry.id), { status: 'closed' })

  const others = await getDocs(
    query(collection(db, 'quotes'), where('enquiryId', '==', enquiry.id)),
  )
  await Promise.all(
    others.docs
      .filter((d) => d.id !== quote.id)
      .map((d) => updateDoc(d.ref, { status: 'rejected' })),
  )

  await sendNotification({
    userId: quote.manufacturerId,
    title: 'Quote accepted',
    body: `${enquiry.buyerName} accepted your quote. Order ${orderId} confirmed.`,
    type: 'order',
    refId: orderId,
  })
  await sendNotification({
    userId: enquiry.buyerId,
    title: 'Order confirmed',
    body: `Order ${orderId} confirmed with ${quote.manufacturerName}.`,
    type: 'order',
    refId: orderId,
  })

  return orderId
}

export async function fetchOrders(status?: OrderStatus | 'all'): Promise<Order[]> {
  const constraints: QueryConstraint[] = [orderBy('createdAt', 'desc')]
  if (status && status !== 'all') constraints.unshift(where('status', '==', status))
  try {
    const snap = await getDocs(query(collection(db, 'orders'), ...constraints))
    return snap.docs.map((d) => mapOrder(d.id, d.data() as Record<string, unknown>))
  } catch {
    const snap = await getDocs(collection(db, 'orders'))
    return snap.docs
      .map((d) => mapOrder(d.id, d.data() as Record<string, unknown>))
      .filter((o) => !status || status === 'all' || o.status === status)
      .sort((a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0))
  }
}

export async function updateOrderStatus(id: string, status: OrderStatus): Promise<void> {
  await updateDoc(doc(db, 'orders', id), { status })
}

export async function fetchPPRates(): Promise<PPRate[]> {
  try {
    const snap = await getDocs(query(collection(db, 'pp_rates'), orderBy('updatedAt', 'desc')))
    return snap.docs.map((d) => mapPPRate(d.id, d.data() as Record<string, unknown>))
  } catch {
    const snap = await getDocs(collection(db, 'pp_rates'))
    return snap.docs.map((d) => mapPPRate(d.id, d.data() as Record<string, unknown>))
  }
}

export async function fetchMarketplace(category?: string): Promise<MarketplaceItem[]> {
  const constraints: QueryConstraint[] = [orderBy('createdAt', 'desc')]
  if (category) constraints.unshift(where('category', '==', category))
  try {
    const snap = await getDocs(query(collection(db, 'marketplace'), ...constraints))
    return snap.docs.map((d) => mapMarketplace(d.id, d.data() as Record<string, unknown>))
  } catch {
    const snap = await getDocs(collection(db, 'marketplace'))
    return snap.docs
      .map((d) => mapMarketplace(d.id, d.data() as Record<string, unknown>))
      .filter((m) => !category || m.category === category)
      .sort((a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0))
  }
}

export async function deleteMarketplaceItem(id: string): Promise<void> {
  await deleteDoc(doc(db, 'marketplace', id))
}

export async function fetchBanners(): Promise<Banner[]> {
  const snap = await getDocs(query(collection(db, 'banners'), orderBy('order', 'asc')))
  return snap.docs.map((d) => mapBanner(d.id, d.data() as Record<string, unknown>))
}

export async function createBanner(input: {
  title: string
  imageUrl: string
  link: string
}): Promise<void> {
  await addDoc(collection(db, 'banners'), {
    ...input,
    isActive: true,
    order: Date.now(),
    createdAt: serverTimestamp(),
  })
}

export async function setBannerActive(id: string, isActive: boolean): Promise<void> {
  await updateDoc(doc(db, 'banners', id), { isActive })
}

export async function deleteBanner(id: string): Promise<void> {
  await deleteDoc(doc(db, 'banners', id))
}

export async function updateBanner(
  id: string,
  input: Partial<{ title: string; imageUrl: string; link: string; isActive: boolean }>,
): Promise<void> {
  await updateDoc(doc(db, 'banners', id), input)
}

export async function setUserProducts(uid: string, products: string[]): Promise<void> {
  await updateDoc(doc(db, 'users', uid), { products })
}

export async function setUserRole(uid: string, role: UserRole): Promise<void> {
  await updateDoc(doc(db, 'users', uid), { role })
}

export async function findUserByPhone(phone10: string): Promise<AppUser | null> {
  const digits = phone10.replace(/\D/g, '').slice(-10)
  const variants = [`+91${digits}`, `91${digits}`, digits, `+91 ${digits}`]
  for (const phone of variants) {
    const snap = await getDocs(query(collection(db, 'users'), where('phone', '==', phone)))
    if (!snap.empty) {
      const d = snap.docs[0]
      return mapUser(d.id, d.data() as Record<string, unknown>)
    }
  }
  const all = await fetchUsers()
  return (
    all.find((u) => u.phone.replace(/\D/g, '').endsWith(digits)) ?? null
  )
}

export async function ensurePPRates(): Promise<void> {
  const defaults = [
    { id: 'virgin', materialType: 'Virgin PP' },
    { id: 'recycled', materialType: 'Recycled PP' },
  ]
  for (const d of defaults) {
    const ref = doc(db, 'pp_rates', d.id)
    const snap = await getDoc(ref)
    if (!snap.exists()) {
      await setDoc(ref, {
        materialType: d.materialType,
        currentRate: 0,
        changePercent: 0,
        history: [],
        updatedAt: serverTimestamp(),
      })
    }
  }
}

export async function updatePPRate(id: string, rate: number): Promise<void> {
  const ref = doc(db, 'pp_rates', id)
  const snap = await getDoc(ref)
  if (!snap.exists()) {
    await ensurePPRates()
  }
  const fresh = await getDoc(ref)
  const current = Number(fresh.data()?.currentRate ?? 0)
  const changePercent = current > 0 ? ((rate - current) / current) * 100 : 0
  await updateDoc(ref, {
    currentRate: rate,
    changePercent,
    updatedAt: serverTimestamp(),
    history: arrayUnion({ rate, date: Timestamp.now() }),
  })
}

export async function updatePPRateName(id: string, materialType: string): Promise<void> {
  const name = materialType.trim()
  if (!name) throw new Error('Rate name cannot be empty')
  const ref = doc(db, 'pp_rates', id)
  const snap = await getDoc(ref)
  if (!snap.exists()) {
    await ensurePPRates()
  }
  await updateDoc(ref, {
    materialType: name,
    updatedAt: serverTimestamp(),
  })
}

export async function sendNotification(input: {
  userId: string
  title: string
  body: string
  type?: string
  refId?: string
}): Promise<void> {
  await addDoc(collection(db, 'notifications'), {
    userId: input.userId,
    title: input.title,
    body: input.body,
    type: input.type ?? 'admin',
    refId: input.refId ?? null,
    read: false,
    createdAt: serverTimestamp(),
  })
}

export async function broadcastNotification(input: {
  title: string
  body: string
  role?: 'buyer' | 'manufacturer' | 'all'
}): Promise<number> {
  const role = input.role ?? 'all'
  let users: AppUser[] = []
  if (role === 'all') {
    const [buyers, manufacturers] = await Promise.all([
      fetchUsers('buyer'),
      fetchUsers('manufacturer'),
    ])
    users = [...buyers, ...manufacturers]
  } else {
    users = await fetchUsers(role)
  }
  await Promise.all(
    users.map((u) =>
      sendNotification({
        userId: u.id,
        title: input.title,
        body: input.body,
        type: 'broadcast',
      }),
    ),
  )
  return users.length
}

export async function fetchRecentNotifications(limitCount = 50): Promise<AdminNotification[]> {
  try {
    const snap = await getDocs(
      query(collection(db, 'notifications'), orderBy('createdAt', 'desc')),
    )
    return snap.docs.slice(0, limitCount).map((d) => {
      const data = d.data() as Record<string, unknown>
      return {
        id: d.id,
        userId: String(data.userId ?? ''),
        title: String(data.title ?? ''),
        body: String(data.body ?? ''),
        type: String(data.type ?? 'admin'),
        refId: (data.refId as string) ?? null,
        read: Boolean(data.read),
        createdAt: toDate(data.createdAt),
      }
    })
  } catch {
    return []
  }
}

export function productCategories(): string[] {
  return [
    'D-Cut Bag',
    'W-Cut Bag',
    'Box Bag',
    'Loop Handle Bag',
    'Side Gusset Bag',
    'Non-Woven Bag',
    'Laminated Bag',
    'Other Bag',
  ]
}
