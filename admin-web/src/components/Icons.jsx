const PATHS = {
  dashboard: (
    <>
      <rect x="3" y="3" width="7.5" height="7.5" rx="1.6" />
      <rect x="13.5" y="3" width="7.5" height="7.5" rx="1.6" />
      <rect x="3" y="13.5" width="7.5" height="7.5" rx="1.6" />
      <rect x="13.5" y="13.5" width="7.5" height="7.5" rx="1.6" />
    </>
  ),
  users: (
    <>
      <path d="M16 19.5v-1.6a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v1.6" />
      <circle cx="9.5" cy="7.5" r="3.3" />
      <path d="M21 19.5v-1.6a4 4 0 0 0-3-3.85" />
      <path d="M15.4 4.6a3.3 3.3 0 0 1 0 6.2" />
    </>
  ),
  shield: (
    <>
      <path d="M12 3l7 2.8v5.4c0 4.2-2.9 7.9-7 9.6-4.1-1.7-7-5.4-7-9.6V5.8L12 3Z" />
      <path d="m9 11.8 2.2 2.3 4.2-4.6" />
    </>
  ),
  package: (
    <>
      <path d="M20 8.4v7.3a2 2 0 0 1-1 1.7l-6 3.4a2 2 0 0 1-2 0l-6-3.4a2 2 0 0 1-1-1.7V8.4" />
      <path d="m3.4 7.5 7.6-4.3a2 2 0 0 1 2 0l7.6 4.3" />
      <path d="m3.6 7.7 8.4 4.7 8.4-4.7" />
      <path d="M12 12.4V20" />
    </>
  ),
  alert: (
    <>
      <path d="M10.3 4 2.6 17.3A2 2 0 0 0 4.3 20.4h15.4a2 2 0 0 0 1.7-3.1L13.7 4a2 2 0 0 0-3.4 0Z" />
      <path d="M12 9.2v4.2" />
      <path d="M12 16.9h.01" />
    </>
  ),
  chart: (
    <>
      <path d="M3.5 20.5h17" />
      <path d="M6.5 20.5v-6.2" />
      <path d="M12 20.5V7.8" />
      <path d="M17.5 20.5v-8.6" />
    </>
  ),
  activity: (
    <>
      <path d="M3 12.5h3.8l2.4-7.2 5 13.4 2.2-6.2H21" />
    </>
  ),
  settings: (
    <>
      <path d="M4 7h9M17 7h3M4 12h3M11 12h9M4 17h9M17 17h3" />
      <circle cx="15" cy="7" r="2.1" />
      <circle cx="9" cy="12" r="2.1" />
      <circle cx="15" cy="17" r="2.1" />
    </>
  ),
  plug: (
    <>
      <path d="M9 3v5M15 3v5" />
      <path d="M7 8h10v2.2a5 5 0 0 1-10 0V8Z" />
      <path d="M12 15.2V21" />
    </>
  ),
  help: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M9.6 9.3a2.5 2.5 0 0 1 4.8 1c0 1.7-2.4 2.1-2.4 3.6" />
      <path d="M12 17.2h.01" />
    </>
  ),
  logout: (
    <>
      <path d="m15.5 17 5-5-5-5" />
      <path d="M20.5 12H9.5" />
      <path d="M12.5 20H5.5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h7" />
    </>
  ),
  search: (
    <>
      <circle cx="11" cy="11" r="7" />
      <path d="m20 20-3.7-3.7" />
    </>
  ),
  refresh: (
    <>
      <path d="M20.5 12a8.5 8.5 0 1 1-2.5-6" />
      <path d="M21 4.5v5h-5" />
    </>
  ),
  chevron: <path d="m9.5 6 6 6-6 6" />,
  leaf: (
    <>
      <path d="M12 3c5 3.4 7.5 7.1 7.5 11a7.5 7.5 0 0 1-15 0C4.5 10.1 7 6.4 12 3Z" />
      <path d="M12 7.2V20" />
      <path d="M12 12.4c2.2-1 3.8-2.8 4.4-5.2M12 15.8c-2.2-.6-3.8-2.3-4.4-5.2" />
    </>
  ),
  close: <path d="M18 6 6 18M6 6l12 12" />,
  check: <path d="m5 12.8 4.2 4.2L19 7" />,
  clock: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 7.4V12l3.1 2" />
    </>
  ),
  phone: (
    <path d="M6.4 3h3.1l1.5 3.9-2 1.4a12.4 12.4 0 0 0 5.7 5.7l1.4-2L20 13.5v3.1a2 2 0 0 1-2.2 2A16.6 16.6 0 0 1 4 4.7 2 2 0 0 1 6.4 3Z" />
  ),
  mail: (
    <>
      <rect x="3" y="5" width="18" height="14" rx="2.2" />
      <path d="m3.6 7.4 8.4 5.9 8.4-5.9" />
    </>
  ),
  pin: (
    <>
      <path d="M12 21c4.6-3.6 7-7.4 7-11a7 7 0 1 0-14 0c0 3.6 2.4 7.4 7 11Z" />
      <circle cx="12" cy="10" r="2.6" />
    </>
  ),
  image: (
    <>
      <rect x="3" y="4.5" width="18" height="15" rx="2.2" />
      <circle cx="8.6" cy="9.8" r="1.8" />
      <path d="m4 17.5 5-5 4.6 4.6L16 14.6l4 3.9" />
    </>
  ),
  flag: (
    <>
      <path d="M5.5 21V3.6" />
      <path d="M5.5 4.8h11l-1.7 3.6 1.7 3.6h-11" />
    </>
  ),
  lock: (
    <>
      <rect x="4.5" y="10" width="15" height="10.5" rx="2.2" />
      <path d="M8.5 10V7.6a3.5 3.5 0 0 1 7 0V10" />
    </>
  ),
  unlock: (
    <>
      <rect x="4.5" y="10" width="15" height="10.5" rx="2.2" />
      <path d="M8.5 10V7.6a3.5 3.5 0 0 1 6.7-1.4" />
    </>
  ),
  external: (
    <>
      <path d="M14 4h6v6" />
      <path d="M20 4 11.5 12.5" />
      <path d="M18 14.5V18a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h3.5" />
    </>
  ),
  sparkle: (
    <path d="M12 3.5 13.8 9l5.7 1.9-5.7 1.9L12 18.5l-1.8-5.7L4.5 10.9 10.2 9 12 3.5Z" />
  ),
  inbox: (
    <>
      <path d="M3.4 12.5h4.8l1.4 2.4h4.8l1.4-2.4h4.8" />
      <path d="M4.8 5.4h14.4l1.4 7V18a2 2 0 0 1-2 2H5.4a2 2 0 0 1-2-2v-5.6l1.4-7Z" />
    </>
  ),
  store: (
    <>
      <path d="M4.5 9.5h15V19a1.5 1.5 0 0 1-1.5 1.5H6A1.5 1.5 0 0 1 4.5 19V9.5Z" />
      <path d="M3.4 9.5 5 4h14l1.6 5.5" />
      <path d="M9.5 20.5v-5.2h5v5.2" />
    </>
  ),
  file: (
    <>
      <path d="M13 3H7.5A2 2 0 0 0 5.5 5v14a2 2 0 0 0 2 2h9a2 2 0 0 0 2-2V9l-6-6Z" />
      <path d="M13 3v6h6" />
    </>
  ),
  ban: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="m5.8 5.8 12.4 12.4" />
    </>
  ),
  dot: <circle cx="12" cy="12" r="3.2" />,
}

export function Icon({ name, size = 18, className, strokeWidth = 1.7 }) {
  return (
    <svg
      className={className}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      {PATHS[name] || PATHS.dot}
    </svg>
  )
}
