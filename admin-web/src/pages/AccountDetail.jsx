import { useState } from 'react'
import { api } from '../lib/api.js'
import { useAsync } from '../lib/useAsync.js'
import { useToast } from '../lib/toast.js'
import { navigate } from '../lib/router.jsx'
import { dateTime, label } from '../lib/format.js'
import {
  Async,
  Banner,
  Button,
  Card,
  Empty,
  Field,
  KV,
  Modal,
  PageHead,
  Pill,
} from '../components/Ui.jsx'
import { Icon } from '../components/Icons.jsx'

export function AccountDetail({ userId, reloadKey }) {
  const state = useAsync(() => api('/admin/accounts/' + userId), [reloadKey])
  const notify = useToast()
  const [dialog, setDialog] = useState(null)
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)

  async function apply(target) {
    if (!note.trim()) {
      notify('A reason is required — it is stored in the audit trail.', 'error')
      return
    }
    setBusy(true)
    try {
      await api(`/admin/accounts/${userId}/status`, {
        method: 'PUT',
        body: { is_active: target, note: note.trim() },
      })
      notify(target ? 'Account re-enabled.' : 'Account disabled. It can no longer sign in.', 'success')
      setDialog(null)
      setNote('')
      state.reload()
    } catch (error) {
      notify(error.message, 'error')
    } finally {
      setBusy(false)
    }
  }

  return (
    <>
      <PageHead
        title="Account record"
        desc="Registration details, verification state and access control for one account."
        actions={
          <Button variant="ghost" size="sm" onClick={() => navigate('/accounts')}>
            Back to accounts
          </Button>
        }
      />

      <Async state={state} label="Loading account…">
        {(account) => (
          <div className="stack">
            <div className="row-wrap">
              <span className="avatar" style={{ width: 34, height: 34, fontSize: 13 }}>
                {(account.name || 'NA')
                  .split(/\s+/)
                  .filter(Boolean)
                  .slice(0, 2)
                  .map((part) => part[0])
                  .join('')
                  .toUpperCase() || '··'}
              </span>
              <div>
                <h2 style={{ fontSize: 18 }}>{account.name || 'Name not set'}</h2>
                <div className="muted" style={{ fontSize: 12.5 }}>
                  {account.role === 'artisan' ? 'Artisan account' : 'Buyer account'} · joined{' '}
                  {dateTime(account.created_at)}
                </div>
              </div>
              <div style={{ marginLeft: 'auto' }} className="row-wrap">
                <Pill status={account.role} tone="role">
                  {label(account.role)}
                </Pill>
                <Pill status={account.verification} />
                {account.is_active ? (
                  <Pill tone="success">Active</Pill>
                ) : (
                  <Pill tone="danger">Disabled</Pill>
                )}
              </div>
            </div>

            <div className="grid grid-2">
              <Card title="Profile">
                <KV
                  items={[
                    ['Name', account.name],
                    ['Phone', account.phone],
                    ['Email', account.email],
                    ['Language', account.language_pref === 'hi' ? 'Hindi' : 'English'],
                    ['Location', account.location],
                    account.role === 'artisan' ? ['Craft category', account.craft_category ? label(account.craft_category) : null] : null,
                    account.role === 'buyer' ? ['Business name', account.business_name] : null,
                    account.role === 'buyer' ? ['Business type', account.business_type] : null,
                    account.role === 'buyer' ? ['Industry', account.industry] : null,
                    ['Products created', account.product_count],
                  ]}
                />
              </Card>

              <div className="stack">
                <Card title="Verification">
                  <KV
                    items={[
                      ['Status', <Pill key="status" status={account.verification} />],
                      ['Profile verified', account.is_verified ? 'Yes' : 'No'],
                      ['Submitted', account.submitted_at ? dateTime(account.submitted_at) : null],
                      [
                        'Evidence uploaded',
                        account.evidence?.length ? account.evidence.map(label).join(', ') : 'None',
                      ],
                      ['Last review note', account.review_note],
                    ]}
                  />
                  {account.verification === 'pending' ? (
                    <div style={{ marginTop: 16 }}>
                      <Button size="sm" onClick={() => navigate('/verification')}>
                        Open in review queue <Icon name="chevron" size={13} />
                      </Button>
                    </div>
                  ) : null}
                </Card>

                <Card title="Access control" sub="Owner of the account cannot be changed from here">
                  <Banner tone="warning" icon="alert">
                    Disabling an account blocks authentication immediately. It does not delete data, and it
                    does not cancel anything the account already agreed to.
                  </Banner>
                  <div className="row" style={{ marginTop: 16 }}>
                    {account.is_active ? (
                      <Button
                        variant="danger"
                        onClick={() => {
                          setNote('')
                          setDialog(false)
                        }}
                      >
                        <Icon name="ban" size={15} /> Disable account
                      </Button>
                    ) : (
                      <Button
                        variant="success"
                        onClick={() => {
                          setNote('')
                          setDialog(true)
                        }}
                      >
                        <Icon name="check" size={15} /> Re-enable account
                      </Button>
                    )}
                  </div>
                </Card>
              </div>
            </div>
          </div>
        )}
      </Async>

      {state.error ? (
        <Card className="mt-16">
          <Empty
            icon="search"
            title="Account not found"
            text="The record may have been removed, or the backend is using a fresh database."
            action={
              <Button variant="ghost" size="sm" onClick={() => navigate('/accounts')}>
                Back to accounts
              </Button>
            }
          />
        </Card>
      ) : null}

      <Modal
        open={dialog !== null}
        title={dialog ? 'Re-enable this account' : 'Disable this account'}
        sub="The reason is written to the administrator audit trail"
        onClose={() => setDialog(null)}
        footer={
          <>
            <Button variant="ghost" onClick={() => setDialog(null)}>
              Cancel
            </Button>
            <Button
              variant={dialog ? 'success' : 'danger'}
              disabled={busy}
              onClick={() => apply(dialog)}
            >
              {busy ? 'Saving…' : dialog ? 'Re-enable' : 'Disable'}
            </Button>
          </>
        }
      >
        <Field label="Reason" hint="For example: duplicate registration, or access restored after review.">
          <textarea
            className="textarea"
            value={note}
            maxLength={2000}
            onChange={(event) => setNote(event.target.value)}
          />
        </Field>
      </Modal>
    </>
  )
}
