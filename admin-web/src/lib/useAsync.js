import { useCallback, useEffect, useRef, useState } from 'react'

/** Run an async loader, exposing loading/error/data plus a manual reload.
 *
 * The loader is held in a ref so callers can pass an inline arrow function
 * without re-running the request on every render; the request re-runs when the
 * `deps` values or a manual reload change. */
export function useAsync(loader, deps = []) {
  const [state, setState] = useState({ loading: true, data: null, error: null })
  const [nonce, setNonce] = useState(0)
  const loaderRef = useRef(loader)
  const key = deps.length ? JSON.stringify(deps) : ''

  useEffect(() => {
    loaderRef.current = loader
  }, [loader])

  useEffect(() => {
    let alive = true
    Promise.resolve()
      .then(() => loaderRef.current())
      .then(
        (data) => {
          if (alive) setState({ loading: false, data, error: null })
        },
        (error) => {
          if (alive) setState({ loading: false, data: null, error })
        },
      )
    return () => {
      alive = false
    }
  }, [key, nonce])

  const reload = useCallback(() => setNonce((value) => value + 1), [])
  return { ...state, reload }
}
