import { navigate } from '../lib/router.jsx'
import { Banner, Button, Card, Empty, PageHead, Pill, SectionLabel } from '../components/Ui.jsx'
import { Icon } from '../components/Icons.jsx'

const DEFERRED = [
  {
    key: 'b2b',
    icon: 'plug',
    title: 'B2B activity monitoring',
    status: 'Later',
    text: 'Full account and channel monitoring across GeM, ONDC and state boards is deferred. External preparation in the mobile app is labelled demo guidance — it does not submit to any external channel and Aakar does not guarantee eligibility or approval.',
  },
  {
    key: 'bidding',
    icon: 'store',
    title: 'Auctions and bidding',
    status: 'Excluded',
    text: 'Sealed-bid lifecycles, eligibility and invitations, timers, monitoring and result notifications are intentionally excluded from the hackathon build. The specification is preserved as future artisan-initiated Bulk Clearance.',
  },
  {
    key: 'integrations',
    icon: 'external',
    title: 'Integrations',
    status: 'Later',
    text: 'There is no live payment provider, carrier booking, hub reservation or marketplace sync. Payments, logistics and external channels are explicit manual or simulated records, and this console never presents them as completed operations.',
  },
  {
    key: 'support',
    icon: 'help',
    title: 'Support and reporting',
    status: 'Later',
    text: 'Risk scoring, automated dispute adjudication and refunds are out of scope. Disputes are handled manually: participants flag an issue with evidence and a reviewer records the agreed outcome by hand.',
  },
]

export function Deferred({ section }) {
  const focus = DEFERRED.find((item) => item.key === section)

  return (
    <>
      <PageHead
        title="Deferred scope"
        desc="Parts of the original admin flow that are deliberately not implemented, so the console does not imply capabilities it does not have."
        actions={
          <Button variant="ghost" size="sm" onClick={() => navigate('/dashboard')}>
            Back to dashboard
          </Button>
        }
      />

      <div className="stack">
        <Banner tone="warning" icon="alert">
          The agreed build scope for the admin console is verification, basic product moderation, basic counts
          and a minimal manual order-issue queue. Everything below is recorded as future work rather than shown
          as a working screen.
        </Banner>

        {focus ? (
          <Card title={focus.title} sub={'Scope label: ' + focus.status}>
            <div className="row" style={{ alignItems: 'flex-start', gap: 13 }}>
              <span className="stat-icon" style={{ flex: 'none' }}>
                <Icon name={focus.icon} size={19} />
              </span>
              <p style={{ margin: 0, fontSize: 13, lineHeight: 1.65 }}>{focus.text}</p>
            </div>
          </Card>
        ) : null}

        <div className="grid grid-2">
          {DEFERRED.map((item) => (
            <Card
              key={item.key}
              title={item.title}
              actions={
                <Pill tone={item.status === 'Excluded' ? 'danger' : 'neutral'} dot={false}>
                  {item.status}
                </Pill>
              }
            >
              <p className="muted" style={{ margin: 0, fontSize: 12.5, lineHeight: 1.65 }}>
                {item.text}
              </p>
              <div style={{ marginTop: 14 }}>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => navigate('/deferred/' + item.key)}
                >
                  Details <Icon name="chevron" size={13} />
                </Button>
              </div>
            </Card>
          ))}
        </div>

        <Card title="What is implemented" sub="For contrast with the list above">
          <SectionLabel>Working today</SectionLabel>
          <ul style={{ margin: 0, paddingLeft: 20, fontSize: 13, lineHeight: 1.8 }}>
            <li>Artisan and buyer verification queue with approve, request-correction and reject decisions.</li>
            <li>Private evidence viewing, authenticated per request and never cached.</li>
            <li>Account directory with profile, role, verification state and access control.</li>
            <li>Product records with listing, pricing and a persisted moderation decision.</li>
            <li>Manual order-issue review when the shared demo workspace is enabled.</li>
            <li>Counts, a current-state analytics snapshot and a decision audit trail.</li>
          </ul>
          <div className="mt-16">
            <Empty
              icon="file"
              title="Scope record"
              text="The implementation checklist and context notes in docs/ are the source of truth for what is complete, partially implemented or planned."
            />
          </div>
        </Card>
      </div>
    </>
  )
}
