// Plain-language legal pages. DRAFT: have an Indian lawyer review both before
// public launch (DPDP Act 2023 and DPDP Rules 2025).

export function privacyPolicy(email: string) {
  return `<h1>Privacy policy</h1>
<p><i>Last updated: November 2026</i></p>
<p>Joynetic is a camera-controlled fitness game for adults (18+). This policy explains what we collect, why, and your rights under India's Digital Personal Data Protection Act, 2023.</p>
<h2>The camera</h2>
<p>The game reads your body position on your phone. <b>Camera images and video are processed only on your device, are never saved, and are never uploaded.</b> Only the game results (for example, how many moves you did) leave the phone.</p>
<h2>What we collect</h2>
<ul>
<li><b>Account:</b> your mobile number (stored encrypted) or Google account ID, an optional first name, and your language.</li>
<li><b>Play data:</b> sessions (level, date, duration, active time, score, difficulty, move counts, optional effort rating) and your progress (XP, streak).</li>
<li><b>Device:</b> phone model, performance tier and app version, to make tracking work well.</li>
<li><b>Calibration backup (optional, off by default):</b> your movement range, only if you turn on backup.</li>
<li><b>Pain reports:</b> if you tell us something hurt, so we can review and improve safety.</li>
<li><b>Payments:</b> Google Play and our payment partner handle payments; we receive only the subscription status.</li>
</ul>
<h2>Why we use it (purposes)</h2>
<p>To run your account and save progress; to show your gym crew board and your gym's weekly summary <b>only if you agree</b>; and, if you agree, anonymous analytics to fix crashes. You can give or withdraw each consent separately in Settings at any time.</p>
<h2>Gyms</h2>
<p>If you join a gym and choose to share, your gym sees your first name, number of sessions, effort points, streaks and quest completion. Gyms <b>never</b> see body measurements, calibration, or anything from the camera.</p>
<h2>Where data is stored</h2>
<p>On servers in India, encrypted in transit and at rest.</p>
<h2>How long we keep it</h2>
<p>While your account is active. If you delete your account, identifying details are removed immediately and all remaining data is erased within 30 days.</p>
<h2>Your rights</h2>
<p>In Settings you can download your data, withdraw consent, and delete your account. You can also ask us to correct or erase data.</p>
<h2>Children</h2>
<p>Joynetic is only for adults aged 18 and over. We do not knowingly collect children's data.</p>
<h2>Grievances</h2>
<p>Contact our Grievance Officer at <a href="mailto:${email}">${email}</a>. We respond within 30 days, and in any case within 90 days. You may also approach the Data Protection Board of India.</p>`;
}

export function termsOfUse(email: string) {
  return `<h1>Terms of use</h1>
<p><i>Last updated: November 2026</i></p>
<h2>A game, not medical advice</h2>
<p>Joynetic is a game for general fitness. It is not a medical device and does not give medical advice, diagnose, or treat anything. It makes no weight-loss or health claims. Talk to a doctor before starting any new exercise, especially if you have a health condition, are pregnant, or are recovering from injury.</p>
<h2>Play safely</h2>
<p>Clear a 2 × 2 m space away from furniture. Move within your comfortable range. Stop if anything hurts. You play at your own risk.</p>
<h2>Who can use it</h2>
<p>You must be 18 or older.</p>
<h2>Subscriptions</h2>
<p>Premium is billed through Google Play and renews until you cancel in Google Play. Members of partner gyms may get Premium through their gym while the gym's licence is active.</p>
<h2>Fair play</h2>
<p>Do not cheat, spoof tracking, share gym codes outside your gym, or misuse the service. We may remove scores or accounts that do.</p>
<h2>Contact</h2>
<p><a href="mailto:${email}">${email}</a></p>`;
}
