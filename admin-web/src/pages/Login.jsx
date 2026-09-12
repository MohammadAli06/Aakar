import { useState } from 'react'
import { api, setToken } from '../lib/api.js'
import { Button, Field } from '../components/Ui.jsx'
import { Icon } from '../components/Icons.jsx'

const POINTS = [
  {
    icon: 'shield',
    title: 'Verify real accounts',
    text: 'Review the identity, craft and selfie evidence an artisan or buyer submitted, then approve, request a correction or reject.',
  },
  {
    icon: 'package',
    title: 'Moderate catalogue output',
    text: 'Inspect AI-generated listings and prices, and record a moderation decision that the artisan can still act on.',
  },
  {
    icon: 'activity',
    title: 'Keep a record',
    text: 'Every decision is written to an audit trail on the shared backend database, not to this browser.',
  },
]

export function Login({ onSignedIn }) {
  const [value, setValue] = useState('')
  const [reveal, setReveal] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState(null)

  async function submit(event) {
    event.preventDefault()
    const candidate = value.trim()
    if (!candidate) {
      setError('Enter the administrator access token.')
      return
    }
    setBusy(true)
    setError(null)
    try {
      await api('/admin/overview', { token: candidate })
      setToken(candidate)
      onSignedIn()
    } catch (failure) {
      setError(
        failure.status === 403
          ? 'That token was rejected. Compare it with ADMIN_ACCESS_TOKEN in the backend environment.'
          : failure.message,
      )
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="login">
      <section className="login-brand">
        <div className="row">
          <span className="brand-mark">
            <Icon name="leaf" size={21} />
          </span>
          <div>
            <div className="brand-name">Aakar</div>
            <div className="brand-sub">Admin console</div>
          </div>
        </div>

        <h1 className="login-word">Real craft, responsibly connected.</h1>
        <p className="login-tag">
          A small, careful review desk for the people and products on the platform.
        </p>

        <div className="login-points">
          {POINTS.map((point) => (
            <div className="login-point" key={point.title}>
              <span className="bubble">
                <Icon name={point.icon} size={16} />
              </span>
              <div>
                <h4>{point.title}</h4>
                <p>{point.text}</p>
              </div>
            </div>
          ))}
        </div>
      </section>

      <section className="login-panel">
        <form className="login-card" onSubmit={submit}>
          <h2>Administrator sign in</h2>
          <p className="lede">
            This console is protected by a separate administrator token. It never handles Firebase account
            credentials and it cannot be reached with a mobile access token.
          </p>

          <Field label="Admin access token">
            <div className="row" style={{ gap: 8 }}>
              <input
                className="input"
                type={reveal ? 'text' : 'password'}
                value={value}
                autoFocus
                autoComplete="off"
                spellCheck="false"
                placeholder="Bearer token issued by the backend"
                onChange={(event) => setValue(event.target.value)}
              />
              <button
                type="button"
                className="icon-btn"
                onClick={() => setReveal((current) => !current)}
                aria-label={reveal ? 'Hide token' : 'Show token'}
              >
                <Icon name={reveal ? 'lock' : 'unlock'} size={16} />
              </button>
            </div>
          </Field>

          {error ? (
            <div className="banner danger" style={{ marginTop: 14 }} role="alert">
              <span className="banner-icon">
                <Icon name="alert" size={16} />
              </span>
              <div>{error}</div>
            </div>
          ) : null}

          <div style={{ marginTop: 18 }}>
            <Button type="submit" block disabled={busy}>
              {busy ? 'Checking…' : 'Sign in to the console'}
            </Button>
          </div>

          <p className="login-foot">
            The token is held in this browser tab only and sent to the backend on each request. Access is
            verified server-side, so changing the token here does not grant permissions by itself.
          </p>
        </form>
      </section>
    </div>
  )
}
