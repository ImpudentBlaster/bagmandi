import { useEffect, useState } from 'react'
import { Navigate } from 'react-router-dom'
import { BrandLogo } from '@/components/BrandLogo'
import { useAuth } from '@/context/AuthContext'

export function LoginPage() {
  const { phase, sendOtp, verifyOtp, error, clearError, firebaseReady, prepareRecaptcha, resetOtpSession } = useAuth()
  const [step, setStep] = useState<'phone' | 'otp'>('phone')
  const [phone, setPhone] = useState('')
  const [otp, setOtp] = useState('')
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    if (phase !== 'unauthenticated' || step !== 'phone' || !firebaseReady) return
    const t = window.setTimeout(() => {
      void prepareRecaptcha().catch(() => {
        // surfaced on send if still broken
      })
    }, 50)
    return () => window.clearTimeout(t)
  }, [phase, step, firebaseReady, prepareRecaptcha])

  if (phase === 'authenticated') return <Navigate to="/" replace />

  const onSend = async (e: React.FormEvent) => {
    e.preventDefault()
    clearError()
    setBusy(true)
    try {
      await sendOtp(phone)
      setStep('otp')
    } catch {
      // error set in AuthContext
    } finally {
      setBusy(false)
    }
  }

  const onVerify = async (e: React.FormEvent) => {
    e.preventDefault()
    clearError()
    setBusy(true)
    try {
      await verifyOtp(otp)
    } catch {
      // error already set
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="min-h-screen grid lg:grid-cols-2">
      <div className="relative hidden lg:flex flex-col justify-between p-12 text-white overflow-hidden bg-[linear-gradient(160deg,#0a4d28_0%,#189f43_48%,#0e7a32_100%)]">
        <div className="absolute inset-0 opacity-30 bg-[radial-gradient(circle_at_20%_20%,#fff_0%,transparent_40%),radial-gradient(circle_at_80%_70%,#9dffb8_0%,transparent_35%)]" />
        <div className="relative inline-flex items-center gap-3">
          <BrandLogo size={44} className="bg-white shadow-md" />
          <span className="font-display text-2xl font-semibold tracking-tight">BagMandi</span>
        </div>
        <div className="relative max-w-md">
          <BrandLogo size={160} className="mb-8 bg-white shadow-xl" />
          <h1 className="font-display text-4xl font-semibold leading-tight">
            Admin control for India&apos;s bag marketplace
          </h1>
          <p className="mt-4 text-white/80 text-lg">
            Manage users, enquiries, PP rates, marketplace listings and more — secured with phone OTP.
          </p>
        </div>
        <p className="relative text-sm text-white/60">Phone OTP · Firebase Auth · Firestore</p>
      </div>

      <div className="flex items-center justify-center p-6 sm:p-10 bg-bg">
        <div className="w-full max-w-md">
          <div className="lg:hidden mb-8 flex items-center gap-3">
            <BrandLogo size={44} />
            <span className="font-display text-xl font-semibold">BagMandi Admin</span>
          </div>

          <div className="bg-surface rounded-2xl border border-border p-8 shadow-[0_12px_40px_rgba(0,0,0,0.06)]">
            <h2 className="font-display text-2xl font-semibold">
              {step === 'phone' ? 'Sign in with phone' : 'Enter OTP'}
            </h2>
            <p className="mt-2 text-muted text-sm">
              {step === 'phone'
                ? 'Use the admin phone number registered in Firebase.'
                : `OTP sent to +91 ${phone}`}
            </p>

            {!firebaseReady && (
              <div className="mt-4 rounded-xl bg-warning/10 text-warning px-4 py-3 text-sm">
                Firebase config missing. Check <code>admin/.env</code> for project{' '}
                <strong>bagmandi</strong>.
              </div>
            )}

            {error && (
              <div className="mt-4 rounded-xl bg-error/10 text-error px-4 py-3 text-sm">{error}</div>
            )}

            {step === 'phone' ? (
              <form onSubmit={onSend} className="mt-6 space-y-4">
                <label className="block">
                  <span className="text-sm font-medium">Mobile number</span>
                  <div className="mt-1.5 flex rounded-xl border border-border overflow-hidden focus-within:ring-2 focus-within:ring-primary/30">
                    <span className="px-3 grid place-items-center bg-bg text-muted text-sm border-r border-border">
                      +91
                    </span>
                    <input
                      value={phone}
                      onChange={(e) => setPhone(e.target.value.replace(/\D/g, '').slice(0, 10))}
                      placeholder="9876543210"
                      className="flex-1 px-3 py-3 outline-none"
                      inputMode="numeric"
                      required
                    />
                  </div>
                </label>
                <div className="rounded-xl border border-border bg-bg p-3">
                  <p className="text-xs text-muted mb-2">Complete reCAPTCHA, then send OTP</p>
                  <div id="recaptcha-container" className="flex justify-center min-h-[78px]" />
                </div>
                <button
                  type="submit"
                  disabled={busy || phone.length !== 10}
                  className="w-full rounded-xl bg-primary hover:bg-primary-dark disabled:opacity-50 text-white font-medium py-3 transition"
                >
                  {busy ? 'Sending…' : 'Send OTP'}
                </button>
              </form>
            ) : (
              <form onSubmit={onVerify} className="mt-6 space-y-4">
                <label className="block">
                  <span className="text-sm font-medium">6-digit OTP</span>
                  <input
                    value={otp}
                    onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
                    placeholder="••••••"
                    className="mt-1.5 w-full rounded-xl border border-border px-3 py-3 tracking-[0.4em] text-center text-lg outline-none focus:ring-2 focus:ring-primary/30"
                    inputMode="numeric"
                    required
                  />
                </label>
                <button
                  type="submit"
                  disabled={busy || otp.length !== 6}
                  className="w-full rounded-xl bg-primary hover:bg-primary-dark disabled:opacity-50 text-white font-medium py-3 transition"
                >
                  {busy ? 'Verifying…' : 'Verify & Continue'}
                </button>
                <button
                  type="button"
                  className="w-full text-sm text-muted hover:text-text"
                  onClick={() => {
                    resetOtpSession()
                    setStep('phone')
                    setOtp('')
                  }}
                >
                  Change number
                </button>
                <button
                  type="button"
                  disabled={busy}
                  className="w-full text-sm text-primary hover:underline disabled:opacity-50"
                  onClick={() => void onSend({ preventDefault() {} } as React.FormEvent)}
                >
                  Resend OTP
                </button>
              </form>
            )}
          </div>

          <p className="mt-6 text-center text-xs text-muted">
            Firestore user must have <code className="text-text">role: admin</code>
          </p>
        </div>
      </div>
    </div>
  )
}
