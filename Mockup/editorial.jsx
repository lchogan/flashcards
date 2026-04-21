// Editorial Intellectual — serif + sans, rules instead of boxes, restrained color

const edColors = {
  bg: '#FAFAF7',
  ink: '#0E0E0E',
  muted: '#6A6A65',
  rule: '#1A1A1A',
  faint: '#D8D6CF',
  accent: '#B91C1C', // a single restrained red, used only for emphasis
};

const edSerif = '"Canela", "Tiempos", "Times New Roman", Georgia, serif';
const edSans = '"Inter", "Söhne", system-ui, sans-serif';

const EDBg = ({ children }) => (
  <div style={{ background: edColors.bg, minHeight: '100%', color: edColors.ink, fontFamily: edSans }}>{children}</div>
);

const EDRule = ({ thick, style }) => (
  <div style={{ height: thick ? 1.5 : 0.5, background: edColors.rule, ...style }} />
);

// ─── HOME ───
const EDHome = () => (
  <EDBg>
    <IOSStatusBar />
    {/* Masthead */}
    <div style={{ padding: '54px 24px 0' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: 10, textTransform: 'uppercase', letterSpacing: 2, color: edColors.muted, fontWeight: 500 }}>
        <span>Vol. IV · Issue 12</span>
        <span>Tuesday, 21 April</span>
      </div>
      <EDRule thick style={{ marginTop: 10 }} />
      <div style={{ fontFamily: edSerif, fontSize: 42, fontWeight: 400, letterSpacing: -1.5, lineHeight: 1, padding: '14px 0 10px', fontStyle: 'italic' }}>Decks</div>
      <EDRule style={{ marginBottom: 4 }} />
      <EDRule thick />
    </div>

    {/* Daily brief */}
    <div style={{ padding: '18px 24px 0' }}>
      <div style={{ display: 'flex', gap: 14, alignItems: 'flex-start' }}>
        <div style={{ fontFamily: edSerif, fontSize: 38, fontWeight: 400, fontStyle: 'italic', color: edColors.accent, lineHeight: 1 }}>18</div>
        <div style={{ flex: 1, paddingTop: 4 }}>
          <div style={{ fontSize: 12, fontWeight: 600, letterSpacing: 0.4 }}>cards due today, across three decks.</div>
          <div style={{ fontSize: 11, color: edColors.muted, marginTop: 3 }}>Estimated seven minutes. Your habit streak stands at four days.</div>
        </div>
        <div style={{ fontSize: 10, textTransform: 'uppercase', letterSpacing: 1.5, fontWeight: 600, borderBottom: `1px solid ${edColors.ink}`, paddingBottom: 1, marginTop: 6 }}>Begin</div>
      </div>
    </div>

    {/* Filter by topic */}
    <div style={{ padding: '22px 24px 0' }}>
      <EDRule thick />
      <div style={{ padding: '10px 0', display: 'flex', gap: 14, overflow: 'hidden', fontSize: 11, fontWeight: 600 }}>
        {[
          { t: 'All', active: true },
          { t: 'Biology' },
          { t: 'Spanish' },
          { t: 'Law' },
          { t: 'History' },
        ].map((p, i) => (
          <div key={i} style={{ textTransform: 'uppercase', letterSpacing: 1.2, paddingBottom: 3, borderBottom: p.active ? `2px solid ${edColors.ink}` : 'none', color: p.active ? edColors.ink : edColors.muted, whiteSpace: 'nowrap' }}>{p.t}</div>
        ))}
      </div>
      <EDRule />
    </div>

    {/* Deck list as editorial entries */}
    <div style={{ padding: '8px 24px 40px' }}>
      {[
        { no: '01', title: 'Cellular Biology', topic: 'The Life Sciences', cards: 142, last: 'Two days past', pct: 58, label: 'Familiar' },
        { no: '02', title: 'Spanish, B2 Verbs', topic: 'Languages', cards: 88, last: 'This morning', pct: 82, label: 'Strong' },
        { no: '03', title: 'Constitutional Law', topic: 'Jurisprudence', cards: 204, last: 'Five days past', pct: 22, label: 'Learning' },
        { no: '04', title: 'Roman History', topic: 'Antiquity', cards: 67, last: 'One week past', pct: 48, label: 'Familiar' },
      ].map((d, i) => (
        <div key={i} style={{ padding: '18px 0', borderBottom: `1px solid ${edColors.faint}` }}>
          <div style={{ display: 'flex', gap: 14, alignItems: 'flex-start' }}>
            <div style={{ fontFamily: edSerif, fontSize: 22, fontStyle: 'italic', color: edColors.muted, width: 30, lineHeight: 1, marginTop: 2 }}>{d.no}</div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 9.5, textTransform: 'uppercase', letterSpacing: 2, color: edColors.muted, fontWeight: 600 }}>{d.topic}</div>
              <div style={{ fontFamily: edSerif, fontSize: 22, fontWeight: 400, letterSpacing: -0.3, lineHeight: 1.15, marginTop: 4 }}>{d.title}</div>
              <div style={{ fontSize: 11, color: edColors.muted, marginTop: 6, fontStyle: 'italic' }}>{d.cards} cards · {d.last}</div>
              {/* thin rule + fill */}
              <div style={{ marginTop: 12, position: 'relative' }}>
                <div style={{ height: 2, background: edColors.faint }}>
                  <div style={{ height: 2, background: edColors.ink, width: `${d.pct}%` }} />
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6, fontSize: 10, fontWeight: 600, letterSpacing: 0.4 }}>
                  <span style={{ textTransform: 'uppercase' }}>{d.label}</span>
                  <span style={{ fontVariantNumeric: 'tabular-nums', color: edColors.muted }}>{d.pct}%</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      ))}
    </div>
  </EDBg>
);

// ─── DECK DETAIL / HISTORY ───
const EDDeckDetail = () => (
  <EDBg>
    <IOSStatusBar />
    <div style={{ padding: '54px 24px 0' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: 10, textTransform: 'uppercase', letterSpacing: 1.5, color: edColors.muted, fontWeight: 500 }}>
        <span>← Back</span>
        <span>Deck · 01</span>
        <span>Edit</span>
      </div>
    </div>

    {/* Title */}
    <div style={{ padding: '24px 24px 0' }}>
      <EDRule thick />
      <div style={{ fontSize: 10, textTransform: 'uppercase', letterSpacing: 2, color: edColors.muted, fontWeight: 600, padding: '14px 0 6px' }}>The Life Sciences</div>
      <div style={{ fontFamily: edSerif, fontSize: 38, fontWeight: 400, letterSpacing: -1, lineHeight: 1, paddingBottom: 12 }}>Cellular <span style={{ fontStyle: 'italic' }}>Biology</span></div>
      <EDRule />
    </div>

    {/* Byline-style meta */}
    <div style={{ padding: '10px 24px 0', fontSize: 11, color: edColors.muted, display: 'flex', gap: 14 }}>
      <span>142 <span style={{ fontStyle: 'italic' }}>cards</span></span>
      <span>18 <span style={{ fontStyle: 'italic' }}>sessions</span></span>
      <span>5h <span style={{ fontStyle: 'italic' }}>studied</span></span>
    </div>

    {/* Primary action — editorial button */}
    <div style={{ padding: '18px 24px 0' }}>
      <div style={{ borderTop: `1.5px solid ${edColors.ink}`, borderBottom: `1.5px solid ${edColors.ink}`, padding: '14px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <div style={{ fontSize: 10, textTransform: 'uppercase', letterSpacing: 2, color: edColors.accent, fontWeight: 600 }}>Feature</div>
          <div style={{ fontFamily: edSerif, fontSize: 20, fontStyle: 'italic', fontWeight: 400, lineHeight: 1.1, marginTop: 3 }}>Smart Study</div>
          <div style={{ fontSize: 11, color: edColors.muted, marginTop: 3 }}>Focus on twenty-three weak cards.</div>
        </div>
        <div style={{ fontFamily: edSerif, fontSize: 28, fontStyle: 'italic' }}>→</div>
      </div>
      <div style={{ padding: '12px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: `1px solid ${edColors.faint}` }}>
        <div>
          <div style={{ fontSize: 13, fontWeight: 600 }}>Basic Study</div>
          <div style={{ fontSize: 11, color: edColors.muted, marginTop: 2 }}>Review all 142 in sequence.</div>
        </div>
        <div style={{ fontSize: 16, color: edColors.muted }}>→</div>
      </div>
    </div>

    {/* Tabs */}
    <div style={{ padding: '20px 24px 0', display: 'flex', gap: 24, fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: 1.5 }}>
      <div style={{ paddingBottom: 6, borderBottom: `2px solid ${edColors.ink}` }}>History</div>
      <div style={{ color: edColors.muted }}>Cards · 142</div>
    </div>
    <EDRule style={{ margin: '0 24px' }} />

    {/* Drop cap mastery */}
    <div style={{ padding: '20px 24px 0', display: 'flex', gap: 14 }}>
      <div style={{ fontFamily: edSerif, fontSize: 68, fontWeight: 400, lineHeight: 0.85, letterSpacing: -3 }}>58<span style={{ fontSize: 28, color: edColors.muted }}>%</span></div>
      <div style={{ flex: 1, paddingTop: 6 }}>
        <div style={{ fontFamily: edSerif, fontSize: 15, fontStyle: 'italic', lineHeight: 1.3 }}>Of this deck, you reliably recall roughly three in five.</div>
        <div style={{ fontSize: 10, color: edColors.muted, marginTop: 8, textTransform: 'uppercase', letterSpacing: 1.2 }}>82 Known · 37 Learning · 23 Unseen</div>
      </div>
    </div>

    {/* Stacked bar as thin line composition */}
    <div style={{ padding: '14px 24px 0' }}>
      <div style={{ display: 'flex', height: 3 }}>
        <div style={{ flex: 82, background: edColors.ink }} />
        <div style={{ flex: 37, background: edColors.muted }} />
        <div style={{ flex: 23, background: edColors.faint }} />
      </div>
    </div>

    {/* Chart */}
    <div style={{ padding: '24px 24px 0' }}>
      <div style={{ fontSize: 10, textTransform: 'uppercase', letterSpacing: 2, color: edColors.muted, fontWeight: 600, marginBottom: 8 }}>Figure 1 · Accuracy over sessions</div>
      <EDRule />
      <svg viewBox="0 0 300 80" preserveAspectRatio="none" style={{ width: '100%', height: 90 }}>
        <polyline fill="none" stroke={edColors.ink} strokeWidth="1"
          points="0,70 27,58 54,65 81,48 108,52 135,40 162,44 189,32 216,36 243,22 270,28 300,18"/>
        <circle cx="300" cy="18" r="3" fill={edColors.accent}/>
      </svg>
      <EDRule />
      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 9.5, color: edColors.muted, marginTop: 6, textTransform: 'uppercase', letterSpacing: 1 }}>
        <span>Session 1</span>
        <span>12</span>
      </div>
    </div>

    {/* Weak areas as list */}
    <div style={{ padding: '24px 24px 40px' }}>
      <div style={{ fontSize: 10, textTransform: 'uppercase', letterSpacing: 2, color: edColors.muted, fontWeight: 600, marginBottom: 8 }}>Where you falter</div>
      <EDRule thick />
      {[
        { t: 'Mitochondria', pct: 34 },
        { t: 'Golgi apparatus', pct: 41 },
        { t: 'Ribosomes', pct: 52 },
      ].map((w, i) => (
        <div key={i} style={{ padding: '12px 0', borderBottom: `1px solid ${edColors.faint}`, display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
          <div style={{ fontFamily: edSerif, fontSize: 16, fontStyle: 'italic' }}>{w.t}</div>
          <div style={{ fontSize: 11, color: edColors.muted, fontVariantNumeric: 'tabular-nums' }}>
            <span style={{ color: edColors.accent, fontWeight: 700 }}>{w.pct}%</span> accuracy
          </div>
        </div>
      ))}
    </div>
  </EDBg>
);

// ─── SMART STUDY ───
const EDStudy = () => (
  <EDBg>
    <IOSStatusBar />
    <div style={{ padding: '54px 24px 0', display: 'flex', justifyContent: 'space-between', fontSize: 10, textTransform: 'uppercase', letterSpacing: 1.5, color: edColors.muted, fontWeight: 500 }}>
      <span>× Close</span>
      <span>Smart Study</span>
      <span style={{ fontVariantNumeric: 'tabular-nums' }}>03 / 23</span>
    </div>

    <div style={{ padding: '14px 24px 0' }}>
      <EDRule thick />
      <div style={{ height: 2, background: edColors.faint, marginTop: 2 }}>
        <div style={{ height: 2, background: edColors.ink, width: '13%' }} />
      </div>
    </div>

    {/* Card — editorial folio */}
    <div style={{ padding: '40px 24px 0' }}>
      <div style={{ border: `0.5px solid ${edColors.rule}`, background: '#fff', minHeight: 360, padding: '24px 22px 22px', position: 'relative' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 10, textTransform: 'uppercase', letterSpacing: 1.8, color: edColors.muted, fontWeight: 600 }}>
          <span>The Life Sciences</span>
          <span style={{ color: edColors.accent }}>Organelles</span>
        </div>
        <EDRule style={{ margin: '10px 0 16px' }} />
        <div style={{ fontSize: 10, textTransform: 'uppercase', letterSpacing: 2, color: edColors.muted, fontWeight: 600, marginBottom: 14 }}>Question</div>
        <div style={{ fontFamily: edSerif, fontSize: 26, fontWeight: 400, letterSpacing: -0.4, lineHeight: 1.25 }}>
          What is the primary function of the <span style={{ fontStyle: 'italic' }}>mitochondrial matrix</span>?
        </div>
        {/* fold indicator */}
        <div style={{ position: 'absolute', bottom: 22, left: 22, right: 22 }}>
          <EDRule />
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 10, fontSize: 9.5, color: edColors.muted, textTransform: 'uppercase', letterSpacing: 1.2 }}>
            <span>Card №0342</span>
            <span style={{ fontFamily: edSerif, fontStyle: 'italic', textTransform: 'none', letterSpacing: 0 }}>tap to reveal →</span>
          </div>
        </div>
      </div>
    </div>

    {/* Confidence buttons as a horizontal rule with labels */}
    <div style={{ position: 'absolute', bottom: 46, left: 24, right: 24 }}>
      <div style={{ fontSize: 10, textTransform: 'uppercase', letterSpacing: 2, color: edColors.muted, fontWeight: 600, textAlign: 'center', marginBottom: 10 }}>How well did you recall?</div>
      <EDRule thick />
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)' }}>
        {[
          { l: 'Again', t: '<1m', accent: true },
          { l: 'Hard', t: '6m' },
          { l: 'Good', t: '1d' },
          { l: 'Easy', t: '4d' },
        ].map((b, i) => (
          <div key={i} style={{ padding: '14px 0', textAlign: 'center', borderRight: i < 3 ? `1px solid ${edColors.faint}` : 'none' }}>
            <div style={{ fontFamily: edSerif, fontSize: 16, fontStyle: 'italic', color: b.accent ? edColors.accent : edColors.ink }}>{b.l}</div>
            <div style={{ fontSize: 10, color: edColors.muted, marginTop: 2, fontVariantNumeric: 'tabular-nums' }}>{b.t}</div>
          </div>
        ))}
      </div>
      <EDRule thick />
    </div>
  </EDBg>
);

// ─── SUMMARY ───
const EDSummary = () => (
  <EDBg>
    <IOSStatusBar />
    <div style={{ padding: '54px 24px 0', display: 'flex', justifyContent: 'space-between', fontSize: 10, textTransform: 'uppercase', letterSpacing: 1.5, color: edColors.muted, fontWeight: 500 }}>
      <span>Session Report</span>
      <span>× Close</span>
    </div>

    <div style={{ padding: '20px 24px 0' }}>
      <EDRule thick />
      <div style={{ fontSize: 10, textTransform: 'uppercase', letterSpacing: 2, color: edColors.accent, fontWeight: 600, padding: '14px 0 4px' }}>Smart Study · Cellular Biology</div>
      <div style={{ fontFamily: edSerif, fontSize: 40, fontWeight: 400, letterSpacing: -1.2, lineHeight: 1, paddingBottom: 12 }}>A <span style={{ fontStyle: 'italic' }}>notable</span><br/>session.</div>
      <EDRule />
      <div style={{ fontSize: 12, color: edColors.muted, fontStyle: 'italic', padding: '12px 0 0', lineHeight: 1.45 }}>
        Eight weak cards improved; the four-day streak holds. Accuracy rose fourteen points against your last sitting.
      </div>
    </div>

    {/* pull quote accuracy */}
    <div style={{ padding: '24px 24px 0' }}>
      <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontSize: 10, textTransform: 'uppercase', letterSpacing: 2, color: edColors.muted, fontWeight: 600 }}>Accuracy</div>
          <div style={{ fontFamily: edSerif, fontSize: 78, fontWeight: 400, letterSpacing: -3, lineHeight: 0.85 }}>87<span style={{ fontSize: 30, color: edColors.muted }}>%</span></div>
        </div>
        <div style={{ fontFamily: edSerif, fontStyle: 'italic', fontSize: 18, color: edColors.accent, marginBottom: 6 }}>↑ +14</div>
      </div>
      <EDRule style={{ marginTop: 14 }} />
      <div style={{ display: 'flex', height: 4 }}>
        <div style={{ flex: 20, background: edColors.ink }} />
        <div style={{ flex: 14, background: '#444' }} />
        <div style={{ flex: 4, background: edColors.muted }} />
        <div style={{ flex: 3, background: edColors.accent }} />
      </div>
      <EDRule />
      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 10, color: edColors.muted, marginTop: 6, textTransform: 'uppercase', letterSpacing: 1.2 }}>
        <span>20 Easy</span><span>14 Good</span><span>4 Hard</span><span style={{ color: edColors.accent }}>3 Again</span>
      </div>
    </div>

    {/* Improved list */}
    <div style={{ padding: '28px 24px 0' }}>
      <div style={{ fontSize: 10, textTransform: 'uppercase', letterSpacing: 2, color: edColors.muted, fontWeight: 600, marginBottom: 8 }}>Cards improved</div>
      <EDRule thick />
      {[
        { t: 'Mitochondrial matrix, role of', was: 'Learning', now: 'Familiar' },
        { t: 'ATP synthase, complex of', was: 'Again', now: 'Good' },
        { t: 'Krebs cycle, products of', was: 'Hard', now: 'Good' },
      ].map((c, i) => (
        <div key={i} style={{ padding: '12px 0', borderBottom: `1px solid ${edColors.faint}` }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
            <div style={{ fontFamily: edSerif, fontSize: 15, fontStyle: 'italic', flex: 1 }}>{c.t}</div>
            <div style={{ fontSize: 10, textTransform: 'uppercase', letterSpacing: 1, color: edColors.muted }}>
              {c.was} <span style={{ color: edColors.ink }}>→</span> <span style={{ color: edColors.accent, fontWeight: 700 }}>{c.now}</span>
            </div>
          </div>
        </div>
      ))}
    </div>

    {/* CTA */}
    <div style={{ padding: '28px 24px 40px' }}>
      <div style={{ borderTop: `1.5px solid ${edColors.ink}`, borderBottom: `1.5px solid ${edColors.ink}`, padding: '16px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ fontFamily: edSerif, fontSize: 18, fontStyle: 'italic' }}>Continue Smart Study</div>
        <div style={{ fontFamily: edSerif, fontSize: 24 }}>→</div>
      </div>
      <div style={{ padding: '12px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ fontSize: 13, color: edColors.muted }}>Review mistakes (3)</div>
        <div style={{ fontSize: 16, color: edColors.muted }}>→</div>
      </div>
    </div>
  </EDBg>
);

Object.assign(window, { EDHome, EDDeckDetail, EDStudy, EDSummary });
