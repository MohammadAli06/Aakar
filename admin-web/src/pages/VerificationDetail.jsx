import { useEffect, useState } from 'react'
import { api, apiImage } from '../lib/api.js'
import { loadQueue, EVIDENCE_LABEL, REQUIRED_EVIDENCE } from '../lib/verification.js'
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
  Loading,
  Modal,
  PageHead,
  Pill,
  Select,
} from '../components/Ui.jsx'
import { Icon } from '../components/Icons.jsx'

const DECISIONS = [
  { value: 'verified', label: 'Approve — mark this profile verified' },
  { value: 'needs_correction', label: 'Request a correction' },
  { value: 'rejected', label: 'Reject this submission' },
]

function useEvidence(recordId, kinds) {
  const [images, setImages] = useState({})
  const [failed, setFailed] = useState({})
  const key = kinds.join(',')

  useEffect(() => {
    if (!recordId || !key) return undefined
    let alive = true
    const created = []
    key.split(',').forEach((kind) => {
      apiImage(`/auth/verification-admin/${recordId}/evidence/${kind}`).then(
        (url) => {
          created.push(url)
          if (alive) setImages((map) => ({ ...map, [kind]: url }))
        },
        () => {
          if (alive) setFailed((map) => ({ ...map, [kind]: true }))
        },
      )
    })
    return () => {
      alive = false
      created.forEach((url) => URL.revokeObjectURL(url))
    }
  }, [recordId, key])

  return { images, failed }
}

export function VerificationDetail({ recordId, reloadKey }) {
  const state = useAsync(loadQueue, [reloadKey])
  const notify = useToast()
  const [decision, setDecision] = useState('verified')
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [lightbox, setLightbox] = useState(null)

  const row = (state.data || []).find((item) => item.record_id === recordId)
  const kinds = row ? REQUIRED_EVIDENCE[row.role] || [] : []
  const uploaded = row ? kinds.filter((kind) => row.evidence?.[kind]) : []
  const { images, failed } = useEvidence(row?.record_id, uploaded)

  async function submitDecision() {
    if (!note.trim()) {
      notify('A written explanation is required — it is shown to the applicant.', 'error')
      return
    }
    setBusy(true)
    try {
      await api(`/auth/verification-admin/${row.record_id}`, {
        method: 'PUT',
        body: { status: decision, note: note.trim() },
      })
      notify('Decision recorded and written to the audit trail.', 'success')
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
        title="Verification review"
        desc="Check the submitted evidence, then record one decision with an explanation."
        actions={
          <Button variant="ghost" size="sm" onClick={() => navigate('/verification')}>
            Back to queue
          </Button>
        }
      />

      <Async state={state} label="Loading the submission…">
        {() =>
          row ? (
            <div className="stack">
              <div className="row-wrap">
                <Pill status={row.status} />
                <Pill status={row.role} tone="role">
                  {label(row.role)}
                </Pill>
                {row.submitted_at ? (
                  <span className="chip">
                    <Icon name="clock" size={13} /> Submitted {dateTime(row.submitted_at)}
                  </span>
                ) : null}
                {!row.is_active ? (
                  <span className="pill danger">
                    <span className="dot" />
                    Account disabled
                  </span>
                ) : null}
              </div>

              <div className="grid grid-1-2">
                <div className="stack">
                  <Card title="Applicant">
                    <KV
                      items={[
                        ['Name', row.name],
                        [
                          'Contact',
                          <span key="contact">
                            {row.phone || '—'}
                            {row.email ? (
                              <>
                                <br />
                                <span className="muted">{row.email}</span>
                              </>
                            ) : null}
                          </span>,
                        ],
                        ['Role', label(row.role)],
                        ['Location', row.location],
                        ['Craft', row.craft_category ? label(row.craft_category) : null],
                        ['Business', row.business_name],
                        ['Profile verified', row.is_verified ? 'Yes' : 'No'],
                      ]}
                    />
                    <div style={{ marginTop: 16 }}>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => navigate('/accounts/' + row.user_id)}
                      >
                        Open account record <Icon name="chevron" size={13} />
                      </Button>
                    </div>
                  </Card>

                  <Card title="Decision" sub="Only pending submissions can be reviewed">
                    {row.status === 'pending' ? (
                      <>
                        <Field label="Outcome">
                          <Select value={decision} onChange={setDecision} options={DECISIONS} />
                        </Field>
                        <div style={{ marginTop: 14 }}>
                          <Field
                            label="Review note"
                            hint="Required. Explain what you saw, or exactly what the applicant must correct."
                          >
                            <textarea
                              className="textarea"
                              value={note}
                              maxLength={2000}
                              placeholder="Documents match the registered name and craft. Selfie is clear."
                              onChange={(event) => setNote(event.target.value)}
                            />
                          </Field>
                        </div>
                        <div className="row" style={{ marginTop: 14 }}>
                          <Button onClick={submitDecision} disabled={busy}>
                            {busy ? 'Saving…' : 'Record decision'}
                          </Button>
                          <span className="muted" style={{ fontSize: 12 }}>
                            Writing a note is mandatory.
                          </span>
                        </div>
                        <div className="mt-16">
                          <Banner icon="shield">
                            Approving marks the role profile verified. A later profile edit invalidates this
                            review and can require re-review.
                          </Banner>
                        </div>
                      </>
                    ) : (
                      <div className="stack" style={{ gap: 12 }}>
                        <Banner tone="warning" icon="alert">
                          This submission is <strong>{label(row.status)}</strong>, so the decision form is
                          closed. Only pending submissions can be reviewed.
                        </Banner>
                        <KV
                          items={[
                            ['Status', <Pill key="s" status={row.status} />],
                            ['Review note', row.review_note],
                            ['Submitted', dateTime(row.submitted_at)],
                          ]}
                        />
                      </div>
                    )}
                  </Card>
                </div>

                <Card
                  title="Submitted evidence"
                  sub={`${uploaded.length} of ${kinds.length} required file${kinds.length === 1 ? '' : 's'} uploaded`}
                >
                  {!row.record_id ? (
                    <Empty
                      icon="file"
                      title="No submission yet"
                      text="This account has not submitted verification evidence, so there is nothing to review."
                    />
                  ) : (
                    <div className="evidence-grid">
                      {kinds.map((kind) => {
                        const url = images[kind]
                        return (
                          <figure className="evidence-tile" key={kind} style={{ margin: 0 }}>
                            {url ? (
                              <img
                                src={url}
                                alt={EVIDENCE_LABEL[kind] || kind}
                                onClick={() => setLightbox({ url, caption: EVIDENCE_LABEL[kind] || kind })}
                                style={{ cursor: 'zoom-in' }}
                              />
                            ) : (
                              <div className="evidence-empty">
                                {failed[kind] ? 'Image unavailable' : 'Loading…'}
                              </div>
                            )}
                            <figcaption className="caption">
                              {EVIDENCE_LABEL[kind] || label(kind)}
                              <span style={{ marginLeft: 'auto' }}>
                                {row.evidence?.[kind] ? (
                                  <Icon name="check" size={14} />
                                ) : (
                                  <span className="muted">missing</span>
                                )}
                              </span>
                            </figcaption>
                          </figure>
                        )
                      })}
                    </div>
                  )}
                  <div className="mt-16">
                    <Banner tone="warning" icon="alert">
                      Evidence is personal data. It is shown only to an authenticated reviewer and is never
                      cached by this console.
                    </Banner>
                  </div>
                </Card>
              </div>
            </div>
          ) : (
            <Card>
              <Empty
                icon="search"
                title="Submission not found"
                text="This review record no longer exists, or the backend was restarted without it."
                action={
                  <Button variant="ghost" size="sm" onClick={() => navigate('/verification')}>
                    Back to queue
                  </Button>
                }
              />
            </Card>
          )
        }
      </Async>

      <Modal
        open={Boolean(lightbox)}
        title={lightbox?.caption || 'Evidence'}
        sub="Private review evidence"
        onClose={() => setLightbox(null)}
        wide
      >
        {lightbox ? <img src={lightbox.url} alt={lightbox.caption} /> : <Loading />}
      </Modal>
    </>
  )
}
