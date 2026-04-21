// MW — Modals
const { MW, MWGrid, MWEyebrow, MWPill, MWButton, MWDeckPaper, MWFlat, MWProgress, MWTopBar, MWTabs, MWDot, MWIcon } = window;
const { IOSStatusBar } = window;

// ═══ QUICK ACTIONS BOTTOM SHEET ═══
const MWModalQuickActions = () => (
  <MWGrid>
    <IOSStatusBar />
    {/* Dimmed page behind */}
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.45)', zIndex: 10 }}/>
    {/* Sheet */}
    <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 11 }}>
      <div style={{ background: MW.color.paper, border: `${MW.border.std}px solid ${MW.color.ink}`, borderBottom: 'none', padding: '18px 20px 28px' }}>
        <div style={{ width: 40, height: 3, background: MW.color.ink, margin: '0 auto 16px' }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
          <div style={{ width: 6, alignSelf: 'stretch', background: MW.color.red }} />
          <div>
            <div style={{ fontSize: 15, fontWeight: 700 }}>Cellular Biology</div>
            <div style={{ fontSize: 11, color: MW.color.inkMuted, marginTop: 2 }}>142 cards · 12 due</div>
          </div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 0, border: `${MW.border.std}px solid ${MW.color.ink}` }}>
          {[
            { l: 'Smart Study', h: '23 weak cards', i: MWIcon.spark(MW.color.red, 12) },
            { l: 'Basic Study', h: 'All 142 cards' },
            { l: 'Add card', i: MWIcon.plus(MW.color.ink, 14) },
            { l: 'Edit deck', i: MWIcon.edit(MW.color.ink, 14) },
            { l: 'Duplicate', i: MWIcon.dup(MW.color.ink, 14) },
            { l: 'Delete deck', i: MWIcon.trash(MW.color.red, 14), red: true },
          ].map((a, i, arr) => (
            <div key={i} style={{ padding: '14px 14px', display: 'flex', alignItems: 'center', gap: 10, borderBottom: i < arr.length - 1 ? `1px solid ${MW.color.grid}` : 'none' }}>
              {a.i && <div style={{ width: 18, display: 'flex', justifyContent: 'center' }}>{a.i}</div>}
              {!a.i && <div style={{ width: 18 }}/>}
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 13.5, fontWeight: 700, color: a.red ? MW.color.red : MW.color.ink }}>{a.l}</div>
                {a.h && <div style={{ fontSize: 11, color: MW.color.inkMuted, marginTop: 2 }}>{a.h}</div>}
              </div>
              <div style={{ color: a.red ? MW.color.red : MW.color.ink }}>→</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  </MWGrid>
);

// ═══ SORT MENU (dropdown) ═══
const MWModalSort = () => (
  <MWGrid>
    <IOSStatusBar />
    <MWTopBar left={MWIcon.profile()} center={<div style={{ fontSize: 13, fontWeight: 700, letterSpacing: 1.4, textTransform: 'uppercase' }}>Decks</div>} right={MWIcon.plus()} />
    <div style={{ padding: '20px 20px 0' }}>
      <MWFlat accent={MW.color.yellow} accentPos="top" style={{ padding: '14px 16px', opacity: 0.35 }}>
        <div style={{ fontSize: 34, fontWeight: 700 }}>18</div>
      </MWFlat>
    </div>
    <div style={{ padding: '18px 20px 0', display: 'flex', justifyContent: 'space-between' }}>
      <MWEyebrow>12 decks · 3 due</MWEyebrow>
      <div style={{ display: 'flex', alignItems: 'center', gap: 5, border: `${MW.border.std}px solid ${MW.color.ink}`, padding: '6px 10px', background: MW.color.paper, position: 'relative', zIndex: 11 }}>
        {MWIcon.sort()}<MWEyebrow>Mastery ↓</MWEyebrow>
      </div>
    </div>
    {/* dimmer */}
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.25)', zIndex: 10 }} />
    {/* dropdown */}
    <div style={{ position: 'absolute', top: 188, right: 20, zIndex: 12, width: 210 }}>
      <MWFlat>
        <div style={{ padding: '10px 14px 6px' }}>
          <MWEyebrow>Sort by</MWEyebrow>
        </div>
        {[
          { l: 'Mastery', d: 'Weakest first', active: true },
          { l: 'Recently studied', d: 'Today first' },
          { l: 'Due today', d: 'Most due first' },
          { l: 'Alphabetical', d: 'A → Z' },
          { l: 'Created', d: 'Newest first' },
        ].map((o, i, a) => (
          <div key={i} style={{ padding: '10px 14px', display: 'flex', alignItems: 'center', gap: 10, borderTop: `1px solid ${MW.color.grid}`, background: o.active ? MW.color.paperTint : 'transparent' }}>
            <div style={{ width: 14, height: 14, border: `${MW.border.std}px solid ${MW.color.ink}`, background: o.active ? MW.color.ink : 'transparent', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              {o.active && MWIcon.check('#fff', 8)}
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 12.5, fontWeight: 700 }}>{o.l}</div>
              <div style={{ fontSize: 10, color: MW.color.inkMuted, marginTop: 1 }}>{o.d}</div>
            </div>
          </div>
        ))}
      </MWFlat>
    </div>
  </MWGrid>
);

// ═══ CARD INLINE EDIT (contextual menu) ═══
const MWModalCardEdit = () => (
  <MWGrid>
    <IOSStatusBar />
    <MWTopBar left={MWIcon.back()} center={<MWEyebrow>Deck 01</MWEyebrow>} right={MWIcon.dots()} />
    <div style={{ padding: '14px 20px 0', opacity: 0.4 }}>
      <MWPill tiny color={MW.color.red}>Biology</MWPill>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 8 }}>Cellular Biology</div>
    </div>

    <div style={{ padding: '16px 20px 0', opacity: 0.25 }}>
      <MWFlat accent={MW.color.hard}>
        <div style={{ padding: '12px 14px 12px 18px' }}>
          <div style={{ fontSize: 13, fontWeight: 700 }}>What is the primary function of the mitochondrial matrix?</div>
        </div>
      </MWFlat>
    </div>

    {/* Highlighted card being edited */}
    <div style={{ padding: '10px 20px 0', position: 'relative', zIndex: 11 }}>
      <MWFlat accent={MW.color.hard} style={{ boxShadow: `6px 6px 0 0 ${MW.color.ink}` }}>
        <div style={{ padding: '14px 14px 14px 18px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div style={{ fontSize: 13, fontWeight: 700, flex: 1 }}>What are cristae?</div>
            <MWPill tiny>Organelles</MWPill>
          </div>
          <div style={{ fontSize: 11, color: MW.color.inkMuted, marginTop: 4 }}>Folded invaginations of the inner mitochondrial membrane.</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 8 }}>
            <MWDot c={MW.color.hard} /><MWEyebrow color={MW.color.hard}>Hard</MWEyebrow>
          </div>
        </div>
      </MWFlat>
    </div>

    {/* contextual menu floating below */}
    <div style={{ padding: '8px 20px 0', position: 'relative', zIndex: 11 }}>
      <MWFlat style={{ width: 200, marginLeft: 'auto' }}>
        {[
          { l: 'Edit card', i: MWIcon.edit(MW.color.ink, 14) },
          { l: 'Move to deck', i: MWIcon.dup(MW.color.ink, 14) },
          { l: 'Reset progress' },
          { l: 'Delete', i: MWIcon.trash(MW.color.red, 14), red: true },
        ].map((a, i, arr) => (
          <div key={i} style={{ padding: '10px 12px', display: 'flex', alignItems: 'center', gap: 8, borderBottom: i < arr.length - 1 ? `1px solid ${MW.color.grid}` : 'none' }}>
            {a.i && <div style={{ width: 16 }}>{a.i}</div>}
            {!a.i && <div style={{ width: 16 }}/>}
            <div style={{ fontSize: 12, fontWeight: 700, color: a.red ? MW.color.red : MW.color.ink }}>{a.l}</div>
          </div>
        ))}
      </MWFlat>
    </div>

    <div style={{ position: 'absolute', inset: 0, background: 'rgba(250,250,250,0.0)', zIndex: 9 }} />
  </MWGrid>
);

// ═══ DELETE CONFIRM ═══
const MWModalDelete = () => (
  <MWGrid>
    <IOSStatusBar />
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.5)', zIndex: 10 }}/>
    <div style={{ position: 'absolute', top: '30%', left: 20, right: 20, zIndex: 11 }}>
      <div style={{ background: MW.color.paper, border: `${MW.border.bold}px solid ${MW.color.ink}` }}>
        {/* Red bar at top */}
        <div style={{ height: 6, background: MW.color.red }}/>
        <div style={{ padding: '20px 20px 18px' }}>
          <MWEyebrow color={MW.color.red}>Delete deck</MWEyebrow>
          <div style={{ fontSize: 22, fontWeight: 700, letterSpacing: -0.4, marginTop: 6, lineHeight: 1.2 }}>Delete "Cellular Biology"?</div>
          <div style={{ fontSize: 13, color: MW.color.inkMuted, marginTop: 10, lineHeight: 1.4 }}>
            This will permanently remove <span style={{ fontWeight: 700, color: MW.color.ink }}>142 cards</span> and <span style={{ fontWeight: 700, color: MW.color.ink }}>18 sessions</span> of progress. This cannot be undone.
          </div>
          <div style={{ background: MW.color.paperTint, border: `1px solid ${MW.color.grid}`, padding: '10px 12px', marginTop: 14, display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ width: 16, height: 16, border: `${MW.border.std}px solid ${MW.color.ink}`, background: MW.color.ink, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{MWIcon.check('#fff', 9)}</div>
            <div style={{ fontSize: 12, fontWeight: 600 }}>Export cards to CSV first</div>
          </div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', borderTop: `${MW.border.std}px solid ${MW.color.ink}` }}>
          <div style={{ padding: '14px', textAlign: 'center', fontSize: 13, fontWeight: 700, borderRight: `${MW.border.std}px solid ${MW.color.ink}` }}>Cancel</div>
          <div style={{ padding: '14px', textAlign: 'center', fontSize: 13, fontWeight: 800, background: MW.color.red, color: '#fff' }}>Delete</div>
        </div>
      </div>
    </div>
  </MWGrid>
);

// ═══ TOPIC PICKER (full-sheet) ═══
const MWModalTopic = () => (
  <MWGrid>
    <IOSStatusBar />
    <MWTopBar left={<div style={{ fontSize: 12, fontWeight: 700 }}>Done</div>} center={<MWEyebrow>Pick topic</MWEyebrow>} right={<div style={{ fontSize: 12, fontWeight: 700, color: MW.color.red }}>+ New</div>} />
    <div style={{ padding: '16px 20px 0' }}>
      <MWFlat style={{ padding: '10px 12px', display: 'flex', alignItems: 'center', gap: 8 }}>
        {MWIcon.search(MW.color.inkMuted, 14)}
        <span style={{ fontSize: 12, color: MW.color.inkMuted }}>Search topics</span>
      </MWFlat>
    </div>
    <div style={{ padding: '18px 20px 0' }}>
      <MWEyebrow style={{ marginBottom: 10 }}>Your topics</MWEyebrow>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {[
          { c: MW.color.red, l: 'Biology', n: 3, active: false },
          { c: MW.color.blue, l: 'Chemistry', n: 1, active: true },
          { c: MW.color.yellow, l: 'Law', n: 2, active: false },
          { c: MW.color.ink, l: 'History', n: 4, active: false },
          { c: MW.color.good, l: 'Spanish', n: 1, active: false },
        ].map((t, i) => (
          <MWFlat key={i} style={{ padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12, background: t.active ? MW.color.paperTint : MW.color.paper }}>
            <div style={{ width: 26, height: 26, background: t.c, border: `${MW.border.std}px solid ${MW.color.ink}` }}/>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 14, fontWeight: 700 }}>{t.l}</div>
              <div style={{ fontSize: 10, color: MW.color.inkMuted, textTransform: 'uppercase', letterSpacing: 0.6, marginTop: 2 }}>{t.n} deck{t.n > 1 ? 's' : ''}</div>
            </div>
            <div style={{ width: 18, height: 18, border: `${MW.border.std}px solid ${MW.color.ink}`, background: t.active ? MW.color.ink : 'transparent', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              {t.active && MWIcon.check('#fff', 10)}
            </div>
          </MWFlat>
        ))}
      </div>
    </div>

    <div style={{ padding: '22px 20px 40px' }}>
      <MWEyebrow style={{ marginBottom: 8 }}>Suggested</MWEyebrow>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
        {['Physics', 'French', 'Music theory', 'Coding', 'Economics'].map((s, i) => (
          <MWPill key={i} style={{ borderStyle: 'dashed' }}>+ {s}</MWPill>
        ))}
      </div>
    </div>
  </MWGrid>
);

// ═══ FILTERS DRAWER (card list filters) ═══
const MWModalFilters = () => (
  <MWGrid>
    <IOSStatusBar />
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.45)', zIndex: 10 }}/>
    <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 11 }}>
      <div style={{ background: MW.color.paper, border: `${MW.border.std}px solid ${MW.color.ink}`, borderBottom: 'none', padding: '16px 20px 24px' }}>
        <div style={{ width: 40, height: 3, background: MW.color.ink, margin: '0 auto 14px' }} />
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 16 }}>
          <div style={{ fontSize: 18, fontWeight: 700, letterSpacing: -0.3 }}>Filter cards</div>
          <MWEyebrow>Showing 142 / 142</MWEyebrow>
        </div>

        <MWEyebrow style={{ marginBottom: 8 }}>Confidence</MWEyebrow>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 6, marginBottom: 18 }}>
          {[
            { l: 'Again', c: MW.color.again, n: 6, active: true },
            { l: 'Hard',  c: MW.color.hard,  n: 17, active: true },
            { l: 'Good',  c: MW.color.good,  n: 82, active: false },
            { l: 'Easy',  c: MW.color.easy,  n: 37, active: false },
          ].map((b, i) => (
            <div key={i} style={{
              border: `${MW.border.std}px solid ${MW.color.ink}`,
              background: b.active ? b.c : MW.color.paper,
              color: b.active && (b.l === 'Good' || b.l === 'Easy' || b.l === 'Again') ? '#fff' : MW.color.ink,
              padding: '10px 4px 8px', textAlign: 'center',
            }}>
              <div style={{ fontSize: 12, fontWeight: 800, textTransform: 'uppercase', letterSpacing: 0.4 }}>{b.l}</div>
              <div style={{ fontSize: 10, marginTop: 2, opacity: 0.8, fontVariantNumeric: 'tabular-nums' }}>{b.n}</div>
            </div>
          ))}
        </div>

        <MWEyebrow style={{ marginBottom: 8 }}>Sub-topic</MWEyebrow>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 18 }}>
          <MWPill tiny active>Organelles · 48</MWPill>
          <MWPill tiny>Enzymes · 22</MWPill>
          <MWPill tiny>Membrane · 18</MWPill>
          <MWPill tiny>Theory · 14</MWPill>
          <MWPill tiny>Krebs · 11</MWPill>
        </div>

        <MWEyebrow style={{ marginBottom: 8 }}>Last reviewed</MWEyebrow>
        <div style={{ position: 'relative', padding: '16px 2px 0' }}>
          <div style={{ height: 4, background: MW.color.paperTint, border: `1px solid ${MW.color.ink}`, position: 'relative' }}>
            <div style={{ position: 'absolute', left: '20%', right: '25%', top: -1, bottom: -1, background: MW.color.ink }}/>
          </div>
          <div style={{ position: 'absolute', left: 'calc(20% - 6px)', top: 12, width: 12, height: 12, background: MW.color.yellow, border: `${MW.border.std}px solid ${MW.color.ink}` }}/>
          <div style={{ position: 'absolute', left: 'calc(75% - 6px)', top: 12, width: 12, height: 12, background: MW.color.yellow, border: `${MW.border.std}px solid ${MW.color.ink}` }}/>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 10, fontSize: 10, color: MW.color.inkMuted, textTransform: 'uppercase', letterSpacing: 0.6 }}>
            <span>Today</span><span>2d ago</span><span>Week+</span>
          </div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 2fr', gap: 8, marginTop: 22 }}>
          <div style={{ border: `${MW.border.std}px solid ${MW.color.ink}`, padding: '12px', textAlign: 'center', fontSize: 12, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.4 }}>Reset</div>
          <div style={{ border: `${MW.border.std}px solid ${MW.color.ink}`, background: MW.color.ink, color: '#fff', padding: '12px', textAlign: 'center', fontSize: 12, fontWeight: 800, textTransform: 'uppercase', letterSpacing: 0.6 }}>Apply · 23 cards</div>
        </div>
      </div>
    </div>
  </MWGrid>
);

Object.assign(window, { MWModalQuickActions, MWModalSort, MWModalCardEdit, MWModalDelete, MWModalTopic, MWModalFilters });
