// Modernist Workshop — Bauhaus-inspired, grid background, primary accents

const mwColors = {
  bg: '#FAFAFA',
  grid: '#EAEAEA',
  border: '#1A1A1A',
  muted: '#8A8A8A',
  ink: '#111',
  red: '#FF3B30',
  blue: '#007AFF',
  yellow: '#FFD60A',
  green: '#34C759',
};

const mwFont = 'Helvetica Neue, Helvetica, Inter, system-ui, sans-serif';

const MWGrid = ({ children, style }) => (
  <div style={{
    background: mwColors.bg,
    backgroundImage: `linear-gradient(${mwColors.grid} 1px, transparent 1px), linear-gradient(90deg, ${mwColors.grid} 1px, transparent 1px)`,
    backgroundSize: '24px 24px',
    minHeight: '100%',
    fontFamily: mwFont,
    color: mwColors.ink,
    ...style,
  }}>{children}</div>
);

// ─── SCREEN 1: HOME / DECK LIST ───
const MWHome = () => (
  <MWGrid>
    <IOSStatusBar />
    {/* Top bar */}
    <div style={{ padding: '56px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
      <div style={{ width: 24, height: 24, border: `1.5px solid ${mwColors.ink}`, borderRadius: '50%' }} />
      <div style={{ fontSize: 15, fontWeight: 700, letterSpacing: 1, textTransform: 'uppercase' }}>Decks</div>
      <div style={{ width: 24, height: 24, position: 'relative' }}>
        <div style={{ position: 'absolute', top: '50%', left: 0, right: 0, height: 1.5, background: mwColors.ink, transform: 'translateY(-50%)' }} />
        <div style={{ position: 'absolute', left: '50%', top: 0, bottom: 0, width: 1.5, background: mwColors.ink, transform: 'translateX(-50%)' }} />
      </div>
    </div>

    {/* Daily strip */}
    <div style={{ margin: '24px 20px 0', border: `1.5px solid ${mwColors.ink}`, background: '#fff', padding: 14, display: 'flex', alignItems: 'center', gap: 12 }}>
      <div style={{ width: 10, height: 10, background: mwColors.yellow, borderRadius: '50%' }} />
      <div style={{ flex: 1, fontSize: 13 }}>
        <div style={{ fontWeight: 700 }}>18 cards due today</div>
        <div style={{ color: mwColors.muted, fontSize: 11, marginTop: 2 }}>3 decks · est. 7 min</div>
      </div>
      <div style={{ fontSize: 11, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5, borderBottom: `1.5px solid ${mwColors.ink}`, paddingBottom: 1 }}>Start →</div>
    </div>

    {/* Topic pills */}
    <div style={{ padding: '20px 20px 16px', display: 'flex', gap: 8, overflow: 'hidden' }}>
      {[
        { t: 'All', active: true },
        { t: 'Biology', c: mwColors.red },
        { t: 'Spanish', c: mwColors.blue },
        { t: 'Law', c: mwColors.yellow },
        { t: 'History' },
      ].map((p, i) => (
        <div key={i} style={{
          padding: '6px 12px',
          border: `1.5px solid ${mwColors.ink}`,
          background: p.active ? mwColors.ink : (p.c || 'transparent'),
          color: p.active ? '#fff' : mwColors.ink,
          fontSize: 12, fontWeight: 600, whiteSpace: 'nowrap',
        }}>{p.t}</div>
      ))}
    </div>

    {/* Sort row */}
    <div style={{ padding: '0 20px 16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: 11, color: mwColors.muted, textTransform: 'uppercase', letterSpacing: 0.8 }}>
      <span>12 decks</span>
      <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>Mastery ↓</span>
    </div>

    {/* Deck cards */}
    <div style={{ padding: '0 20px 40px', display: 'flex', flexDirection: 'column', gap: 14 }}>
      {[
        { title: 'Cellular Biology', topic: 'Biology', accent: mwColors.red, cards: 142, last: '2d ago', sessions: 18, masteryLabel: 'Familiar', pct: 0.58 },
        { title: 'Spanish · B2 Verbs', topic: 'Spanish', accent: mwColors.blue, cards: 88, last: 'Today', sessions: 31, masteryLabel: 'Strong', pct: 0.82 },
        { title: 'Constitutional Law', topic: 'Law', accent: mwColors.yellow, cards: 204, last: '5d ago', sessions: 4, masteryLabel: 'Learning', pct: 0.22 },
        { title: 'Roman History', topic: 'History', accent: mwColors.ink, cards: 67, last: '1w ago', sessions: 9, masteryLabel: 'Familiar', pct: 0.48 },
      ].map((d, i) => (
        <div key={i} style={{ position: 'relative' }}>
          {/* stacked paper effect */}
          <div style={{ position: 'absolute', inset: '4px -4px -4px 4px', background: '#fff', border: `1px solid ${mwColors.grid}` }} />
          <div style={{ position: 'absolute', inset: '2px -2px -2px 2px', background: '#fff', border: `1px solid ${mwColors.grid}` }} />
          <div style={{ position: 'relative', background: '#fff', border: `1.5px solid ${mwColors.ink}`, padding: '16px 18px' }}>
            {/* accent stripe */}
            <div style={{ position: 'absolute', top: 0, left: 0, bottom: 0, width: 4, background: d.accent }} />
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 10 }}>
              <div>
                <div style={{ fontSize: 17, fontWeight: 700, letterSpacing: -0.2 }}>{d.title}</div>
                <div style={{ marginTop: 6, display: 'inline-block', fontSize: 10, fontWeight: 600, letterSpacing: 0.8, textTransform: 'uppercase', padding: '2px 6px', border: `1px solid ${mwColors.ink}` }}>{d.topic}</div>
              </div>
              <div style={{ fontSize: 10, color: mwColors.muted, textTransform: 'uppercase', letterSpacing: 0.6 }}>{d.last}</div>
            </div>
            {/* stats */}
            <div style={{ display: 'flex', gap: 16, fontSize: 11, color: mwColors.muted, marginBottom: 12 }}>
              <span>{d.cards} cards</span>
              <span>·</span>
              <span>{d.sessions} sessions</span>
            </div>
            {/* mastery */}
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 10, fontWeight: 700, letterSpacing: 0.8, textTransform: 'uppercase', marginBottom: 6 }}>
                <span>{d.masteryLabel}</span>
                <span style={{ fontVariantNumeric: 'tabular-nums' }}>{Math.round(d.pct * 100)}%</span>
              </div>
              <div style={{ height: 8, background: '#F0F0F0', position: 'relative', border: `1px solid ${mwColors.ink}` }}>
                <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: `${d.pct * 100}%`, background: mwColors.ink }} />
                <div style={{ position: 'absolute', left: `${d.pct * 100 - 2}%`, top: -2, bottom: -2, width: 4, background: d.accent }} />
              </div>
            </div>
          </div>
        </div>
      ))}
    </div>
  </MWGrid>
);

// ─── SCREEN 2: DECK DETAIL / HISTORY ───
const MWDeckDetail = () => (
  <MWGrid>
    <IOSStatusBar />
    {/* Header */}
    <div style={{ padding: '56px 20px 16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
      <div style={{ fontSize: 18, fontWeight: 700 }}>←</div>
      <div style={{ fontSize: 11, color: mwColors.muted, textTransform: 'uppercase', letterSpacing: 0.8 }}>Deck 01</div>
      <div style={{ fontSize: 18, fontWeight: 700, letterSpacing: 2 }}>···</div>
    </div>
    <div style={{ padding: '0 20px' }}>
      <div style={{ display: 'inline-block', fontSize: 10, fontWeight: 600, letterSpacing: 0.8, textTransform: 'uppercase', padding: '2px 6px', border: `1px solid ${mwColors.red}`, color: mwColors.red, marginBottom: 8 }}>Biology</div>
      <div style={{ fontSize: 26, fontWeight: 700, letterSpacing: -0.5, lineHeight: 1.1 }}>Cellular<br/>Biology</div>
      <div style={{ fontSize: 12, color: mwColors.muted, marginTop: 6 }}>142 cards · 18 sessions · 5h studied</div>
    </div>

    {/* Primary actions */}
    <div style={{ padding: '20px 20px 0', display: 'flex', flexDirection: 'column', gap: 10 }}>
      <div style={{ background: mwColors.ink, color: '#fff', padding: '16px 18px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', border: `1.5px solid ${mwColors.ink}` }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <svg width="14" height="14" viewBox="0 0 14 14"><path d="M7 0L8.5 5.5L14 7L8.5 8.5L7 14L5.5 8.5L0 7L5.5 5.5Z" fill={mwColors.red}/></svg>
            <span style={{ fontSize: 15, fontWeight: 700, letterSpacing: -0.2 }}>Smart Study</span>
          </div>
          <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.7)', marginTop: 3 }}>Focus on 23 weak cards</div>
        </div>
        <div style={{ fontSize: 16 }}>→</div>
      </div>
      <div style={{ background: '#fff', padding: '14px 18px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', border: `1.5px solid ${mwColors.ink}` }}>
        <div>
          <div style={{ fontSize: 14, fontWeight: 700 }}>Basic Study</div>
          <div style={{ fontSize: 11, color: mwColors.muted, marginTop: 3 }}>Review all 142 cards</div>
        </div>
        <div style={{ fontSize: 16 }}>→</div>
      </div>
    </div>

    {/* Tabs */}
    <div style={{ padding: '24px 20px 0', display: 'flex', borderBottom: `1.5px solid ${mwColors.ink}` }}>
      <div style={{ padding: '8px 0 8px', marginRight: 24, fontSize: 12, fontWeight: 700, letterSpacing: 0.8, textTransform: 'uppercase', borderBottom: `2.5px solid ${mwColors.red}`, marginBottom: -1.5 }}>History</div>
      <div style={{ padding: '8px 0 8px', fontSize: 12, fontWeight: 700, letterSpacing: 0.8, textTransform: 'uppercase', color: mwColors.muted }}>Cards · 142</div>
    </div>

    {/* Mastery overview */}
    <div style={{ padding: '20px 20px 0' }}>
      <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 0.8, textTransform: 'uppercase', color: mwColors.muted, marginBottom: 8 }}>Mastery</div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginBottom: 10 }}>
        <div style={{ fontSize: 40, fontWeight: 700, letterSpacing: -1, lineHeight: 1 }}>58</div>
        <div style={{ fontSize: 16, fontWeight: 700, color: mwColors.muted }}>%</div>
        <div style={{ fontSize: 11, color: mwColors.muted, marginLeft: 8 }}>you know ~58% of this deck</div>
      </div>
      {/* stacked bar */}
      <div style={{ display: 'flex', height: 10, border: `1.5px solid ${mwColors.ink}` }}>
        <div style={{ flex: 58, background: mwColors.ink }} />
        <div style={{ flex: 26, background: mwColors.yellow, borderLeft: `1.5px solid ${mwColors.ink}` }} />
        <div style={{ flex: 16, background: '#fff', borderLeft: `1.5px solid ${mwColors.ink}` }} />
      </div>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8, fontSize: 10, textTransform: 'uppercase', letterSpacing: 0.6 }}>
        <span><span style={{ display: 'inline-block', width: 8, height: 8, background: mwColors.ink, marginRight: 5, verticalAlign: 'middle' }}/>Known 82</span>
        <span><span style={{ display: 'inline-block', width: 8, height: 8, background: mwColors.yellow, border: `1px solid ${mwColors.ink}`, marginRight: 5, verticalAlign: 'middle' }}/>Learning 37</span>
        <span><span style={{ display: 'inline-block', width: 8, height: 8, background: '#fff', border: `1px solid ${mwColors.ink}`, marginRight: 5, verticalAlign: 'middle' }}/>Unseen 23</span>
      </div>
    </div>

    {/* Line chart */}
    <div style={{ padding: '24px 20px 0' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 8 }}>
        <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 0.8, textTransform: 'uppercase', color: mwColors.muted }}>Accuracy · 12 sessions</div>
        <div style={{ fontSize: 10, color: mwColors.red, fontWeight: 700 }}>+14%</div>
      </div>
      <div style={{ background: '#fff', border: `1.5px solid ${mwColors.ink}`, padding: 12, height: 110, position: 'relative' }}>
        <svg viewBox="0 0 300 90" preserveAspectRatio="none" style={{ width: '100%', height: '100%' }}>
          <line x1="0" y1="22" x2="300" y2="22" stroke={mwColors.grid} strokeDasharray="2 3"/>
          <line x1="0" y1="45" x2="300" y2="45" stroke={mwColors.grid} strokeDasharray="2 3"/>
          <line x1="0" y1="68" x2="300" y2="68" stroke={mwColors.grid} strokeDasharray="2 3"/>
          <polyline fill="none" stroke={mwColors.ink} strokeWidth="1.8"
            points="0,70 27,58 54,65 81,48 108,52 135,40 162,44 189,32 216,36 243,22 270,28 300,18"/>
          {[70,58,65,48,52,40,44,32,36,22,28,18].map((y,i)=>(
            <circle key={i} cx={i*27} cy={y} r="2.5" fill={i===11 ? mwColors.red : '#fff'} stroke={mwColors.ink} strokeWidth="1.5"/>
          ))}
        </svg>
      </div>
    </div>

    {/* Stats grid */}
    <div style={{ padding: '20px 20px 0', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
      {[
        { v: '142', l: 'Cards', c: null },
        { v: '18', l: 'Sessions', c: null },
        { v: '71%', l: 'Avg Accuracy', c: mwColors.yellow },
        { v: '4d', l: 'Streak', c: mwColors.red },
      ].map((s, i) => (
        <div key={i} style={{ background: '#fff', border: `1.5px solid ${mwColors.ink}`, padding: '12px 14px', position: 'relative' }}>
          {s.c && <div style={{ position: 'absolute', top: 8, right: 8, width: 8, height: 8, background: s.c, borderRadius: '50%' }} />}
          <div style={{ fontSize: 22, fontWeight: 700, letterSpacing: -0.5 }}>{s.v}</div>
          <div style={{ fontSize: 10, color: mwColors.muted, textTransform: 'uppercase', letterSpacing: 0.8, marginTop: 2 }}>{s.l}</div>
        </div>
      ))}
    </div>

    {/* Weak areas */}
    <div style={{ padding: '24px 20px 40px' }}>
      <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 0.8, textTransform: 'uppercase', color: mwColors.muted, marginBottom: 10 }}>Weak areas</div>
      <div style={{ background: '#fff', border: `1.5px solid ${mwColors.ink}` }}>
        {[
          { tag: 'Mitochondria', pct: 34 },
          { tag: 'Golgi apparatus', pct: 41 },
          { tag: 'Ribosomes', pct: 52 },
        ].map((w, i, arr) => (
          <div key={i} style={{ padding: '12px 14px', borderBottom: i < arr.length - 1 ? `1px solid ${mwColors.grid}` : 'none', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ fontSize: 13, fontWeight: 600 }}>{w.tag}</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <div style={{ width: 50, height: 4, background: '#F0F0F0', border: `1px solid ${mwColors.ink}`, position: 'relative' }}>
                <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: `${w.pct}%`, background: mwColors.red }}/>
              </div>
              <div style={{ fontSize: 11, fontWeight: 700, fontVariantNumeric: 'tabular-nums', width: 28, textAlign: 'right' }}>{w.pct}%</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  </MWGrid>
);

// ─── SCREEN 3: SMART STUDY CARD ───
const MWStudy = () => (
  <MWGrid>
    <IOSStatusBar />
    {/* top bar */}
    <div style={{ padding: '56px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
      <div style={{ fontSize: 16, fontWeight: 700 }}>×</div>
      <div style={{ fontSize: 11, color: mwColors.muted, textTransform: 'uppercase', letterSpacing: 0.8 }}>Smart Study</div>
      <div style={{ width: 16 }} />
    </div>

    {/* progress */}
    <div style={{ padding: '16px 20px 0' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 10, fontWeight: 700, letterSpacing: 0.8, textTransform: 'uppercase', marginBottom: 6 }}>
        <span>Card 03 / 23</span>
        <span style={{ color: mwColors.red }}>● Weak</span>
      </div>
      <div style={{ height: 3, background: '#F0F0F0', position: 'relative', border: `1px solid ${mwColors.ink}` }}>
        <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: '13%', background: mwColors.ink }} />
      </div>
    </div>

    {/* card */}
    <div style={{ padding: '40px 20px 0', display: 'flex', justifyContent: 'center' }}>
      <div style={{ position: 'relative', width: '100%' }}>
        <div style={{ position: 'absolute', inset: '4px -4px -4px 4px', background: '#fff', border: `1px solid ${mwColors.grid}` }} />
        <div style={{ position: 'absolute', inset: '2px -2px -2px 2px', background: '#fff', border: `1px solid ${mwColors.grid}` }} />
        <div style={{ position: 'relative', background: '#fff', border: `1.5px solid ${mwColors.ink}`, padding: '28px 24px', minHeight: 340 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 40 }}>
            <div style={{ display: 'inline-block', fontSize: 10, fontWeight: 600, letterSpacing: 0.8, textTransform: 'uppercase', padding: '2px 6px', border: `1px solid ${mwColors.red}`, color: mwColors.red }}>Organelles</div>
            <div style={{ fontSize: 10, color: mwColors.muted, textTransform: 'uppercase', letterSpacing: 0.8 }}>Tap to flip</div>
          </div>
          <div style={{ fontSize: 11, color: mwColors.muted, textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 12 }}>Front</div>
          <div style={{ fontSize: 26, fontWeight: 700, letterSpacing: -0.5, lineHeight: 1.2 }}>
            What is the primary function of the mitochondrial matrix?
          </div>
          {/* decoration */}
          <div style={{ position: 'absolute', bottom: 16, left: 24, right: 24, display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end' }}>
            <div style={{ fontSize: 10, color: mwColors.muted, fontVariantNumeric: 'tabular-nums' }}>#0342</div>
            <svg width="24" height="24" viewBox="0 0 24 24">
              <rect x="1" y="1" width="22" height="22" fill="none" stroke={mwColors.ink} strokeWidth="1"/>
              <circle cx="12" cy="12" r="5" fill={mwColors.yellow} stroke={mwColors.ink} strokeWidth="1"/>
            </svg>
          </div>
        </div>
      </div>
    </div>

    {/* confidence actions */}
    <div style={{ position: 'absolute', bottom: 50, left: 20, right: 20 }}>
      <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 0.8, textTransform: 'uppercase', color: mwColors.muted, marginBottom: 10, textAlign: 'center' }}>How well did you recall?</div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 6 }}>
        {[
          { l: 'Again', c: mwColors.red, t: '<1m' },
          { l: 'Hard', c: '#FF9500', t: '6m' },
          { l: 'Good', c: mwColors.green, t: '1d' },
          { l: 'Easy', c: mwColors.blue, t: '4d' },
        ].map((b, i) => (
          <div key={i} style={{ border: `1.5px solid ${mwColors.ink}`, background: '#fff', padding: '10px 4px', textAlign: 'center' }}>
            <div style={{ width: 8, height: 8, background: b.c, borderRadius: '50%', margin: '0 auto 5px' }}/>
            <div style={{ fontSize: 11, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.4 }}>{b.l}</div>
            <div style={{ fontSize: 9, color: mwColors.muted, marginTop: 2 }}>{b.t}</div>
          </div>
        ))}
      </div>
    </div>
  </MWGrid>
);

// ─── SCREEN 4: SESSION SUMMARY ───
const MWSummary = () => (
  <MWGrid>
    <IOSStatusBar />
    <div style={{ padding: '56px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
      <div style={{ fontSize: 11, color: mwColors.muted, textTransform: 'uppercase', letterSpacing: 0.8 }}>Session complete</div>
      <div style={{ fontSize: 16, fontWeight: 700 }}>×</div>
    </div>

    <div style={{ padding: '32px 20px 0' }}>
      <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 0.8, textTransform: 'uppercase', color: mwColors.red, marginBottom: 8 }}>● Smart Study · Cellular Biology</div>
      <div style={{ fontSize: 44, fontWeight: 700, letterSpacing: -1.5, lineHeight: 1 }}>Nice work.</div>
      <div style={{ fontSize: 14, color: mwColors.muted, marginTop: 8, lineHeight: 1.4 }}>You improved on <span style={{ color: mwColors.ink, fontWeight: 700 }}>8 weak cards</span> and maintained your streak.</div>
    </div>

    {/* Accuracy big number */}
    <div style={{ padding: '32px 20px 0' }}>
      <div style={{ background: '#fff', border: `1.5px solid ${mwColors.ink}`, padding: '24px 20px', position: 'relative' }}>
        <div style={{ position: 'absolute', top: 0, left: 0, width: 4, bottom: 0, background: mwColors.red }} />
        <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 0.8, textTransform: 'uppercase', color: mwColors.muted }}>Session accuracy</div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, marginTop: 6 }}>
          <div style={{ fontSize: 64, fontWeight: 700, letterSpacing: -2, lineHeight: 1 }}>87</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: mwColors.muted }}>%</div>
          <div style={{ fontSize: 12, color: mwColors.red, fontWeight: 700, marginLeft: 'auto' }}>↑ +14 vs last</div>
        </div>
        <div style={{ display: 'flex', height: 8, marginTop: 16, border: `1.5px solid ${mwColors.ink}` }}>
          {[
            { f: 20, c: mwColors.blue, l: 'Easy' },
            { f: 14, c: mwColors.green, l: 'Good' },
            { f: 4, c: '#FF9500', l: 'Hard' },
            { f: 3, c: mwColors.red, l: 'Again' },
          ].map((s, i) => (
            <div key={i} style={{ flex: s.f, background: s.c, borderLeft: i > 0 ? `1.5px solid ${mwColors.ink}` : 'none' }} />
          ))}
        </div>
        <div style={{ display: 'flex', marginTop: 8, fontSize: 10, color: mwColors.muted, textTransform: 'uppercase', letterSpacing: 0.6 }}>
          <span style={{ flex: 20 }}>20 Easy</span>
          <span style={{ flex: 14 }}>14 Good</span>
          <span style={{ flex: 4 }}>4 Hard</span>
          <span style={{ flex: 3 }}>3 Again</span>
        </div>
      </div>
    </div>

    {/* Cards improved */}
    <div style={{ padding: '16px 20px 0' }}>
      <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 0.8, textTransform: 'uppercase', color: mwColors.muted, marginBottom: 10 }}>Improved</div>
      <div style={{ background: '#fff', border: `1.5px solid ${mwColors.ink}` }}>
        {[
          { t: 'Mitochondrial matrix role', was: 'Learning', now: 'Familiar' },
          { t: 'ATP synthase complex', was: 'Again', now: 'Good' },
          { t: 'Krebs cycle products', was: 'Hard', now: 'Good' },
        ].map((c, i, arr) => (
          <div key={i} style={{ padding: '12px 14px', borderBottom: i < arr.length - 1 ? `1px solid ${mwColors.grid}` : 'none', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ fontSize: 13, fontWeight: 600 }}>{c.t}</div>
            <div style={{ fontSize: 10, textTransform: 'uppercase', letterSpacing: 0.6, display: 'flex', alignItems: 'center', gap: 6 }}>
              <span style={{ color: mwColors.muted }}>{c.was}</span>
              <span>→</span>
              <span style={{ color: mwColors.red, fontWeight: 700 }}>{c.now}</span>
            </div>
          </div>
        ))}
      </div>
    </div>

    {/* actions */}
    <div style={{ padding: '24px 20px 40px', display: 'flex', flexDirection: 'column', gap: 8 }}>
      <div style={{ background: mwColors.ink, color: '#fff', padding: '14px 18px', textAlign: 'center', fontSize: 13, fontWeight: 700, letterSpacing: 0.4, textTransform: 'uppercase', border: `1.5px solid ${mwColors.ink}` }}>Continue Smart Study</div>
      <div style={{ background: '#fff', padding: '12px 18px', textAlign: 'center', fontSize: 13, fontWeight: 700, letterSpacing: 0.4, textTransform: 'uppercase', border: `1.5px solid ${mwColors.ink}` }}>Review Mistakes (3)</div>
    </div>
  </MWGrid>
);

Object.assign(window, { MWHome, MWDeckDetail, MWStudy, MWSummary });
