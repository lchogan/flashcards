// ═══════════════════════════════════════════════════════════════
// MODERNIST WORKSHOP — Design System
// Tokens, primitives, and shared components.
// ═══════════════════════════════════════════════════════════════

// ─── TOKENS ───
const MW = {
  // Color
  color: {
    bg:        '#FAFAFA',
    paper:     '#FFFFFF',
    grid:      '#EAEAEA',
    rule:      '#D8D8D8',
    ink:       '#111111',
    inkMuted:  '#8A8A8A',
    inkFaint:  '#B8B8B8',

    // Primary accents — Bauhaus triad + functional greens
    red:       '#FF3B30',
    blue:      '#007AFF',
    yellow:    '#FFD60A',

    // Confidence rating — the canonical 4-color scale, used everywhere
    // the user sees Again/Hard/Good/Easy or their derived states.
    again:     '#FF3B30',  // red
    hard:      '#FF9500',  // orange
    good:      '#34C759',  // green
    easy:      '#007AFF',  // blue

    // Paper tints for sheets/sections
    paperTint: '#F4F4F2',
  },
  // Typography
  font: 'Helvetica Neue, Helvetica, Inter, system-ui, sans-serif',
  mono: '"SF Mono", "JetBrains Mono", Menlo, monospace',
  // Spacing — 8pt grid
  space: { 0.5: 4, 1: 8, 1.5: 12, 2: 16, 2.5: 20, 3: 24, 4: 32, 5: 40, 6: 48 },
  // Borders
  border: { hair: 1, std: 1.5, bold: 2.5 },
  radius: 4,
};

// Status bar wrapper for all MW screens
const MWFont = ({ children, style }) => (
  <div style={{ fontFamily: MW.font, color: MW.color.ink, ...style }}>{children}</div>
);

const MWGrid = ({ children, noGrid, tint, style }) => (
  <div style={{
    background: tint ? MW.color.paperTint : MW.color.bg,
    backgroundImage: noGrid ? 'none' : `linear-gradient(${MW.color.grid} 1px, transparent 1px), linear-gradient(90deg, ${MW.color.grid} 1px, transparent 1px)`,
    backgroundSize: '24px 24px',
    minHeight: '100%',
    fontFamily: MW.font,
    color: MW.color.ink,
    position: 'relative',
    ...style,
  }}>{children}</div>
);

// ─── PRIMITIVES ───

// Eyebrow label — uppercase 10px, used ubiquitously
const MWEyebrow = ({ children, color, style }) => (
  <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 0.8, textTransform: 'uppercase', color: color || MW.color.inkMuted, ...style }}>{children}</div>
);

// Pill — can be filled, outlined, or color-tinted
const MWPill = ({ children, color, active, tiny, style }) => (
  <div style={{
    display: 'inline-flex', alignItems: 'center', gap: 5,
    padding: tiny ? '2px 6px' : '6px 12px',
    border: `${MW.border.std}px solid ${color === 'white' ? MW.color.ink : (color || MW.color.ink)}`,
    background: active ? (color || MW.color.ink) : 'transparent',
    color: active ? (color === MW.color.yellow ? MW.color.ink : '#fff') : (color || MW.color.ink),
    fontSize: tiny ? 10 : 12, fontWeight: 600, letterSpacing: tiny ? 0.8 : 0.2,
    textTransform: tiny ? 'uppercase' : 'none',
    whiteSpace: 'nowrap',
    ...style,
  }}>{children}</div>
);

// Sharp button — primary (inverse) or secondary
const MWButton = ({ children, variant = 'primary', color, icon, hint, style, onClick }) => {
  const primary = variant === 'primary';
  return (
    <div onClick={onClick} style={{
      border: `${MW.border.std}px solid ${MW.color.ink}`,
      background: primary ? MW.color.ink : MW.color.paper,
      color: primary ? '#fff' : MW.color.ink,
      padding: '14px 18px',
      display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      cursor: 'pointer',
      ...style,
    }}>
      <div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          {icon}
          <span style={{ fontSize: 15, fontWeight: 700, letterSpacing: -0.2 }}>{children}</span>
        </div>
        {hint && <div style={{ fontSize: 11, color: primary ? 'rgba(255,255,255,0.7)' : MW.color.inkMuted, marginTop: 3 }}>{hint}</div>}
      </div>
      <div style={{ fontSize: 16 }}>→</div>
    </div>
  );
};

// Paper card with stacked shadow to suggest a deck
const MWDeckPaper = ({ children, accent, style, flat, depth = 2 }) => (
  <div style={{ position: 'relative', ...style }}>
    {!flat && Array.from({ length: depth }).map((_, i) => (
      <div key={i} style={{
        position: 'absolute',
        inset: `${(i + 1) * 2}px ${-(i + 1) * 2}px ${-(i + 1) * 2}px ${(i + 1) * 2}px`,
        background: MW.color.paper,
        border: `${MW.border.hair}px solid ${MW.color.grid}`,
      }} />
    ))}
    <div style={{ position: 'relative', background: MW.color.paper, border: `${MW.border.std}px solid ${MW.color.ink}` }}>
      {accent && <div style={{ position: 'absolute', top: 0, left: 0, bottom: 0, width: 4, background: accent }} />}
      {children}
    </div>
  </div>
);

// Flat card (for cards, stats, etc. — NOT decks)
const MWFlat = ({ children, style, accent, accentPos = 'left' }) => (
  <div style={{ position: 'relative', background: MW.color.paper, border: `${MW.border.std}px solid ${MW.color.ink}`, ...style }}>
    {accent && (
      <div style={{
        position: 'absolute',
        ...(accentPos === 'left'  ? { top: 0, left: 0, bottom: 0, width: 4 } :
            accentPos === 'top'   ? { top: 0, left: 0, right: 0, height: 4 } :
            accentPos === 'right' ? { top: 0, right: 0, bottom: 0, width: 4 } :
                                    { bottom: 0, left: 0, right: 0, height: 4 }),
        background: accent,
      }} />
    )}
    {children}
  </div>
);

// Progress bar — stark, 1px bordered
const MWProgress = ({ pct, endCap, height = 8 }) => (
  <div style={{ height, background: '#F0F0F0', position: 'relative', border: `${MW.border.hair}px solid ${MW.color.ink}` }}>
    <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: `${pct}%`, background: MW.color.ink }} />
    {endCap && <div style={{ position: 'absolute', left: `calc(${pct}% - 2px)`, top: -2, bottom: -2, width: 4, background: endCap }} />}
  </div>
);

// iOS status + nav wrapper for MW
const MWTopBar = ({ left, center, right, padTop = 56 }) => (
  <div style={{ padding: `${padTop}px 20px 0`, display: 'flex', justifyContent: 'space-between', alignItems: 'center', minHeight: 32 }}>
    <div style={{ minWidth: 50, display: 'flex', alignItems: 'center', justifyContent: 'flex-start' }}>{left}</div>
    <div style={{ flex: 1, textAlign: 'center' }}>{center}</div>
    <div style={{ minWidth: 50, display: 'flex', alignItems: 'center', justifyContent: 'flex-end' }}>{right}</div>
  </div>
);

// Tab bar — underlined active, uppercase
const MWTabs = ({ tabs, active }) => (
  <div style={{ display: 'flex', borderBottom: `${MW.border.std}px solid ${MW.color.ink}`, gap: 24 }}>
    {tabs.map((t, i) => (
      <div key={i} style={{
        padding: '10px 0',
        fontSize: 12, fontWeight: 700, letterSpacing: 0.8, textTransform: 'uppercase',
        color: active === i ? MW.color.ink : MW.color.inkMuted,
        borderBottom: active === i ? `2.5px solid ${MW.color.red}` : 'none',
        marginBottom: -1.5,
      }}>{t}</div>
    ))}
  </div>
);

// Confidence color swatch (small)
const MWDot = ({ c, size = 8, ring }) => (
  <div style={{ width: size, height: size, background: c, borderRadius: '50%', border: ring ? `1px solid ${MW.color.ink}` : 'none', flexShrink: 0 }} />
);

// Geometric icons (24px) — stroke 1.5
const MWIcon = {
  plus: (c = MW.color.ink, s = 18) => <svg width={s} height={s} viewBox="0 0 18 18"><line x1="9" y1="2" x2="9" y2="16" stroke={c} strokeWidth="1.5"/><line x1="2" y1="9" x2="16" y2="9" stroke={c} strokeWidth="1.5"/></svg>,
  back: (c = MW.color.ink, s = 18) => <svg width={s} height={s} viewBox="0 0 18 18" fill="none"><path d="M11 3L5 9l6 6" stroke={c} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  close: (c = MW.color.ink, s = 18) => <svg width={s} height={s} viewBox="0 0 18 18"><line x1="4" y1="4" x2="14" y2="14" stroke={c} strokeWidth="1.8" strokeLinecap="round"/><line x1="14" y1="4" x2="4" y2="14" stroke={c} strokeWidth="1.8" strokeLinecap="round"/></svg>,
  search: (c = MW.color.ink, s = 18) => <svg width={s} height={s} viewBox="0 0 18 18" fill="none"><circle cx="8" cy="8" r="5" stroke={c} strokeWidth="1.5"/><line x1="12" y1="12" x2="16" y2="16" stroke={c} strokeWidth="1.5" strokeLinecap="round"/></svg>,
  profile: (c = MW.color.ink, s = 18) => <svg width={s} height={s} viewBox="0 0 18 18" fill="none"><circle cx="9" cy="9" r="7" stroke={c} strokeWidth="1.5"/><circle cx="9" cy="7" r="2.5" stroke={c} strokeWidth="1.5"/><path d="M3.5 15c1-2.5 3.2-4 5.5-4s4.5 1.5 5.5 4" stroke={c} strokeWidth="1.5"/></svg>,
  dots: (c = MW.color.ink, s = 18) => <svg width={s} height={s} viewBox="0 0 18 18"><circle cx="4" cy="9" r="1.3" fill={c}/><circle cx="9" cy="9" r="1.3" fill={c}/><circle cx="14" cy="9" r="1.3" fill={c}/></svg>,
  spark: (c = MW.color.red, s = 14) => <svg width={s} height={s} viewBox="0 0 14 14"><path d="M7 0L8.5 5.5L14 7L8.5 8.5L7 14L5.5 8.5L0 7L5.5 5.5Z" fill={c}/></svg>,
  flip:  (c = MW.color.ink, s = 16) => <svg width={s} height={s} viewBox="0 0 16 16" fill="none"><path d="M2 6V3a1 1 0 011-1h10a1 1 0 011 1v3M14 10v3a1 1 0 01-1 1H3a1 1 0 01-1-1v-3" stroke={c} strokeWidth="1.5" strokeLinecap="round"/><path d="M5 8l-3-2 3-2M11 8l3-2-3-2" stroke={c} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  sort:  (c = MW.color.ink, s = 14) => <svg width={s} height={s} viewBox="0 0 14 14" fill="none"><path d="M3 3h8M4 7h6M5 11h4" stroke={c} strokeWidth="1.5" strokeLinecap="round"/></svg>,
  check: (c = MW.color.ink, s = 14) => <svg width={s} height={s} viewBox="0 0 14 14" fill="none"><path d="M3 7l3 3 5-6" stroke={c} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  trash: (c = MW.color.ink, s = 16) => <svg width={s} height={s} viewBox="0 0 16 16" fill="none"><path d="M3 4h10M6 4V2.5a1 1 0 011-1h2a1 1 0 011 1V4M4 4l.7 9a1 1 0 001 .9h4.6a1 1 0 001-.9L12 4" stroke={c} strokeWidth="1.5" strokeLinecap="round"/></svg>,
  edit:  (c = MW.color.ink, s = 16) => <svg width={s} height={s} viewBox="0 0 16 16" fill="none"><path d="M2 14l3-1L13.5 4.5a1.4 1.4 0 00-2-2L3 11l-1 3z" stroke={c} strokeWidth="1.5" strokeLinejoin="round"/></svg>,
  dup:   (c = MW.color.ink, s = 16) => <svg width={s} height={s} viewBox="0 0 16 16" fill="none"><rect x="3" y="5" width="8" height="8" stroke={c} strokeWidth="1.5"/><path d="M5 3h8v8" stroke={c} strokeWidth="1.5"/></svg>,
};

Object.assign(window, {
  MW, MWFont, MWGrid, MWEyebrow, MWPill, MWButton, MWDeckPaper, MWFlat,
  MWProgress, MWTopBar, MWTabs, MWDot, MWIcon,
});
