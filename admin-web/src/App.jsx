import { useCallback, useEffect, useState } from 'react'
import { api, clearToken, getToken } from './lib/api.js'
import { navigate, useRoute } from './lib/router.jsx'
import { ToastProvider } from './components/ToastProvider.jsx'
import { Layout } from './components/Layout.jsx'
import { Button, Card, Empty } from './components/Ui.jsx'
import { Login } from './pages/Login.jsx'
import { Dashboard } from './pages/Dashboard.jsx'
import { Verification } from './pages/Verification.jsx'
import { VerificationDetail } from './pages/VerificationDetail.jsx'
import { Accounts } from './pages/Accounts.jsx'
import { AccountDetail } from './pages/AccountDetail.jsx'
import { Products } from './pages/Products.jsx'
import { ProductDetail } from './pages/ProductDetail.jsx'
import { Requirements } from './pages/Requirements.jsx'
import { Issues } from './pages/Issues.jsx'
import { Analytics } from './pages/Analytics.jsx'
import { Activity } from './pages/Activity.jsx'
import { Platform } from './pages/Platform.jsx'
import { Deferred } from './pages/Deferred.jsx'

const SECTIONS = new Set([
  'dashboard',
  'verification',
  'accounts',
  'products',
  'requirements',
  'issues',
  'analytics',
  'activity',
  'platform',
  'deferred',
])

function NotFound() {
  return (
    <Card>
      <Empty
        icon="search"
        title="Page not found"
        text="That route does not exist in the admin console."
        action={
          <Button variant="ghost" size="sm" onClick={() => navigate('/dashboard')}>
            Go to dashboard
          </Button>
        }
      />
    </Card>
  )
}

function Console({ section, id, reloadKey, counts, onRefresh, onSignOut, refreshing }) {
  let page
  switch (section) {
    case 'verification':
      page = id ? <VerificationDetail recordId={id} reloadKey={reloadKey} /> : <Verification reloadKey={reloadKey} />
      break
    case 'accounts':
      page = id ? <AccountDetail userId={id} reloadKey={reloadKey} /> : <Accounts reloadKey={reloadKey} />
      break
    case 'products':
      page = id ? <ProductDetail productId={id} reloadKey={reloadKey} /> : <Products reloadKey={reloadKey} />
      break
    case 'requirements':
      page = <Requirements reloadKey={reloadKey} />
      break
    case 'issues':
      page = <Issues reloadKey={reloadKey} />
      break
    case 'analytics':
      page = <Analytics reloadKey={reloadKey} />
      break
    case 'activity':
      page = <Activity reloadKey={reloadKey} />
      break
    case 'platform':
      page = <Platform reloadKey={reloadKey} />
      break
    case 'deferred':
      page = <Deferred section={id} />
      break
    case 'dashboard':
      page = <Dashboard reloadKey={reloadKey} />
      break
    default:
      page = <NotFound />
  }

  return (
    <Layout
      section={SECTIONS.has(section) ? section : 'dashboard'}
      counts={counts}
      onRefresh={onRefresh}
      refreshing={refreshing}
      onSignOut={onSignOut}
    >
      {page}
    </Layout>
  )
}

export default function App() {
  const { section, id } = useRoute()
  const [session, setSession] = useState(() => (getToken() ? 'checking' : 'signed-out'))
  const [counts, setCounts] = useState(null)
  const [reloadKey, setReloadKey] = useState(0)
  const [refreshing, setRefreshing] = useState(false)

  // Validate a stored token once on load. Only an explicit rejection signs out;
  // a network failure leaves the console usable with visible errors.
  useEffect(() => {
    if (session !== 'checking') return
    api('/admin/overview').then(
      () => setSession('signed-in'),
      (error) => {
        if (error.status === 403) {
          clearToken()
          setSession('signed-out')
        } else {
          setSession('signed-in')
        }
      },
    )
  }, [session])

  // A rejected token on any later request signs the console out.
  useEffect(() => {
    const onUnauthorized = () => {
      clearToken()
      setSession('signed-out')
    }
    window.addEventListener('aakar:unauthorized', onUnauthorized)
    return () => window.removeEventListener('aakar:unauthorized', onUnauthorized)
  }, [])

  // Sidebar badges read the same overview endpoint the dashboard uses.
  useEffect(() => {
    if (session !== 'signed-in') return undefined
    let alive = true
    api('/admin/overview').then(
      (data) => {
        if (alive) setCounts(data)
      },
      () => {
        if (alive) setCounts(null)
      },
    )
    return () => {
      alive = false
    }
  }, [session, reloadKey])

  const refresh = useCallback(() => {
    setRefreshing(true)
    setReloadKey((value) => value + 1)
    window.setTimeout(() => setRefreshing(false), 700)
  }, [])

  const signIn = useCallback(() => {
    setSession('signed-in')
    navigate('/dashboard')
  }, [])

  const signOut = useCallback(() => {
    clearToken()
    setCounts(null)
    setSession('signed-out')
    navigate('/dashboard')
  }, [])

  if (session === 'checking') {
    return (
      <div className="splash">
        <div className="loading">
          <span className="spinner" />
          Verifying administrator access…
        </div>
      </div>
    )
  }

  if (session === 'signed-out') {
    return (
      <ToastProvider>
        <Login onSignedIn={signIn} />
      </ToastProvider>
    )
  }

  return (
    <ToastProvider>
      <Console
        section={section}
        id={id}
        reloadKey={reloadKey}
        counts={counts}
        onRefresh={refresh}
        onSignOut={signOut}
        refreshing={refreshing}
      />
    </ToastProvider>
  )
}
