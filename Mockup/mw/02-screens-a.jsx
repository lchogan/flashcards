// MW — Screens A
const { MW, MWFont, MWGrid, MWEyebrow, MWPill, MWButton, MWDeckPaper, MWFlat, MWProgress, MWTopBar, MWTabs, MWDot, MWIcon } = window;
const { IOSStatusBar, IOSKeyboard } = window;

const MW_DECKS = [
  { title: 'Cellular Biology', topic: 'Biology', accent: MW.color.red, cards: 142, last: '2d ago', sessions: 18, label: 'Familiar', pct: 58, due: 12 },
  { title: 'Spanish · B2 Verbs', topic: 'Spanish', accent: MW.color.blue, cards: 88, last: 'Today', sessions: 31, label: 'Strong', pct: 82, due: 4 },
  { title: 'Constitutional Law', topic: 'Law', accent: MW.color.yellow, cards: 204, last: '5d ago', sessions: 4, label: 'Learning', pct: 22, due: 2 },
  { title: 'Roman History', topic: 'History', accent: MW.color.ink, cards: 67, last: '1w ago', sessions: 9, label: 'Familiar', pct: 48, due: 0 },
];

// ═══ SCREEN: HOME ═══
const MWScreenHome = () => (
  <MWGrid>
    <IOSStatusBar />
    <MWTopBar
      left={MWIcon.profile()}
      center={<div style={{ fontSize: 13, fontWeight: 700, letterSpacing: 1.4, textTransform: 'uppercase' }}>Decks</div>}
      right={MWIcon.plus()}
    />
    {/* Daily strip */}
    <div style={{ padding: '20px 20px 0' }}>
      <MWFlat accent={MW.color.yellow} accentPos="top" style={{ padding: '14px 16px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ fontSize: 34, fontWeight: 700, letterSpacing: -1, lineHeight: 1, fontVariantNumeric: 'tabular-nums' }}>18</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 13, fontWeight: 700 }}>cards due today</div>
            <div style={{ fontSize: 11, color: MW.color.inkMuted, marginTop: 2 }}>3 decks · est. 7 min · 4-day streak</div>
          </div>
          <MWPill tiny active>Start →</MWPill>
        </div>
      </MWFlat>
    </div>

    {/* Topic pills */}
    <div style={{ padding: '18px 20px 12px', display: 'flex', gap: 6, overflow: 'hidden' }}>
      <MWPill active>All · 12</MWPill>
      <MWPill color={MW.color.red}>Biology</MWPill>
      <MWPill color={MW.color.blue}>Spanish</MWPill>
      <MWPill color={MW.color.yellow}>Law</MWPill>
      <MWPill>History</MWPill>
    </div>
    <div style={{ padding: '0 20px 14px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
      <MWEyebrow>12 decks · 3 due</MWEyebrow>
      <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>{MWIcon.sort()}<MWEyebrow>Mastery ↓</MWEyebrow></div>
    </div>

    <div style={{ padding: '0 20px 40px', display: 'flex', flexDirection: 'column', gap: 14 }}>
      {MW_DECKS.map((d, i) => (
        <MWDeckPaper key={i} accent={d.accent}>
          <div style={{ padding: '14px 16px 14px 18px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 8 }}>
              <div>
                <div style={{ fontSize: 16, fontWeight: 700, letterSpacing: -0.2 }}>{d.title}</div>
                <div style={{ marginTop: 5, display: 'flex', gap: 6 }}>
                  <MWPill tiny color={d.accent}>{d.topic}</MWPill>
                  {d.due > 0 && <MWPill tiny color={MW.color.ink} active>{d.due} due</MWPill>}
                </div>
              </div>
              <MWEyebrow>{d.last}</MWEyebrow>
            </div>
            <div style={{ display: 'flex', gap: 12, fontSize: 11, color: MW.color.inkMuted, marginBottom: 10 }}>
              <span>{d.cards} cards</span><span>·</span><span>{d.sessions} sessions</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 10, fontWeight: 700, letterSpacing: 0.8, textTransform: 'uppercase', marginBottom: 5 }}>
              <span>{d.label}</span>
              <span style={{ fontVariantNumeric: 'tabular-nums' }}>{d.pct}%</span>
            </div>
            <MWProgress pct={d.pct} endCap={d.accent}/>
          </div>
        </MWDeckPaper>
      ))}
    </div>
  </MWGrid>
);

// ═══ SCREEN: SEARCH ═══
const MWScreenSearch = () => (
  <MWGrid>
    <IOSStatusBar />
    <MWTopBar
      left={<div style={{ fontSize: 12, fontWeight: 700 }}>Cancel</div>}
      center={<div style={{ fontSize: 13, fontWeight: 700, letterSpacing: 1.4, textTransform: 'uppercase' }}>Search</div>}
      right={null}
    />
    <div style={{ padding: '16px 20px 0' }}>
      <MWFlat style={{ padding: '10px 12px', display: 'flex', alignItems: 'center', gap: 8 }}>
        {MWIcon.search(MW.color.ink, 16)}
        <span style={{ fontSize: 14 }}>mitochondria</span>
        <div style={{ width: 1.5, height: 16, background: MW.color.ink, marginLeft: -2, animation: 'none' }} />
        <div style={{ flex: 1 }} />
        <div style={{ fontSize: 10, color: MW.color.inkMuted }}>24 results</div>
      </MWFlat>
    </div>

    <div style={{ padding: '20px 20px 0' }}>
      <MWEyebrow style={{ marginBottom: 10 }}>Decks · 2</MWEyebrow>
      <MWFlat>
        {[
          { t: 'Cellular Biology', s: '7 matches', c: MW.color.red },
          { t: 'Organic Chemistry', s: '3 matches', c: MW.color.blue },
        ].map((r, i, a) => (
          <div key={i} style={{ padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12, borderBottom: i < a.length - 1 ? `1px solid ${MW.color.grid}` : 'none' }}>
            <div style={{ width: 4, alignSelf: 'stretch', background: r.c }} />
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 13, fontWeight: 700 }}>{r.t}</div>
              <div style={{ fontSize: 11, color: MW.color.inkMuted, marginTop: 2 }}>{r.s}</div>
            </div>
            <div>→</div>
          </div>
        ))}
      </MWFlat>
    </div>

    <div style={{ padding: '20px 20px 40px' }}>
      <MWEyebrow style={{ marginBottom: 10 }}>Cards · 24</MWEyebrow>
      <MWFlat>
        {[
          { q: 'What is the primary function of the mitochondrial matrix?', deck: 'Cellular Biology' },
          { q: 'Name the inner membrane of the mitochondrion', deck: 'Cellular Biology' },
          { q: 'Mitochondria evolved from which ancestor?', deck: 'Cellular Biology' },
          { q: 'How many mitochondria in an average liver cell?', deck: 'Cellular Biology' },
        ].map((c, i, a) => (
          <div key={i} style={{ padding: '12px 14px', borderBottom: i < a.length - 1 ? `1px solid ${MW.color.grid}` : 'none' }}>
            <div style={{ fontSize: 12.5, fontWeight: 600, lineHeight: 1.35 }}>
              What is the primary function of the <mark style={{ background: MW.color.yellow, color: MW.color.ink, padding: '0 2px' }}>mitochondria</mark>l matrix?
            </div>
            <div style={{ fontSize: 10, color: MW.color.inkMuted, marginTop: 4, textTransform: 'uppercase', letterSpacing: 0.6 }}>{c.deck}</div>
          </div>
        ))}
      </MWFlat>
    </div>
  </MWGrid>
);

// ═══ SCREEN: DECK DETAIL · HISTORY ═══
const MWScreenDeckHistory = () => (
  <MWGrid>
    <IOSStatusBar />
    <MWTopBar
      left={MWIcon.back()}
      center={<MWEyebrow>Deck 01</MWEyebrow>}
      right={MWIcon.dots()}
    />
    <div style={{ padding: '14px 20px 0' }}>
      <MWPill tiny color={MW.color.red}>Biology</MWPill>
      <div style={{ fontSize: 26, fontWeight: 700, letterSpacing: -0.5, lineHeight: 1.05, marginTop: 8 }}>Cellular<br/>Biology</div>
      <div style={{ fontSize: 11, color: MW.color.inkMuted, marginTop: 6 }}>142 cards · 18 sessions · 5h studied</div>
    </div>

    <div style={{ padding: '18px 20px 0', display: 'flex', flexDirection: 'column', gap: 8 }}>
      <MWButton icon={MWIcon.spark('#fff', 12)} hint="Focus on 23 weak cards" variant="primary">Smart Study</MWButton>
      <MWButton hint="Review all 142 cards" variant="secondary">Basic Study</MWButton>
    </div>

    <div style={{ padding: '22px 20px 0' }}>
      <MWTabs tabs={['History', 'Cards · 142']} active={0} />
    </div>

    {/* Mastery */}
    <div style={{ padding: '20px 20px 0' }}>
      <MWEyebrow style={{ marginBottom: 8 }}>Mastery</MWEyebrow>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
        <div style={{ fontSize: 44, fontWeight: 700, letterSpacing: -1.2, lineHeight: 1 }}>58</div>
        <div style={{ fontSize: 18, fontWeight: 700, color: MW.color.inkMuted }}>%</div>
        <MWEyebrow style={{ marginLeft: 8 }}>Familiar</MWEyebrow>
      </div>
      <div style={{ display: 'flex', height: 10, border: `${MW.border.std}px solid ${MW.color.ink}`, marginTop: 12 }}>
        <div style={{ flex: 82, background: MW.color.ink }}/>
        <div style={{ flex: 37, background: MW.color.yellow, borderLeft: `${MW.border.std}px solid ${MW.color.ink}` }}/>
        <div style={{ flex: 23, background: MW.color.paper, borderLeft: `${MW.border.std}px solid ${MW.color.ink}` }}/>
      </div>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8, fontSize: 10, textTransform: 'uppercase', letterSpacing: 0.6 }}>
        <span><MWDot c={MW.color.ink} /> <span style={{ marginLeft: 4 }}>82 Known</span></span>
        <span><MWDot c={MW.color.yellow} ring /> <span style={{ marginLeft: 4 }}>37 Learning</span></span>
        <span><MWDot c="#fff" ring /> <span style={{ marginLeft: 4 }}>23 Unseen</span></span>
      </div>
    </div>

    {/* Chart */}
    <div style={{ padding: '22px 20px 0' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 8 }}>
        <MWEyebrow>Accuracy · 12 sessions</MWEyebrow>
        <MWEyebrow color={MW.color.red}>▲ +14%</MWEyebrow>
      </div>
      <MWFlat style={{ padding: 12, height: 110 }}>
        <svg viewBox="0 0 300 90" preserveAspectRatio="none" style={{ width: '100%', height: '100%' }}>
          {[22,45,68].map((y,i)=><line key={i} x1="0" y1={y} x2="300" y2={y} stroke={MW.color.grid} strokeDasharray="2 3"/>)}
          <polyline fill="none" stroke={MW.color.ink} strokeWidth="1.8"
            points="0,70 27,58 54,65 81,48 108,52 135,40 162,44 189,32 216,36 243,22 270,28 300,18"/>
          {[70,58,65,48,52,40,44,32,36,22,28,18].map((y,i)=>(
            <circle key={i} cx={i*27} cy={y} r="2.5" fill={i===11 ? MW.color.red : '#fff'} stroke={MW.color.ink} strokeWidth="1.5"/>
          ))}
        </svg>
      </MWFlat>
    </div>

    {/* stats */}
    <div style={{ padding: '18px 20px 0', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
      {[
        { v: '142', l: 'Cards' },
        { v: '18', l: 'Sessions' },
        { v: '71%', l: 'Avg Accuracy', c: MW.color.yellow },
        { v: '4d', l: 'Streak', c: MW.color.red },
      ].map((s, i) => (
        <MWFlat key={i} style={{ padding: '12px 14px', position: 'relative' }}>
          {s.c && <div style={{ position: 'absolute', top: 8, right: 8, width: 8, height: 8, background: s.c, borderRadius: '50%' }} />}
          <div style={{ fontSize: 22, fontWeight: 700, letterSpacing: -0.5 }}>{s.v}</div>
          <MWEyebrow style={{ marginTop: 2 }}>{s.l}</MWEyebrow>
        </MWFlat>
      ))}
    </div>

    {/* Weak areas */}
    <div style={{ padding: '22px 20px 40px' }}>
      <MWEyebrow style={{ marginBottom: 10 }}>Weak areas</MWEyebrow>
      <MWFlat>
        {[
          { tag: 'Mitochondria', pct: 34 },
          { tag: 'Golgi apparatus', pct: 41 },
          { tag: 'Ribosomes', pct: 52 },
        ].map((w, i, arr) => (
          <div key={i} style={{ padding: '12px 14px', borderBottom: i < arr.length - 1 ? `1px solid ${MW.color.grid}` : 'none', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ fontSize: 13, fontWeight: 600 }}>{w.tag}</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <div style={{ width: 50 }}><MWProgress pct={w.pct} height={4} endCap={MW.color.red}/></div>
              <div style={{ fontSize: 11, fontWeight: 700, fontVariantNumeric: 'tabular-nums', width: 28, textAlign: 'right' }}>{w.pct}%</div>
            </div>
          </div>
        ))}
      </MWFlat>
    </div>
  </MWGrid>
);

// ═══ SCREEN: DECK DETAIL · CARDS ═══
const MWScreenDeckCards = () => (
  <MWGrid>
    <IOSStatusBar />
    <MWTopBar left={MWIcon.back()} center={<MWEyebrow>Deck 01</MWEyebrow>} right={MWIcon.dots()} />
    <div style={{ padding: '14px 20px 0' }}>
      <MWPill tiny color={MW.color.red}>Biology</MWPill>
      <div style={{ fontSize: 22, fontWeight: 700, letterSpacing: -0.4, marginTop: 8 }}>Cellular Biology</div>
    </div>
    <div style={{ padding: '18px 20px 0' }}>
      <MWTabs tabs={['History', 'Cards · 142']} active={1} />
    </div>

    {/* search + add */}
    <div style={{ padding: '14px 20px 0', display: 'flex', gap: 8 }}>
      <MWFlat style={{ flex: 1, padding: '8px 12px', display: 'flex', alignItems: 'center', gap: 8 }}>
        {MWIcon.search(MW.color.inkMuted, 14)}
        <span style={{ fontSize: 12, color: MW.color.inkMuted }}>Search cards</span>
      </MWFlat>
      <div style={{ width: 38, border: `${MW.border.std}px solid ${MW.color.ink}`, background: MW.color.ink, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        {MWIcon.plus('#fff')}
      </div>
    </div>

    {/* filters */}
    <div style={{ padding: '12px 20px 0', display: 'flex', gap: 6 }}>
      <MWPill tiny active>All · 142</MWPill>
      <MWPill tiny color={MW.color.red}>Weak · 23</MWPill>
      <MWPill tiny>Learning · 37</MWPill>
      <MWPill tiny>Known · 82</MWPill>
    </div>

    <div style={{ padding: '14px 20px 40px', display: 'flex', flexDirection: 'column', gap: 8 }}>
      {[
        { f: 'What is the primary function of the mitochondrial matrix?', b: 'Site of the citric acid (Krebs) cycle and oxidative phosphorylation.', tag: 'Organelles', level: 'again' },
        { f: 'What are cristae?', b: 'Folded invaginations of the inner mitochondrial membrane.', tag: 'Organelles', level: 'hard' },
        { f: 'Define endosymbiotic theory', b: 'Hypothesis that mitochondria and plastids originated from prokaryotes.', tag: 'Theory', level: 'good' },
        { f: 'What is ATP synthase?', b: 'Enzyme complex that produces ATP from ADP using a proton gradient.', tag: 'Enzymes', level: 'easy' },
        { f: 'What does the Golgi apparatus do?', b: 'Modifies, sorts and packages proteins for secretion.', tag: 'Organelles', level: 'hard' },
      ].map((c, i) => {
        const levelColor = MW.color[c.level];
        return (
          <MWFlat key={i} accent={levelColor}>
            <div style={{ padding: '12px 14px 12px 18px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 10 }}>
                <div style={{ flex: 1, fontSize: 13, fontWeight: 700, lineHeight: 1.3 }}>{c.f}</div>
                <MWPill tiny>{c.tag}</MWPill>
              </div>
              <div style={{ fontSize: 11, color: MW.color.inkMuted, marginTop: 4, lineHeight: 1.4 }}>{c.b}</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 8 }}>
                <MWDot c={levelColor} />
                <MWEyebrow color={levelColor}>{c.level}</MWEyebrow>
                <span style={{ flex: 1 }} />
                <div style={{ fontSize: 10, color: MW.color.inkFaint }}>#{String(342 + i).padStart(4, '0')}</div>
              </div>
            </div>
          </MWFlat>
        );
      })}
    </div>
  </MWGrid>
);

Object.assign(window, { MWScreenHome, MWScreenSearch, MWScreenDeckHistory, MWScreenDeckCards });
