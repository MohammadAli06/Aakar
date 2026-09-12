/* Thin fetch client for the Aakar backend.

   The admin credential is the separate `ADMIN_ACCESS_TOKEN` bearer token. It is
   kept in sessionStorage (cleared when the tab closes) and sent on every request.
   A 403 on a stored token means the backend no longer accepts it, so the app
   signs out instead of retrying in a loop. */

const API_ROOT = (import.meta.env.VITE_API_BASE_URL || '/api/v1').replace(/\/+$/, '')
const STORAGE_KEY = 'aakar.admin.token'

let token = ''

try {
  token = sessionStorage.getItem(STORAGE_KEY) || ''
} catch {
  token = ''
}

export class ApiError extends Error {
  constructor(message, status) {
    super(message)
    this.name = 'ApiError'
    this.status = status
  }
}

export function getToken() {
  return token
}

export function setToken(value) {
  token = value || ''
  try {
    if (token) sessionStorage.setItem(STORAGE_KEY, token)
    else sessionStorage.removeItem(STORAGE_KEY)
  } catch {
    /* private mode: the token simply will not persist */
  }
}

export function clearToken() {
  setToken('')
}

function resolve(path) {
  if (/^https?:\/\//i.test(path)) return path
  return path.startsWith('/api/') ? path : API_ROOT + path
}

function describe(data, status) {
  const value = data && typeof data === 'object' && 'detail' in data ? data.detail : data
  if (typeof value === 'string' && value.trim()) return value
  if (Array.isArray(value)) {
    return value
      .map((item) => item?.msg || JSON.stringify(item))
      .join('; ')
  }
  if (value && typeof value === 'object') return JSON.stringify(value)
  if (status === 0) return 'Cannot reach the backend.'
  if (status === 403) return 'The backend rejected this administrator token.'
  return `Request failed (${status})`
}

async function readBody(response) {
  const text = await response.text()
  if (!text) return null
  try {
    return JSON.parse(text)
  } catch {
    return text
  }
}

export async function api(path, options = {}) {
  const { method = 'GET', body, token: override, signal } = options
  const headers = { Accept: 'application/json' }
  const credential = override === undefined ? token : override
  if (credential) headers.Authorization = 'Bearer ' + credential
  if (body !== undefined) headers['Content-Type'] = 'application/json'

  let response
  try {
    response = await fetch(resolve(path), {
      method,
      headers,
      signal,
      body: body === undefined ? undefined : JSON.stringify(body),
    })
  } catch (error) {
    if (error?.name === 'AbortError') throw error
    throw new ApiError('Cannot reach the backend. Check that it is running and the API URL is correct.', 0)
  }

  const data = await readBody(response)

  if (!response.ok) {
    if (response.status === 403 && credential && override === undefined) {
      window.dispatchEvent(new Event('aakar:unauthorized'))
    }
    throw new ApiError(describe(data, response.status), response.status)
  }
  return data
}

/** Fetch a protected image (review evidence, workspace media) as an object URL. */
export async function apiImage(path) {
  let response
  try {
    response = await fetch(resolve(path), {
      headers: token ? { Authorization: 'Bearer ' + token } : {},
    })
  } catch {
    throw new ApiError('Cannot reach the backend for this image.', 0)
  }
  if (!response.ok) {
    if (response.status === 403 && token) window.dispatchEvent(new Event('aakar:unauthorized'))
    throw new ApiError('Image unavailable', response.status)
  }
  return URL.createObjectURL(await response.blob())
}
