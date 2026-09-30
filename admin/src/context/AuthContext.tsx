import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react'
import {
  onAuthStateChanged,
  RecaptchaVerifier,
  signInWithCredential,
  signOut,
  PhoneAuthProvider,
  type ConfirmationResult,
  signInWithPhoneNumber,
  type User,
  type AuthError,
} from 'firebase/auth'
import { auth, firebaseReady } from '@/lib/firebase'
import { getUserById } from '@/services/adminApi'
import type { AppUser } from '@/types'

type AuthPhase = 'loading' | 'unauthenticated' | 'authenticated'

interface AuthContextValue {
  phase: AuthPhase
  firebaseUser: User | null
  adminUser: AppUser | null
  firebaseReady: boolean
  error: string | null
  clearError: () => void
  sendOtp: (phone10: string) => Promise<void>
  verifyOtp: (otp: string) => Promise<void>
  resetOtpSession: () => void
  logout: () => Promise<void>
  prepareRecaptcha: () => Promise<RecaptchaVerifier>
}

const AuthContext = createContext<AuthContextValue | null>(null)

function authErrorMessage(err: unknown): string {
  const e = err as AuthError & { message?: string }
  const code = e?.code ?? ''
  const map: Record<string, string> = {
    'auth/invalid-phone-number': 'Invalid phone number. Use a valid 10-digit Indian mobile.',
    'auth/missing-phone-number': 'Phone number is required.',
    'auth/quota-exceeded': 'SMS quota exceeded. Try again later or enable billing in Firebase.',
    'auth/user-disabled': 'This account has been disabled.',
    'auth/operation-not-allowed':
      'Phone sign-in is not enabled. Enable Phone provider in Firebase Console → Authentication.',
    'auth/too-many-requests': 'Too many attempts. Wait a few minutes and try again.',
    'auth/captcha-check-failed': 'reCAPTCHA failed. Refresh the page and try again.',
    'auth/invalid-app-credential':
      'App credential invalid. Check Firebase web config / authorized domains (localhost).',
    'auth/network-request-failed': 'Network error. Check your internet connection.',
    'auth/invalid-verification-code': 'Wrong OTP. Please try again.',
    'auth/code-expired': 'OTP expired. Request a new one.',
    'auth/missing-verification-code': 'Enter the 6-digit OTP.',
    'auth/argument-error': 'Phone auth setup error (reCAPTCHA). Refresh and try again.',
  }
  if (code && map[code]) return map[code]
  if (code) return `${code}: ${e.message ?? 'Authentication failed'}`
  return e?.message ?? 'Something went wrong sending OTP'
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [phase, setPhase] = useState<AuthPhase>('loading')
  const [firebaseUser, setFirebaseUser] = useState<User | null>(null)
  const [adminUser, setAdminUser] = useState<AppUser | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [confirmation, setConfirmation] = useState<ConfirmationResult | null>(null)
  const [verificationId, setVerificationId] = useState<string | null>(null)
  const verifierRef = useRef<RecaptchaVerifier | null>(null)

  const clearRecaptcha = useCallback(() => {
    try {
      verifierRef.current?.clear()
    } catch {
      // ignore
    }
    verifierRef.current = null
    const el = document.getElementById('recaptcha-container')
    if (el) el.innerHTML = ''
  }, [])

  const getRecaptcha = useCallback(async () => {
    clearRecaptcha()
    const container = document.getElementById('recaptcha-container')
    if (!container) {
      throw new Error('reCAPTCHA container missing. Refresh the page.')
    }
    const verifier = new RecaptchaVerifier(auth, 'recaptcha-container', {
      size: 'normal',
      callback: () => {
        // solved
      },
      'expired-callback': () => {
        clearRecaptcha()
      },
    })
    verifierRef.current = verifier
    await verifier.render()
    return verifier
  }, [clearRecaptcha])

  useEffect(() => {
    if (!firebaseReady) {
      setPhase('unauthenticated')
      return
    }
    const unsub = onAuthStateChanged(auth, async (user) => {
      if (!user) {
        setFirebaseUser(null)
        setAdminUser(null)
        setPhase('unauthenticated')
        return
      }
      try {
        const profile = await getUserById(user.uid)
        if (!profile || profile.role !== 'admin') {
          await signOut(auth)
          setError('Access denied. Only admin accounts can use this panel.')
          setFirebaseUser(null)
          setAdminUser(null)
          setPhase('unauthenticated')
          return
        }
        if (profile.isActive === false) {
          await signOut(auth)
          setError('This admin account has been disabled.')
          setFirebaseUser(null)
          setAdminUser(null)
          setPhase('unauthenticated')
          return
        }
        setFirebaseUser(user)
        setAdminUser(profile)
        setPhase('authenticated')
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Failed to load admin profile')
        setPhase('unauthenticated')
      }
    })
    return () => unsub()
  }, [])

  const sendOtp = useCallback(
    async (phone10: string) => {
      setError(null)
      if (!firebaseReady) {
        setError('Firebase is not configured for project bagmandi.')
        throw new Error('Firebase not ready')
      }
      const digits = phone10.replace(/\D/g, '')
      if (digits.length !== 10) {
        setError('Enter a valid 10-digit mobile number')
        throw new Error('Invalid phone')
      }
      try {
        let verifier = verifierRef.current
        if (!verifier) {
          verifier = await getRecaptcha()
        }
        const result = await signInWithPhoneNumber(auth, `+91${digits}`, verifier)
        setConfirmation(result)
        setVerificationId(result.verificationId)
      } catch (err) {
        clearRecaptcha()
        // Rebuild widget for next attempt
        try {
          await getRecaptcha()
        } catch {
          // ignore secondary failure
        }
        const message = authErrorMessage(err)
        setError(message)
        throw err
      }
    },
    [getRecaptcha, clearRecaptcha],
  )

  const verifyOtp = useCallback(
    async (otp: string) => {
      setError(null)
      if (!/^\d{6}$/.test(otp)) {
        setError('Enter the 6-digit OTP')
        throw new Error('Invalid OTP')
      }
      try {
        if (confirmation) {
          await confirmation.confirm(otp)
          clearRecaptcha()
          return
        }
        if (!verificationId) {
          setError('Request OTP first')
          throw new Error('No verification')
        }
        const credential = PhoneAuthProvider.credential(verificationId, otp)
        await signInWithCredential(auth, credential)
        clearRecaptcha()
      } catch (err) {
        setError(authErrorMessage(err))
        throw err
      }
    },
    [confirmation, verificationId, clearRecaptcha],
  )

  const resetOtpSession = useCallback(() => {
    setConfirmation(null)
    setVerificationId(null)
    setError(null)
    clearRecaptcha()
  }, [clearRecaptcha])

  const logout = useCallback(async () => {
    await signOut(auth)
    setConfirmation(null)
    setVerificationId(null)
    clearRecaptcha()
  }, [clearRecaptcha])

  const value = useMemo<AuthContextValue>(
    () => ({
      phase,
      firebaseUser,
      adminUser,
      firebaseReady,
      error,
      clearError: () => setError(null),
      sendOtp,
      verifyOtp,
      resetOtpSession,
      logout,
      prepareRecaptcha: getRecaptcha,
    }),
    [phase, firebaseUser, adminUser, error, sendOtp, verifyOtp, resetOtpSession, logout, getRecaptcha],
  )

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
