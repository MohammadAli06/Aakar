import { Icon } from './Icons.jsx'
import { navigate } from '../lib/router.jsx'
import { label as titleCase } from '../lib/format.js'

const NAV = [
  {
    group: 'Overview',
    items: [{ key: 'dashboard', text: 'Dashboard', icon: 'dashboard' }],
  },
  {
    group: 'Review',
    items: [
      { key: 'verification', text: 'Verification', icon: 'shield', badge: 'pending' },
      { key: 'accounts', text: 'Accounts', icon: 'users' },
      { key: 'products', text: 'Products', icon: 'package', badge: 'flagged' },
      { key: 'issues', text: 'Order issues', icon: 'alert', badge: 'issues' },
    ],
  },
  {
    group: 'Insight',
    items: [
      { key: 'analytics', text: 'Analytics', icon: 'chart' },
      { key: 'activity', text: 'Audit trail', icon: 'activity' },
    ],
  },
  {
    group: 'Administration',
    items: [
      { key: 'platform', text: 'Platform', icon: 'settings' },
      { key: 'deferred', text: 'Deferred scope', icon: 'file' },
    ],
  },
]

function sectionTitle(section) {
  if (section === 'deferred') return 'Deferred scope'
  return titleCase(section)
}

export function Layout({ section, counts, onSignOut, onRefresh, refreshing, children }) {
  const badgeFor = (key) => {
    if (!counts) return null
    if (key === 'pending') return counts.verifications?.pending || 0
    if (key === 'flagged') return counts.products?.flagged || 0
    if (key === 'issues') return counts.open_issues ?? null
    return null
  }

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="sidebar-brand">
          <span className="brand-mark">
            <Icon name="leaf" size={21} />
          </span>
          <div>
            <div className="brand-name">Aakar</div>
            <div className="brand-sub">Admin console</div>
          </div>
        </div>

        <nav className="nav-group">
          {NAV.map((group) => (
            <div key={group.group}>
              <div className="nav-label">{group.group}</div>
              {group.items.map((item) => {
                const badge = item.badge ? badgeFor(item.badge) : null
                return (
                  <button
                    key={item.key}
                    type="button"
                    className={'nav-item' + (section === item.key ? ' active' : '')}
                    onClick={() => navigate('/' + item.key)}
                  >
                    <Icon name={item.icon} size={17} className="nav-icon" />
                    <span>{item.text}</span>
                    {badge ? <span className="nav-count alert">{badge}</span> : null}
                  </button>
                )
              })}
            </div>
          ))}
        </nav>

        <div className="sidebar-foot">
          <button type="button" className="nav-item" onClick={onSignOut}>
            <Icon name="logout" size={17} className="nav-icon" />
            <span>Sign out</span>
          </button>
        </div>
      </aside>

      <div className="main">
        <header className="topbar">
          <div style={{ minWidth: 0 }}>
            <div className="topbar-title">{sectionTitle(section)}</div>
            <div className="topbar-sub">Verification, moderation and review — shared backend database</div>
          </div>
          <div className="topbar-actions">
            <button type="button" className="icon-btn" onClick={onRefresh} disabled={refreshing} aria-label="Refresh">
              <Icon name="refresh" size={16} />
            </button>
            <span className="user-chip">
              <span className="avatar">AD</span>
              Administrator
            </span>
          </div>
        </header>
        <main className="content">{children}</main>
      </div>
    </div>
  )
}
