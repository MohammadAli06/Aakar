import { api } from './api.js'

export const REQUIRED_EVIDENCE = {
  artisan: ['identity', 'craft', 'selfie'],
  buyer: ['business'],
}

export const EVIDENCE_LABEL = {
  identity: 'Government identity',
  craft: 'Craft / workshop evidence',
  selfie: 'Live selfie',
  business: 'Business document',
}

function buildRow(record, account) {
  const owner = account || {}
  return {
    record_id: record?.id || null,
    user_id: record?.user_id || owner.id,
    role: record?.role || owner.role || 'artisan',
    name: owner.name || null,
    phone: owner.phone || null,
    email: owner.email || null,
    location: owner.location || null,
    craft_category: owner.craft_category || null,
    business_name: owner.business_name || null,
    is_active: owner.is_active ?? true,
    is_verified: owner.is_verified ?? false,
    status: record?.status || 'not_started',
    evidence: record?.evidence || {},
    review_note: record?.review_note || null,
    submitted_at: record?.submitted_at || null,
  }
}

/** The review queue joins the verification records with account names. */
export async function loadQueue() {
  const [records, accounts] = await Promise.all([
    api('/auth/verification-admin'),
    api('/admin/accounts'),
  ])
  const accountsById = new Map(accounts.map((account) => [account.id, account]))
  const rows = records.map((record) => buildRow(record, accountsById.get(record.user_id)))
  const seen = new Set(records.map((record) => record.user_id))
  for (const account of accounts) {
    if (!seen.has(account.id)) rows.push(buildRow(null, account))
  }
  return rows.sort((left, right) => {
    if (left.status === 'pending' && right.status !== 'pending') return -1
    if (right.status === 'pending' && left.status !== 'pending') return 1
    return String(right.submitted_at || '').localeCompare(String(left.submitted_at || ''))
  })
}
