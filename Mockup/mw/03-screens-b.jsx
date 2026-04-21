// MW — Screens B
const { MW, MWGrid, MWEyebrow, MWPill, MWButton, MWDeckPaper, MWFlat, MWProgress, MWTopBar, MWTabs, MWDot, MWIcon } = window;
const { IOSStatusBar, IOSKeyboard } = window;

// ═══ SMART STUDY · CARD FRONT ═══
const MWScreenStudySmart = () => (
  <MWGrid>
    <IOSStatusBar />
    <MWTopBar
      left={MWIcon.close()}
      center={<div style={{ display: 'flex', alignItems: 'center', gap: 6, justifyContent: 'center' }}>{MWIcon.spark(MW.color.red, 11)}<MWEyebrow>Smart Study</MWEyebrow></div>}
      right={<MWEyebrow>03/23</MWEyebrow>}
    />
    <div style={{ padding: '14px 20px 0' }}>
      <div style={{ display: 'flex', gap: 3 }}>
        {Array.from({ length: 23 }).map((_, i) => (
          <div key={i} style={{ flex: 1, height: 4, background: i < 2 ? MW.color.good : (i === 2 ? MW.color.red : '#F0F0F0'), border: `1px solid ${MW.color.ink}` }}/>
        ))}
      </div>
    </div>

    <div style={{ padding: '34px 20px 0' }}>
      <MWDeckPaper accent={MW.color.red} depth={2}>
        <div style={{ padding: '22px 22px 22px 26px', minHeight: 340, position: 'relative' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 36 }}>
            <MWPill tiny color={MW.color.red}>Organelles</MWPill>
            <MWEyebrow>Tap to flip</MWEyebrow>
          </div>
          <MWEyebrow style={{ marginBottom: 12 }}>Front</MWEyebrow>
          <div style={{ fontSize: 26, fontWeight: 700, letterSpacing: -0.5, lineHeight: 1.2 }}>
            What is the primary function of the mitochondrial matrix?
          </div>
          <div style={{ position: 'absolute', bottom: 18, left: 26, right: 22, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ fontSize: 10, color: MW.color.inkFaint, fontVariantNumeric: 'tabular-nums' }}>#0342</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 4, color: MW.color.inkMuted }}>{MWIcon.flip(MW.color.inkMuted, 14)}</div>
          </div>
        </div>
      </MWDeckPaper>
    </div>

    {/* coming up */}
    <div style={{ padding: '18px 20px 0' }}>
      <MWEyebrow>Up next · 20 more</MWEyebrow>
      <div style={{ display: 'flex', gap: 6, marginTop: 8, overflow: 'hidden' }}>
        {['Organelles', 'Krebs', 'Enzymes', 'Membrane'].map((t, i) => (
          <MWPill tiny key={i}>{t}</MWPill>
        ))}
      </div>
    </div>
  </MWGrid>
);

// ═══ SMART STUDY · CARD BACK (with confidence rating) ═══
const MWScreenStudyBack = () => (
  <MWGrid>
    <IOSStatusBar />
    <MWTopBar
      left={MWIcon.close()}
      center={<div style={{ display: 'flex', alignItems: 'center', gap: 6, justifyContent: 'center' }}>{MWIcon.spark(MW.color.red, 11)}<MWEyebrow>Smart Study</MWEyebrow></div>}
      right={<MWEyebrow>03/23</MWEyebrow>}
    />
    <div style={{ padding: '14px 20px 0' }}>
      <div style={{ display: 'flex', gap: 3 }}>
        {Array.from({ length: 23 }).map((_, i) => (
          <div key={i} style={{ flex: 1, height: 4, background: i < 2 ? MW.color.good : (i === 2 ? MW.color.red : '#F0F0F0'), border: `1px solid ${MW.color.ink}` }}/>
        ))}
      </div>
    </div>

    <div style={{ padding: '20px 20px 0' }}>
      <MWDeckPaper accent={MW.color.red} depth={1}>
        <div style={{ padding: '18px 18px 18px 22px' }}>
          <MWPill tiny color={MW.color.red}>Organelles</MWPill>
          <MWEyebrow style={{ marginTop: 10 }}>Front</MWEyebrow>
          <div style={{ fontSize: 15, fontWeight: 700, marginTop: 4, lineHeight: 1.3 }}>What is the primary function of the mitochondrial matrix?</div>
          <div style={{ height: 1, background: MW.color.ink, margin: '14px -18px 14px -22px' }} />
          <MWEyebrow>Back</MWEyebrow>
          <div style={{ fontSize: 15, fontWeight: 600, marginTop: 4, lineHeight: 1.4 }}>
            Site of the <span style={{ background: MW.color.yellow, padding: '0 2px' }}>citric acid (Krebs) cycle</span> and oxidative phosphorylation. Contains mitochondrial DNA, ribosomes, and the enzymes needed to produce ATP.
          </div>
          <div style={{ display: 'flex', gap: 6, marginTop: 12 }}>
            <MWPill tiny>Krebs cycle</MWPill>
            <MWPill tiny>ATP</MWPill>
          </div>
        </div>
      </MWDeckPaper>
    </div>

    {/* Confidence rating — prominently color coded */}
    <div style={{ position: 'absolute', bottom: 44, left: 20, right: 20 }}>
      <MWEyebrow style={{ textAlign: 'center', marginBottom: 10 }}>How well did you recall?</MWEyebrow>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 6 }}>
        {[
          { l: 'Again', c: MW.color.again, t: '<1m', kbd: '1' },
          { l: 'Hard',  c: MW.color.hard,  t: '6m',  kbd: '2' },
          { l: 'Good',  c: MW.color.good,  t: '1d',  kbd: '3' },
          { l: 'Easy',  c: MW.color.easy,  t: '4d',  kbd: '4' },
        ].map((b, i) => (
          <div key={i} style={{
            position: 'relative',
            border: `${MW.border.std}px solid ${MW.color.ink}`,
            background: b.c,
            color: b.l === 'Good' || b.l === 'Easy' || b.l === 'Again' ? '#fff' : MW.color.ink,
            padding: '14px 4px 10px',
            textAlign: 'center',
          }}>
            <div style={{ fontSize: 14, fontWeight: 800, textTransform: 'uppercase', letterSpacing: 0.4 }}>{b.l}</div>
            <div style={{ fontSize: 10, opacity: 0.85, marginTop: 3, fontVariantNumeric: 'tabular-nums' }}>next · {b.t}</div>
            <div style={{ position: 'absolute', top: 4, right: 5, fontSize: 9, fontWeight: 700, opacity: 0.6, border: `1px solid currentColor`, borderRadius: 2, width: 12, height: 12, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{b.kbd}</div>
          </div>
        ))}
      </div>
    </div>
  </MWGrid>
);

// ═══ BASIC STUDY ═══
const MWScreenStudyBasic = () => (
  <MWGrid>
    <IOSStatusBar />
    <MWTopBar left={MWIcon.close()} center={<MWEyebrow>Basic Study</MWEyebrow>} right={<MWEyebrow>12/142</MWEyebrow>} />
    <div style={{ padding: '14px 20px 0' }}>
      <MWProgress pct={8} />
    </div>
    <div style={{ padding: '40px 20px 0' }}>
      <MWDeckPaper depth={2}>
        <div style={{ padding: '22px 22px 22px 22px', minHeight: 320, position: 'relative' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 36 }}>
            <MWPill tiny>Organelles</MWPill>
            <MWEyebrow>Tap to flip</MWEyebrow>
          </div>
          <div style={{ fontSize: 24, fontWeight: 700, letterSpacing: -0.4, lineHeight: 1.25 }}>What are cristae?</div>
          <div style={{ position: 'absolute', bottom: 18, left: 22, right: 22, display: 'flex', justifyContent: 'space-between' }}>
            <div style={{ fontSize: 10, color: MW.color.inkFaint }}>#0343</div>
            {MWIcon.flip(MW.color.inkMuted, 14)}
          </div>
        </div>
      </MWDeckPaper>
    </div>
    {/* simpler 2-way feedback */}
    <div style={{ position: 'absolute', bottom: 44, left: 20, right: 20, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
      <div style={{ border: `${MW.border.std}px solid ${MW.color.ink}`, background: MW.color.again, color: '#fff', padding: '16px', textAlign: 'center', fontSize: 14, fontWeight: 800, textTransform: 'uppercase', letterSpacing: 0.4 }}>✕ Don't know</div>
      <div style={{ border: `${MW.border.std}px solid ${MW.color.ink}`, background: MW.color.good, color: '#fff', padding: '16px', textAlign: 'center', fontSize: 14, fontWeight: 800, textTransform: 'uppercase', letterSpacing: 0.4 }}>✓ Know</div>
    </div>
  </MWGrid>
);

// ═══ SESSION SUMMARY ═══
const MWScreenSummary = () => (
  <MWGrid>
    <IOSStatusBar />
    <MWTopBar left={<MWEyebrow>Complete</MWEyebrow>} center={null} right={MWIcon.close()} />

    <div style={{ padding: '24px 20px 0' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8 }}>
        {MWIcon.spark(MW.color.red, 11)}
        <MWEyebrow color={MW.color.red}>Smart Study · Cellular Biology</MWEyebrow>
      </div>
      <div style={{ fontSize: 44, fontWeight: 700, letterSpacing: -1.5, lineHeight: 1 }}>Nice work.</div>
      <div style={{ fontSize: 13, color: MW.color.inkMuted, marginTop: 8 }}>You improved <span style={{ color: MW.color.ink, fontWeight: 700 }}>8 weak cards</span> and kept your 4-day streak.</div>
    </div>

    <div style={{ padding: '24px 20px 0' }}>
      <MWFlat accent={MW.color.red} style={{ padding: '18px 18px 18px 22px' }}>
        <MWEyebrow>Session accuracy</MWEyebrow>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, marginTop: 4 }}>
          <div style={{ fontSize: 60, fontWeight: 700, letterSpacing: -2, lineHeight: 1 }}>87</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: MW.color.inkMuted }}>%</div>
          <MWEyebrow color={MW.color.red} style={{ marginLeft: 'auto' }}>▲ +14 vs last</MWEyebrow>
        </div>

        {/* Rating breakdown — prominently color coded */}
        <div style={{ display: 'flex', height: 10, marginTop: 16, border: `${MW.border.std}px solid ${MW.color.ink}` }}>
          {[
            { f: 20, c: MW.color.easy },
            { f: 14, c: MW.color.good },
            { f: 4,  c: MW.color.hard },
            { f: 3,  c: MW.color.again },
          ].map((s, i) => (
            <div key={i} style={{ flex: s.f, background: s.c, borderLeft: i > 0 ? `${MW.border.std}px solid ${MW.color.ink}` : 'none' }} />
          ))}
        </div>
        <div style={{ display: 'flex', marginTop: 8, fontSize: 10, color: MW.color.inkMuted, textTransform: 'uppercase', letterSpacing: 0.6, gap: 0 }}>
          <div style={{ flex: 20, display: 'flex', alignItems: 'center', gap: 4 }}><MWDot c={MW.color.easy} size={7} /> 20 Easy</div>
          <div style={{ flex: 14, display: 'flex', alignItems: 'center', gap: 4 }}><MWDot c={MW.color.good} size={7} /> 14 Good</div>
          <div style={{ flex: 4,  display: 'flex', alignItems: 'center', gap: 4 }}><MWDot c={MW.color.hard} size={7} /> 4 Hard</div>
          <div style={{ flex: 3,  display: 'flex', alignItems: 'center', gap: 4 }}><MWDot c={MW.color.again} size={7} /> 3 Again</div>
        </div>
      </MWFlat>
    </div>

    <div style={{ padding: '16px 20px 0', display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
      {[
        { v: '5m 40s', l: 'Time' },
        { v: '+2%', l: 'Mastery', c: MW.color.red },
        { v: '5d', l: 'Streak', c: MW.color.red },
      ].map((s, i) => (
        <MWFlat key={i} style={{ padding: '10px 12px', position: 'relative' }}>
          {s.c && <div style={{ position: 'absolute', top: 6, right: 6, width: 6, height: 6, background: s.c, borderRadius: '50%' }} />}
          <div style={{ fontSize: 18, fontWeight: 700, letterSpacing: -0.3 }}>{s.v}</div>
          <MWEyebrow style={{ marginTop: 2 }}>{s.l}</MWEyebrow>
        </MWFlat>
      ))}
    </div>

    <div style={{ padding: '18px 20px 0' }}>
      <MWEyebrow style={{ marginBottom: 10 }}>Improved (3)</MWEyebrow>
      <MWFlat>
        {[
          { t: 'Mitochondrial matrix role', was: 'Again', now: 'Good' },
          { t: 'ATP synthase complex', was: 'Hard', now: 'Good' },
          { t: 'Krebs cycle products', was: 'Hard', now: 'Easy' },
        ].map((c, i, a) => (
          <div key={i} style={{ padding: '11px 14px', borderBottom: i < a.length - 1 ? `1px solid ${MW.color.grid}` : 'none', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10 }}>
            <div style={{ fontSize: 12.5, fontWeight: 600, flex: 1 }}>{c.t}</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
              <MWDot c={MW.color[c.was.toLowerCase()]} size={7} />
              <MWEyebrow color={MW.color[c.was.toLowerCase()]}>{c.was}</MWEyebrow>
              <span style={{ fontSize: 10, color: MW.color.inkMuted }}>→</span>
              <MWDot c={MW.color[c.now.toLowerCase()]} size={7} />
              <MWEyebrow color={MW.color[c.now.toLowerCase()]}>{c.now}</MWEyebrow>
            </div>
          </div>
        ))}
      </MWFlat>
    </div>

    <div style={{ padding: '20px 20px 40px', display: 'flex', flexDirection: 'column', gap: 8 }}>
      <MWButton variant="primary">Continue Smart Study</MWButton>
      <MWButton variant="secondary" hint="Redo the 3 you missed">Review mistakes</MWButton>
    </div>
  </MWGrid>
);

// ═══ CREATE DECK ═══
const MWScreenCreateDeck = () => (
  <MWGrid>
    <IOSStatusBar />
    <MWTopBar left={<div style={{ fontSize: 12, fontWeight: 700 }}>Cancel</div>} center={<MWEyebrow>New Deck</MWEyebrow>} right={<div style={{ fontSize: 12, fontWeight: 700, color: MW.color.red }}>Create</div>} />

    <div style={{ padding: '24px 20px 0' }}>
      <MWEyebrow style={{ marginBottom: 8 }}>Title</MWEyebrow>
      <MWFlat style={{ padding: '14px 14px' }}>
        <div style={{ fontSize: 20, fontWeight: 700, letterSpacing: -0.3 }}>Organic Chemistry</div>
        <div style={{ width: 2, height: 22, background: MW.color.red, marginTop: -22, marginLeft: 185 }}/>
      </MWFlat>
    </div>

    <div style={{ padding: '18px 20px 0' }}>
      <MWEyebrow style={{ marginBottom: 8 }}>Topic</MWEyebrow>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
        <MWPill color={MW.color.red}>Biology</MWPill>
        <MWPill color={MW.color.blue}>Chemistry ✓</MWPill>
        <MWPill color={MW.color.yellow}>Law</MWPill>
        <MWPill>History</MWPill>
        <MWPill>Spanish</MWPill>
        <MWPill style={{ borderStyle: 'dashed' }}>+ New topic</MWPill>
      </div>
    </div>

    <div style={{ padding: '18px 20px 0' }}>
      <MWEyebrow style={{ marginBottom: 8 }}>Accent color</MWEyebrow>
      <div style={{ display: 'flex', gap: 10 }}>
        {[MW.color.red, MW.color.blue, MW.color.yellow, MW.color.good, MW.color.ink].map((c, i) => (
          <div key={i} style={{ width: 38, height: 38, background: c, border: `${MW.border.std}px solid ${MW.color.ink}`, position: 'relative' }}>
            {i === 1 && <div style={{ position: 'absolute', inset: -4, border: `${MW.border.bold}px solid ${MW.color.ink}` }}/>}
          </div>
        ))}
      </div>
    </div>

    <div style={{ padding: '18px 20px 0' }}>
      <MWEyebrow style={{ marginBottom: 8 }}>Description (optional)</MWEyebrow>
      <MWFlat style={{ padding: '12px 14px', minHeight: 80 }}>
        <div style={{ fontSize: 13, color: MW.color.inkFaint }}>A short note about this deck…</div>
      </MWFlat>
    </div>

    <div style={{ padding: '20px 20px 0' }}>
      <MWEyebrow style={{ marginBottom: 8 }}>Study mode default</MWEyebrow>
      <MWFlat>
        <div style={{ padding: '12px 14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', borderBottom: `1px solid ${MW.color.grid}` }}>
          <div>
            <div style={{ fontSize: 13, fontWeight: 700 }}>Smart Study</div>
            <div style={{ fontSize: 11, color: MW.color.inkMuted, marginTop: 2 }}>Spaced repetition, weak-first</div>
          </div>
          <div style={{ width: 18, height: 18, border: `${MW.border.std}px solid ${MW.color.ink}`, display: 'flex', alignItems: 'center', justifyContent: 'center', background: MW.color.ink }}>{MWIcon.check('#fff', 10)}</div>
        </div>
        <div style={{ padding: '12px 14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ fontSize: 13, fontWeight: 600 }}>Basic</div>
          <div style={{ width: 18, height: 18, border: `${MW.border.std}px solid ${MW.color.ink}` }}/>
        </div>
      </MWFlat>
    </div>
    <div style={{ height: 40 }} />
  </MWGrid>
);

// ═══ CREATE CARD ═══
const MWScreenCreateCard = () => (
  <MWGrid>
    <IOSStatusBar />
    <MWTopBar left={<div style={{ fontSize: 12, fontWeight: 700 }}>Cancel</div>} center={<MWEyebrow>New Card</MWEyebrow>} right={<div style={{ fontSize: 12, fontWeight: 700, color: MW.color.red }}>Save</div>} />

    <div style={{ padding: '16px 20px 0' }}>
      <MWPill tiny color={MW.color.red}>Cellular Biology</MWPill>
    </div>

    <div style={{ padding: '16px 20px 0' }}>
      <MWEyebrow style={{ marginBottom: 8 }}>Front</MWEyebrow>
      <MWDeckPaper depth={1}>
        <div style={{ padding: '16px', minHeight: 120 }}>
          <div style={{ fontSize: 18, fontWeight: 700, lineHeight: 1.3 }}>
            What is the role of the mitochondrial matrix?
            <span style={{ display: 'inline-block', width: 2, height: 20, background: MW.color.red, marginLeft: 3, verticalAlign: '-4px' }}/>
          </div>
        </div>
      </MWDeckPaper>
    </div>

    <div style={{ padding: '16px 20px 0' }}>
      <MWEyebrow style={{ marginBottom: 8 }}>Back</MWEyebrow>
      <MWDeckPaper depth={1}>
        <div style={{ padding: '16px', minHeight: 120 }}>
          <div style={{ fontSize: 15, fontWeight: 600, lineHeight: 1.4, color: MW.color.inkFaint }}>
            Site of the Krebs cycle and oxidative phosphorylation…
          </div>
        </div>
      </MWDeckPaper>
    </div>

    <div style={{ padding: '16px 20px 0' }}>
      <MWEyebrow style={{ marginBottom: 8 }}>Sub-topic</MWEyebrow>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
        <MWPill tiny color={MW.color.red} active>Organelles</MWPill>
        <MWPill tiny>Enzymes</MWPill>
        <MWPill tiny>Membrane</MWPill>
        <MWPill tiny>Theory</MWPill>
        <MWPill tiny style={{ borderStyle: 'dashed' }}>+ Add</MWPill>
      </div>
    </div>

    {/* Keyboard */}
    <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0 }}>
      <IOSKeyboard />
    </div>
  </MWGrid>
);

// ═══ SETTINGS ═══
const MWScreenSettings = () => (
  <MWGrid>
    <IOSStatusBar />
    <MWTopBar left={MWIcon.back()} center={<MWEyebrow>Settings</MWEyebrow>} right={null} />

    <div style={{ padding: '22px 20px 0' }}>
      <MWFlat>
        <div style={{ padding: '16px', display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 46, height: 46, background: MW.color.yellow, border: `${MW.border.std}px solid ${MW.color.ink}`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 18, fontWeight: 800 }}>AL</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 15, fontWeight: 700 }}>Alex Linden</div>
            <div style={{ fontSize: 11, color: MW.color.inkMuted, marginTop: 2 }}>alex@workshop.studio</div>
          </div>
          <div>→</div>
        </div>
      </MWFlat>
    </div>

    <div style={{ padding: '22px 20px 0' }}>
      <MWEyebrow style={{ marginBottom: 8 }}>Study</MWEyebrow>
      <MWFlat>
        {[
          { l: 'Daily goal', v: '18 cards' },
          { l: 'Reminder time', v: '8:30 AM' },
          { l: 'Smart Study algorithm', v: 'SM-2' },
          { l: 'Card flip direction', v: 'Tap' },
        ].map((r, i, a) => (
          <div key={i} style={{ padding: '12px 14px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: i < a.length - 1 ? `1px solid ${MW.color.grid}` : 'none' }}>
            <div style={{ fontSize: 13, fontWeight: 600 }}>{r.l}</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <div style={{ fontSize: 12, color: MW.color.inkMuted }}>{r.v}</div>
              <div style={{ fontSize: 12, color: MW.color.inkFaint }}>›</div>
            </div>
          </div>
        ))}
      </MWFlat>
    </div>

    <div style={{ padding: '22px 20px 0' }}>
      <MWEyebrow style={{ marginBottom: 8 }}>Appearance</MWEyebrow>
      <MWFlat>
        <div style={{ padding: '12px 14px', borderBottom: `1px solid ${MW.color.grid}` }}>
          <div style={{ fontSize: 13, fontWeight: 600, marginBottom: 8 }}>Theme</div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 6 }}>
            {['Paper', 'Dark', 'System'].map((t, i) => (
              <div key={i} style={{ padding: '8px', border: `${MW.border.std}px solid ${MW.color.ink}`, background: i === 0 ? MW.color.ink : 'transparent', color: i === 0 ? '#fff' : MW.color.ink, textAlign: 'center', fontSize: 11, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.6 }}>{t}</div>
            ))}
          </div>
        </div>
        {[
          { l: 'Show grid', v: 'On' },
          { l: 'Reduce motion', v: 'Off' },
        ].map((r, i, a) => (
          <div key={i} style={{ padding: '12px 14px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: i < a.length - 1 ? `1px solid ${MW.color.grid}` : 'none' }}>
            <div style={{ fontSize: 13, fontWeight: 600 }}>{r.l}</div>
            <div style={{ width: 40, height: 22, border: `${MW.border.std}px solid ${MW.color.ink}`, background: r.v === 'On' ? MW.color.ink : '#fff', padding: 2, display: 'flex', justifyContent: r.v === 'On' ? 'flex-end' : 'flex-start' }}>
              <div style={{ width: 14, height: 14, background: r.v === 'On' ? MW.color.yellow : MW.color.ink }}/>
            </div>
          </div>
        ))}
      </MWFlat>
    </div>

    <div style={{ padding: '22px 20px 40px' }}>
      <MWEyebrow style={{ marginBottom: 8 }}>About</MWEyebrow>
      <MWFlat>
        <div style={{ padding: '12px 14px', fontSize: 13, fontWeight: 600, borderBottom: `1px solid ${MW.color.grid}` }}>Export all data</div>
        <div style={{ padding: '12px 14px', fontSize: 13, fontWeight: 600, color: MW.color.red }}>Sign out</div>
      </MWFlat>
    </div>
  </MWGrid>
);

// ═══ EMPTY HOME ═══
const MWScreenEmpty = () => (
  <MWGrid>
    <IOSStatusBar />
    <MWTopBar left={MWIcon.profile()} center={<div style={{ fontSize: 13, fontWeight: 700, letterSpacing: 1.4, textTransform: 'uppercase' }}>Decks</div>} right={MWIcon.plus()} />
    <div style={{ padding: '120px 36px 0', textAlign: 'center' }}>
      <div style={{ margin: '0 auto 20px', width: 64, height: 64, position: 'relative' }}>
        <div style={{ position: 'absolute', inset: '4px -4px -4px 4px', border: `${MW.border.std}px solid ${MW.color.inkFaint}`, background: MW.color.paper }}/>
        <div style={{ position: 'absolute', inset: '2px -2px -2px 2px', border: `${MW.border.std}px solid ${MW.color.inkMuted}`, background: MW.color.paper }}/>
        <div style={{ position: 'absolute', inset: 0, border: `${MW.border.std}px solid ${MW.color.ink}`, background: MW.color.paper, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          {MWIcon.plus(MW.color.ink, 22)}
        </div>
      </div>
      <div style={{ fontSize: 22, fontWeight: 700, letterSpacing: -0.4, marginBottom: 8 }}>No decks yet.</div>
      <div style={{ fontSize: 13, color: MW.color.inkMuted, lineHeight: 1.4, marginBottom: 24 }}>Start with one card on one topic. The workshop grows from there.</div>
      <div style={{ display: 'inline-block' }}><MWButton variant="primary" style={{ minWidth: 220 }}>Create your first deck</MWButton></div>
      <div style={{ marginTop: 16, fontSize: 12, color: MW.color.inkMuted, textDecoration: 'underline' }}>Import from CSV</div>
    </div>
  </MWGrid>
);

Object.assign(window, { MWScreenStudySmart, MWScreenStudyBack, MWScreenStudyBasic, MWScreenSummary, MWScreenCreateDeck, MWScreenCreateCard, MWScreenSettings, MWScreenEmpty });
