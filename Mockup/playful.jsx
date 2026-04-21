// Playful Museum Object — warm cream, saturated colors, subtle rotation, color-blocking

const pmColors = {
  bg: '#FBF7EF',
  card: '#FFFCF4',
  ink: '#1A1A1A',
  muted: '#7A7366',
  border: '#1A1A1A',
  red: '#FF3B30',
  blue: '#0A84FF',
  yellow: '#FFD60A',
  green: '#30D158',
  pink: '#FF9BAE',
};

const pmFont = '"GT America", "Suisse Intl", Inter, system-ui, sans-serif';

const PMBg = ({ children }) => (
  <div style={{
    background: pmColors.bg,
    minHeight: '100%',
    fontFamily: pmFont,
    color: pmColors.ink,
    backgroundImage: `radial-gradient(circle at 1px 1px, rgba(0,0,0,0.05) 1px, transparent 0)`,
    backgroundSize: '16px 16px',
  }}>{children}</div>
);

// ─── HOME ───
const PMHome = () => (
  <PMBg>
    <IOSStatusBar />
    <div style={{ padding: '54px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
      <div style={{ width: 32, height: 32, borderRadius: '50%', background: pmColors.yellow, border: `2px solid ${pmColors.ink}` }} />
      <div style={{ fontSize: 18, fontWeight: 800, letterSpacing: -0.3 }}>Decks</div>
      <div style={{ width: 32, height: 32, borderRadius: '50%', background: pmColors.red, border: `2px solid ${pmColors.ink}`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontSize: 18, fontWeight: 700 }}>+</div>
    </div>

    {/* Daily strip as a "ticket" */}
    <div style={{ margin: '20px 20px 0', background: pmColors.yellow, border: `2px solid ${pmColors.ink}`, borderRadius: 12, padding: 14, position: 'relative', transform: 'rotate(-0.6deg)', boxShadow: `4px 4px 0 ${pmColors.ink}` }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <div style={{ fontSize: 28 }}>⚡</div>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 15, fontWeight: 800 }}>18 cards due today</div>
          <div style={{ fontSize: 12, color: pmColors.ink, opacity: 0.7, marginTop: 2 }}>est. 7 min — keep your 4-day streak</div>
        </div>
        <div style={{ background: pmColors.ink, color: '#fff', padding: '6px 12px', borderRadius: 20, fontSize: 12, fontWeight: 700 }}>Start</div>
      </div>
    </div>

    {/* pills */}
    <div style={{ padding: '20px 20px 12px', display: 'flex', gap: 8, overflow: 'hidden' }}>
      {[
        { t: 'All', active: true, c: pmColors.ink },
        { t: 'Biology', c: pmColors.red },
        { t: 'Spanish', c: pmColors.blue },
        { t: 'Law', c: pmColors.yellow },
        { t: 'History', c: pmColors.green },
      ].map((p, i) => (
        <div key={i} style={{
          padding: '7px 14px',
          border: `2px solid ${pmColors.ink}`,
          borderRadius: 20,
          background: p.active ? p.c : 'transparent',
          color: p.active ? '#fff' : pmColors.ink,
          fontSize: 13, fontWeight: 700, whiteSpace: 'nowrap',
        }}>{p.t}</div>
      ))}
    </div>

    {/* sort */}
    <div style={{ padding: '0 20px 14px', display: 'flex', justifyContent: 'space-between', fontSize: 12, color: pmColors.muted, fontWeight: 600 }}>
      <span>12 decks</span>
      <span>Mastery ↓</span>
    </div>

    {/* Decks as objects */}
    <div style={{ padding: '0 20px 40px', display: 'flex', flexDirection: 'column', gap: 18 }}>
      {[
        { title: 'Cellular Biology', topic: 'Biology', accent: pmColors.red, cards: 142, last: '2d ago', pct: 0.58, label: 'Familiar', rotate: -0.8, object: '🧬' },
        { title: 'Spanish · B2 Verbs', topic: 'Spanish', accent: pmColors.blue, cards: 88, last: 'Today', pct: 0.82, label: 'Strong', rotate: 0.6, object: '🗣' },
        { title: 'Constitutional Law', topic: 'Law', accent: pmColors.yellow, cards: 204, last: '5d ago', pct: 0.22, label: 'Learning', rotate: -0.4, object: '⚖' },
        { title: 'Roman History', topic: 'History', accent: pmColors.green, cards: 67, last: '1w ago', pct: 0.48, label: 'Familiar', rotate: 0.5, object: '🏛' },
      ].map((d, i) => (
        <div key={i} style={{
          background: pmColors.card,
          border: `2px solid ${pmColors.ink}`,
          borderRadius: 14,
          boxShadow: `5px 5px 0 ${pmColors.ink}`,
          transform: `rotate(${d.rotate}deg)`,
          overflow: 'hidden',
        }}>
          {/* color header */}
          <div style={{ background: d.accent, padding: '12px 16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: `2px solid ${pmColors.ink}` }}>
            <div style={{ fontSize: 11, fontWeight: 800, letterSpacing: 1, textTransform: 'uppercase', color: pmColors.ink }}>{d.topic}</div>
            <div style={{ fontSize: 18 }}>{d.object}</div>
          </div>
          <div style={{ padding: '14px 16px 16px' }}>
            <div style={{ fontSize: 18, fontWeight: 800, letterSpacing: -0.3 }}>{d.title}</div>
            <div style={{ fontSize: 11, color: pmColors.muted, marginTop: 3 }}>{d.cards} cards · {d.last}</div>
            <div style={{ marginTop: 12 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11, fontWeight: 700, marginBottom: 4 }}>
                <span>{d.label}</span>
                <span style={{ fontVariantNumeric: 'tabular-nums' }}>{Math.round(d.pct * 100)}%</span>
              </div>
              <div style={{ height: 10, background: '#fff', border: `1.5px solid ${pmColors.ink}`, borderRadius: 6, position: 'relative', overflow: 'hidden' }}>
                <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: `${d.pct * 100}%`, background: d.accent, borderRight: `1.5px solid ${pmColors.ink}` }} />
              </div>
            </div>
          </div>
        </div>
      ))}
    </div>
  </PMBg>
);

// ─── DECK DETAIL / HISTORY ───
const PMDeckDetail = () => (
  <PMBg>
    <IOSStatusBar />
    <div style={{ padding: '54px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
      <div style={{ width: 32, height: 32, borderRadius: '50%', background: pmColors.card, border: `2px solid ${pmColors.ink}`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 14, fontWeight: 700 }}>←</div>
      <div style={{ fontSize: 11, color: pmColors.muted, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 1 }}>Deck</div>
      <div style={{ width: 32, height: 32, borderRadius: '50%', background: pmColors.card, border: `2px solid ${pmColors.ink}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>⋯</div>
    </div>

    {/* title card with color block */}
    <div style={{ margin: '16px 20px 0', background: pmColors.card, border: `2px solid ${pmColors.ink}`, borderRadius: 14, boxShadow: `5px 5px 0 ${pmColors.ink}`, overflow: 'hidden' }}>
      <div style={{ background: pmColors.red, padding: '14px 18px', borderBottom: `2px solid ${pmColors.ink}`, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ fontSize: 11, fontWeight: 800, letterSpacing: 1, textTransform: 'uppercase' }}>Biology</div>
        <div style={{ fontSize: 22 }}>🧬</div>
      </div>
      <div style={{ padding: '16px 18px' }}>
        <div style={{ fontSize: 28, fontWeight: 800, letterSpacing: -0.8, lineHeight: 1.05 }}>Cellular Biology</div>
        <div style={{ fontSize: 12, color: pmColors.muted, marginTop: 6 }}>142 cards · 18 sessions · 5h studied</div>
      </div>
    </div>

    {/* actions */}
    <div style={{ padding: '18px 20px 0', display: 'flex', gap: 10 }}>
      <div style={{ flex: 1.3, background: pmColors.blue, border: `2px solid ${pmColors.ink}`, borderRadius: 12, boxShadow: `3px 3px 0 ${pmColors.ink}`, padding: '12px 14px', color: '#fff' }}>
        <div style={{ fontSize: 18 }}>✦</div>
        <div style={{ fontSize: 14, fontWeight: 800, marginTop: 4 }}>Smart Study</div>
        <div style={{ fontSize: 10.5, opacity: 0.85, marginTop: 2 }}>23 weak cards</div>
      </div>
      <div style={{ flex: 1, background: pmColors.card, border: `2px solid ${pmColors.ink}`, borderRadius: 12, boxShadow: `3px 3px 0 ${pmColors.ink}`, padding: '12px 14px' }}>
        <div style={{ fontSize: 18 }}>↻</div>
        <div style={{ fontSize: 14, fontWeight: 800, marginTop: 4 }}>Basic</div>
        <div style={{ fontSize: 10.5, color: pmColors.muted, marginTop: 2 }}>All 142</div>
      </div>
    </div>

    {/* tabs */}
    <div style={{ padding: '20px 20px 0' }}>
      <div style={{ display: 'inline-flex', background: pmColors.card, border: `2px solid ${pmColors.ink}`, borderRadius: 24, padding: 3 }}>
        <div style={{ padding: '6px 16px', background: pmColors.ink, color: '#fff', borderRadius: 20, fontSize: 12, fontWeight: 700 }}>History</div>
        <div style={{ padding: '6px 16px', fontSize: 12, fontWeight: 700, color: pmColors.muted }}>Cards · 142</div>
      </div>
    </div>

    {/* Mastery display — circular */}
    <div style={{ padding: '18px 20px 0' }}>
      <div style={{ background: pmColors.card, border: `2px solid ${pmColors.ink}`, borderRadius: 14, padding: 16, display: 'flex', alignItems: 'center', gap: 16 }}>
        <div style={{ position: 'relative', width: 80, height: 80, flexShrink: 0 }}>
          <svg viewBox="0 0 80 80" style={{ width: '100%', height: '100%' }}>
            <circle cx="40" cy="40" r="32" fill="none" stroke={pmColors.ink} strokeWidth="1.5"/>
            <circle cx="40" cy="40" r="32" fill="none" stroke={pmColors.red} strokeWidth="8"
              strokeDasharray={`${0.58 * 201} 201`} transform="rotate(-90 40 40)" strokeLinecap="butt"/>
            <text x="40" y="44" textAnchor="middle" fontSize="18" fontWeight="800" fill={pmColors.ink}>58%</text>
          </svg>
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 14, fontWeight: 800 }}>You know ~58% of this deck</div>
          <div style={{ display: 'flex', gap: 10, marginTop: 8, fontSize: 11 }}>
            <span><span style={{ display: 'inline-block', width: 8, height: 8, background: pmColors.red, borderRadius: 2, marginRight: 4, verticalAlign: 'middle' }}/>82 Known</span>
            <span><span style={{ display: 'inline-block', width: 8, height: 8, background: pmColors.yellow, borderRadius: 2, marginRight: 4, verticalAlign: 'middle' }}/>37 Learn</span>
          </div>
          <div style={{ fontSize: 11, marginTop: 4 }}>
            <span><span style={{ display: 'inline-block', width: 8, height: 8, background: '#fff', border: `1.5px solid ${pmColors.ink}`, borderRadius: 2, marginRight: 4, verticalAlign: 'middle' }}/>23 Unseen</span>
          </div>
        </div>
      </div>
    </div>

    {/* Line chart */}
    <div style={{ padding: '14px 20px 0' }}>
      <div style={{ background: pmColors.card, border: `2px solid ${pmColors.ink}`, borderRadius: 14, padding: 14 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 8 }}>
          <div style={{ fontSize: 12, fontWeight: 800 }}>Accuracy trend</div>
          <div style={{ fontSize: 11, fontWeight: 800, color: pmColors.green, background: '#fff', border: `1.5px solid ${pmColors.ink}`, padding: '2px 8px', borderRadius: 10 }}>+14%</div>
        </div>
        <svg viewBox="0 0 300 80" preserveAspectRatio="none" style={{ width: '100%', height: 90 }}>
          <path d="M0,70 L27,58 L54,65 L81,48 L108,52 L135,40 L162,44 L189,32 L216,36 L243,22 L270,28 L300,18 L300,80 L0,80 Z" fill={pmColors.yellow} opacity="0.5"/>
          <polyline fill="none" stroke={pmColors.ink} strokeWidth="2.5"
            points="0,70 27,58 54,65 81,48 108,52 135,40 162,44 189,32 216,36 243,22 270,28 300,18"/>
          <circle cx="300" cy="18" r="5" fill={pmColors.red} stroke={pmColors.ink} strokeWidth="2"/>
        </svg>
      </div>
    </div>

    {/* Stats grid */}
    <div style={{ padding: '14px 20px 0', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
      {[
        { v: '71%', l: 'Accuracy', c: pmColors.yellow },
        { v: '4d', l: 'Streak', c: pmColors.red },
        { v: '18', l: 'Sessions', c: pmColors.blue },
        { v: '5h', l: 'Studied', c: pmColors.green },
      ].map((s, i) => (
        <div key={i} style={{ background: pmColors.card, border: `2px solid ${pmColors.ink}`, borderRadius: 12, padding: 12, position: 'relative', overflow: 'hidden' }}>
          <div style={{ position: 'absolute', top: 0, right: 0, width: 18, height: 18, background: s.c, borderLeft: `2px solid ${pmColors.ink}`, borderBottom: `2px solid ${pmColors.ink}`, borderBottomLeftRadius: 10 }} />
          <div style={{ fontSize: 22, fontWeight: 800, letterSpacing: -0.6 }}>{s.v}</div>
          <div style={{ fontSize: 11, color: pmColors.muted, fontWeight: 600, marginTop: 2 }}>{s.l}</div>
        </div>
      ))}
    </div>

    <div style={{ height: 40 }} />
  </PMBg>
);

// ─── SMART STUDY ───
const PMStudy = () => (
  <PMBg>
    <IOSStatusBar />
    <div style={{ padding: '54px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
      <div style={{ width: 32, height: 32, borderRadius: '50%', background: pmColors.card, border: `2px solid ${pmColors.ink}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>×</div>
      <div style={{ background: pmColors.blue, color: '#fff', padding: '5px 12px', borderRadius: 20, fontSize: 11, fontWeight: 800, border: `2px solid ${pmColors.ink}` }}>✦ Smart</div>
      <div style={{ fontSize: 12, fontWeight: 700, fontVariantNumeric: 'tabular-nums' }}>03/23</div>
    </div>

    {/* progress dots */}
    <div style={{ padding: '16px 20px 0' }}>
      <div style={{ display: 'flex', gap: 3 }}>
        {Array.from({ length: 23 }).map((_, i) => (
          <div key={i} style={{
            flex: 1,
            height: 5,
            background: i < 2 ? pmColors.green : (i === 2 ? pmColors.red : '#fff'),
            border: `1.5px solid ${pmColors.ink}`,
            borderRadius: 3,
          }}/>
        ))}
      </div>
    </div>

    {/* Card */}
    <div style={{ padding: '36px 24px 0' }}>
      <div style={{ position: 'relative' }}>
        {/* stacked rotated card shadow */}
        <div style={{ position: 'absolute', inset: 0, background: pmColors.yellow, border: `2px solid ${pmColors.ink}`, borderRadius: 18, transform: 'rotate(-2deg)' }} />
        <div style={{ position: 'absolute', inset: 0, background: pmColors.card, border: `2px solid ${pmColors.ink}`, borderRadius: 18, transform: 'rotate(1deg)' }} />
        <div style={{ position: 'relative', background: pmColors.card, border: `2px solid ${pmColors.ink}`, borderRadius: 18, boxShadow: `6px 6px 0 ${pmColors.ink}`, padding: '22px 22px 26px', minHeight: 320 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ background: pmColors.red, color: '#fff', padding: '3px 10px', borderRadius: 12, border: `1.5px solid ${pmColors.ink}`, fontSize: 10, fontWeight: 800, textTransform: 'uppercase', letterSpacing: 0.8 }}>Organelles</div>
            <div style={{ fontSize: 10, color: pmColors.muted, fontWeight: 600 }}>tap to flip</div>
          </div>
          <div style={{ marginTop: 30, fontSize: 11, color: pmColors.muted, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 1 }}>Question</div>
          <div style={{ fontSize: 24, fontWeight: 800, letterSpacing: -0.5, lineHeight: 1.2, marginTop: 8 }}>
            What is the primary function of the mitochondrial matrix?
          </div>
          <div style={{ position: 'absolute', bottom: 16, left: 22, right: 22, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ fontSize: 10, color: pmColors.muted, fontVariantNumeric: 'tabular-nums' }}>#0342</div>
            <div style={{ display: 'flex', gap: 4 }}>
              <div style={{ width: 10, height: 10, background: pmColors.red, borderRadius: '50%', border: `1.5px solid ${pmColors.ink}` }}/>
              <div style={{ width: 10, height: 10, background: pmColors.yellow, borderRadius: '50%', border: `1.5px solid ${pmColors.ink}` }}/>
              <div style={{ width: 10, height: 10, background: pmColors.blue, borderRadius: '50%', border: `1.5px solid ${pmColors.ink}` }}/>
            </div>
          </div>
        </div>
      </div>
    </div>

    {/* actions */}
    <div style={{ position: 'absolute', bottom: 40, left: 20, right: 20 }}>
      <div style={{ fontSize: 11, fontWeight: 700, textAlign: 'center', color: pmColors.muted, marginBottom: 10 }}>How well did you recall?</div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 7 }}>
        {[
          { l: 'Again', c: pmColors.red },
          { l: 'Hard', c: '#FF9500' },
          { l: 'Good', c: pmColors.green },
          { l: 'Easy', c: pmColors.blue },
        ].map((b, i) => (
          <div key={i} style={{ background: b.c, color: '#fff', border: `2px solid ${pmColors.ink}`, borderRadius: 12, padding: '12px 4px', textAlign: 'center', fontSize: 12, fontWeight: 800, boxShadow: `2px 2px 0 ${pmColors.ink}` }}>{b.l}</div>
        ))}
      </div>
    </div>
  </PMBg>
);

// ─── SUMMARY ───
const PMSummary = () => (
  <PMBg>
    <IOSStatusBar />
    <div style={{ padding: '54px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
      <div style={{ fontSize: 11, color: pmColors.muted, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 1 }}>Session Complete</div>
      <div style={{ width: 32, height: 32, borderRadius: '50%', background: pmColors.card, border: `2px solid ${pmColors.ink}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>×</div>
    </div>

    {/* Headline card */}
    <div style={{ margin: '20px 20px 0', background: pmColors.green, border: `2px solid ${pmColors.ink}`, borderRadius: 18, boxShadow: `6px 6px 0 ${pmColors.ink}`, padding: 20, position: 'relative', transform: 'rotate(-0.8deg)' }}>
      <div style={{ fontSize: 13, fontWeight: 800, color: pmColors.ink, textTransform: 'uppercase', letterSpacing: 1 }}>✦ Smart Study</div>
      <div style={{ fontSize: 36, fontWeight: 800, letterSpacing: -1, lineHeight: 1, marginTop: 8, color: '#fff' }}>Nice work!</div>
      <div style={{ fontSize: 13, color: 'rgba(255,255,255,0.9)', marginTop: 8, lineHeight: 1.4 }}>You improved 8 weak cards — keep the 4-day streak alive.</div>
      <div style={{ position: 'absolute', top: 12, right: 16, fontSize: 34 }}>🎯</div>
    </div>

    {/* Score */}
    <div style={{ margin: '16px 20px 0', background: pmColors.card, border: `2px solid ${pmColors.ink}`, borderRadius: 14, boxShadow: `4px 4px 0 ${pmColors.ink}`, padding: 16, transform: 'rotate(0.5deg)' }}>
      <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontSize: 11, color: pmColors.muted, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 1 }}>Accuracy</div>
          <div style={{ fontSize: 56, fontWeight: 800, letterSpacing: -2, lineHeight: 1 }}>87<span style={{ fontSize: 24, color: pmColors.muted }}>%</span></div>
        </div>
        <div style={{ background: pmColors.red, color: '#fff', border: `2px solid ${pmColors.ink}`, borderRadius: 20, padding: '6px 12px', fontSize: 12, fontWeight: 800 }}>↑ +14</div>
      </div>
      <div style={{ display: 'flex', height: 12, marginTop: 16, border: `2px solid ${pmColors.ink}`, borderRadius: 8, overflow: 'hidden' }}>
        {[
          { f: 20, c: pmColors.blue },
          { f: 14, c: pmColors.green },
          { f: 4, c: '#FF9500' },
          { f: 3, c: pmColors.red },
        ].map((s, i) => (
          <div key={i} style={{ flex: s.f, background: s.c, borderLeft: i > 0 ? `2px solid ${pmColors.ink}` : 'none' }} />
        ))}
      </div>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8, fontSize: 10.5, color: pmColors.muted, fontWeight: 700 }}>
        <span>20 Easy</span><span>14 Good</span><span>4 Hard</span><span>3 Again</span>
      </div>
    </div>

    {/* Improved chips */}
    <div style={{ padding: '20px 20px 0' }}>
      <div style={{ fontSize: 11, fontWeight: 800, color: pmColors.muted, textTransform: 'uppercase', letterSpacing: 1, marginBottom: 10 }}>Cards improved (3)</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {[
          { t: 'Mitochondrial matrix role', was: 'Learning', now: 'Familiar', rot: -0.5 },
          { t: 'ATP synthase complex', was: 'Again', now: 'Good', rot: 0.4 },
          { t: 'Krebs cycle products', was: 'Hard', now: 'Good', rot: -0.3 },
        ].map((c, i) => (
          <div key={i} style={{ background: pmColors.card, border: `2px solid ${pmColors.ink}`, borderRadius: 10, padding: '10px 12px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', transform: `rotate(${c.rot}deg)`, boxShadow: `2px 2px 0 ${pmColors.ink}` }}>
            <div style={{ fontSize: 13, fontWeight: 700 }}>{c.t}</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 10, fontWeight: 700 }}>
              <span style={{ color: pmColors.muted }}>{c.was}</span>
              <span>→</span>
              <span style={{ background: pmColors.green, color: '#fff', padding: '2px 6px', borderRadius: 8, border: `1.5px solid ${pmColors.ink}` }}>{c.now}</span>
            </div>
          </div>
        ))}
      </div>
    </div>

    <div style={{ padding: '24px 20px 40px', display: 'flex', flexDirection: 'column', gap: 10 }}>
      <div style={{ background: pmColors.blue, color: '#fff', padding: '14px', textAlign: 'center', fontSize: 14, fontWeight: 800, border: `2px solid ${pmColors.ink}`, borderRadius: 14, boxShadow: `4px 4px 0 ${pmColors.ink}` }}>Continue Smart Study</div>
      <div style={{ background: pmColors.card, padding: '12px', textAlign: 'center', fontSize: 14, fontWeight: 700, border: `2px solid ${pmColors.ink}`, borderRadius: 14 }}>Review mistakes (3)</div>
    </div>
  </PMBg>
);

Object.assign(window, { PMHome, PMDeckDetail, PMStudy, PMSummary });
