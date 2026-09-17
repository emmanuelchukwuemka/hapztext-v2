(() => {
  const API = ''; // same-origin
  let token = localStorage.getItem('hapzo_admin_token') || '';
  let me = null;
  let currentScreen = 'dashboard';
  let contentFilter = 'all';
  let trendingPeriod = '24h';
  let callsTab = 'active';
  let socket = null;

  const $ = (sel) => document.querySelector(sel);
  const $$ = (sel) => Array.from(document.querySelectorAll(sel));

  function escapeHtml(str) {
    return String(str ?? '').replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
  }

  function toast(msg, type = '') {
    const el = $('#toast');
    el.textContent = msg;
    el.className = 'toast show' + (type ? ' ' + type : '');
    clearTimeout(toast._t);
    toast._t = setTimeout(() => { el.className = 'toast'; }, 3200);
  }

  function timeAgo(dateStr) {
    if (!dateStr) return '';
    const diff = (Date.now() - new Date(dateStr).getTime()) / 1000;
    if (diff < 60) return 'just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return `${Math.floor(diff / 86400)}d ago`;
  }

  function fmtDuration(seconds) {
    const s = Math.max(0, seconds | 0);
    const m = Math.floor(s / 60);
    const rem = s % 60;
    return m > 0 ? `${m}m ${rem}s` : `${rem}s`;
  }

  function fmtDate(dateStr) {
    if (!dateStr) return '—';
    return new Date(dateStr).toLocaleString();
  }

  // ─── API ──────────────────────────────────────────────────────────────
  async function api(path, opts = {}) {
    const res = await fetch(API + path, {
      ...opts,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(opts.headers || {}),
      },
      body: opts.body ? JSON.stringify(opts.body) : undefined,
    });
    const json = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(json?.errors?.detail || `Request failed (${res.status})`);
    return json.data;
  }

  // ─── DIALOG ───────────────────────────────────────────────────────────
  function openDialog(html) {
    $('#dialogBox').innerHTML = html;
    $('#dialogOverlay').classList.add('open');
  }
  function closeDialog() {
    $('#dialogOverlay').classList.remove('open');
    $('#dialogBox').innerHTML = '';
  }
  $('#dialogOverlay').addEventListener('click', (e) => {
    if (e.target.id === 'dialogOverlay') closeDialog();
  });

  // ─── AUTH ─────────────────────────────────────────────────────────────
  $('#loginForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = $('#loginEmail').value.trim();
    const password = $('#loginPassword').value;
    const btn = $('#loginBtn');
    const errEl = $('#loginError');
    errEl.textContent = '';
    btn.disabled = true;
    btn.innerHTML = '<span class="btn-spinner"></span>';
    try {
      const res = await fetch(API + '/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });
      const json = await res.json();
      if (!res.ok) throw new Error(json?.errors?.detail || 'Login failed');
      token = json.data.tokens.auth;
      localStorage.setItem('hapzo_admin_token', token);
      await loadMeAndStart();
    } catch (err) {
      errEl.textContent = err.message;
    } finally {
      btn.disabled = false;
      btn.innerHTML = '<span>Sign In</span>';
    }
  });

  $('#logoutBtn').addEventListener('click', () => {
    localStorage.removeItem('hapzo_admin_token');
    token = '';
    me = null;
    if (socket) { socket.disconnect(); socket = null; }
    $('#app').classList.add('hidden');
    $('#loginScreen').classList.remove('hidden');
  });

  async function loadMeAndStart() {
    try {
      me = await api('/api/admin/me');
      if (!me || !me.id) throw new Error('Admin access required');
    } catch (err) {
      localStorage.removeItem('hapzo_admin_token');
      token = '';
      $('#loginError').textContent = 'This account does not have admin access.';
      return;
    }
    $('#loginScreen').classList.add('hidden');
    $('#app').classList.remove('hidden');
    connectSocket();
    switchScreen('dashboard');
  }

  function connectSocket() {
    try {
      socket = io({ transports: ['websocket', 'polling'] });
      socket.on('connect', () => socket.emit('authenticate', token));
      socket.on('call:age_alert', (payload) => {
        toast(`⚠ Age alert on a live call — ${payload?.reason || 'mismatch detected'}`, 'error');
        if (currentScreen === 'calls' && callsTab === 'active') renderCallsTab();
      });
    } catch (e) { /* socket.io script may be blocked offline — dashboard still works */ }
  }

  // ─── NAVIGATION ───────────────────────────────────────────────────────
  const titles = {
    dashboard: 'Dashboard', reports: 'Reports', users: 'Users', content: 'Content',
    trending: 'Trending', calls: 'Random Calls', appeals: 'Appeals', settings: 'Settings',
  };

  function switchScreen(screen) {
    currentScreen = screen;
    $$('.menu-item').forEach((el) => el.classList.toggle('active', el.dataset.screen === screen));
    $$('.screen').forEach((el) => el.classList.toggle('active', el.id === `screen-${screen}`));
    $('#topbarTitle').textContent = titles[screen] || '';
    loadScreen(screen);
  }

  $$('.menu-item').forEach((el) => el.addEventListener('click', () => switchScreen(el.dataset.screen)));
  $('#refreshBtn').addEventListener('click', () => loadScreen(currentScreen));

  function loadScreen(screen) {
    if (screen === 'dashboard') return loadDashboard();
    if (screen === 'reports') return loadReports();
    if (screen === 'users') return loadUsers();
    if (screen === 'content') return loadContent();
    if (screen === 'trending') return loadTrending();
    if (screen === 'calls') return renderCallsTab();
    if (screen === 'appeals') return loadAppeals();
    if (screen === 'settings') return loadSettings();
  }

  // ─── DASHBOARD ────────────────────────────────────────────────────────
  async function loadDashboard() {
    const grid = $('#statsGrid');
    grid.innerHTML = '<div class="empty-note">Loading…</div>';
    try {
      const [stats, top] = await Promise.all([
        api('/api/admin/stats/overview'),
        api('/api/admin/dashboard/trending-top?limit=5'),
      ]);
      const cards = [
        { icon: 'fa-users', color: '#1976D2', value: stats.totalUsers, label: 'Total Users' },
        { icon: 'fa-user-plus', color: '#388E3C', value: stats.activeNow, label: 'Active Now' },
        { icon: 'fa-photo-film', color: '#7B1FA2', value: stats.totalPosts, label: 'Total Posts' },
        { icon: 'fa-phone', color: '#00838F', value: stats.activeCalls, label: 'Active Calls' },
        { icon: 'fa-flag', color: '#E53935', value: stats.pendingReports, label: 'Pending Reports' },
        { icon: 'fa-gavel', color: '#F57C00', value: stats.pendingAppeals, label: 'Pending Appeals' },
        { icon: 'fa-ban', color: '#5D4037', value: stats.bannedUsers, label: 'Banned Users' },
        { icon: 'fa-triangle-exclamation', color: '#C62828', value: stats.activeAgeAlerts, label: 'Age Alerts' },
      ];
      grid.innerHTML = cards.map((c) => `
        <div class="stat-card">
          <i class="fas ${c.icon}" style="color:${c.color}"></i>
          <div class="value">${c.value ?? 0}</div>
          <div class="label">${c.label}</div>
        </div>`).join('');

      const list = $('#dashTrendingList');
      list.innerHTML = top.length ? top.map((p, i) => `
        <div class="trending-item">
          <div class="rank">#${i + 1}</div>
          <div class="info">
            <div class="name">${escapeHtml(p.sender_username)}</div>
            <div class="stats">
              <span><i class="fas fa-heart"></i> ${p.like_count}</span>
              <span><i class="fas fa-comment"></i> ${p.comment_count}</span>
              <span><i class="fas fa-share"></i> ${p.share_count}</span>
              <span><i class="fas fa-fire"></i> ${p.score}</span>
            </div>
          </div>
        </div>`).join('') : '<div class="empty-note">No trending posts yet</div>';
    } catch (e) { toast(e.message, 'error'); }
  }

  // ─── REPORTS ──────────────────────────────────────────────────────────
  async function loadReports() {
    const el = $('#reportsList');
    el.innerHTML = '<div class="empty-note">Loading…</div>';
    try {
      const { result } = await api('/api/admin/reports?status=pending&pageSize=50');
      el.innerHTML = result.length ? result.map(reportCardHtml).join('') : '<div class="empty-note">No pending reports 🎉</div>';
      result.forEach((r) => wireReportCard(r));
    } catch (e) { toast(e.message, 'error'); }
  }

  function reportCardHtml(r) {
    return `
      <div class="report-card ${r.autoFlags?.length ? 'alert' : ''}" id="report-${r.id}">
        <div class="report-header">
          <div class="avatar"><i class="fas fa-user"></i></div>
          <div>
            <div class="title">${escapeHtml(r.username)} · <span style="text-transform:capitalize">${escapeHtml(r.contentType)}</span></div>
            <div class="sub">Reported by ${escapeHtml(r.reporterUsername)} · ${timeAgo(r.createdAt)} · ${r.totalReporters} total report${r.totalReporters === 1 ? '' : 's'}</div>
          </div>
        </div>
        <div class="violation-box">
          <div class="head"><i class="fas fa-triangle-exclamation"></i> Reason: ${escapeHtml(r.reason)}</div>
          <div class="body">${escapeHtml(r.details || 'No additional details provided.')}</div>
        </div>
        ${r.autoFlags?.length ? `
        <div class="autodetect-box">
          <i class="fas fa-robot"></i> Auto-detected: ${r.autoFlags.map(escapeHtml).join(', ')}
        </div>` : ''}
        <div class="media-preview" data-media-for="${r.id}" data-target-type="${r.targetType}" style="display:none">
          <div class="head"><i class="fas fa-photo-film"></i> Media Preview</div>
          <div class="body"></div>
        </div>
        <div class="action-row">
          <button class="btn btn-outline btn-ignore"><i class="fas fa-xmark"></i> Ignore</button>
          <button class="btn btn-orange btn-warn"><i class="fas fa-triangle-exclamation"></i> Warn User</button>
          ${r.targetType === 'post' ? `<button class="btn btn-red btn-delete-post" data-post-id="${r.targetId}"><i class="fas fa-trash"></i> Delete Post</button>` : ''}
        </div>
      </div>`;
  }

  function wireReportCard(r) {
    const card = $(`#report-${r.id}`);
    if (!card) return;
    if (r.targetType === 'post') {
      api(`/api/admin/reports/${r.id}/media`).then((m) => {
        if (!m?.mediaUrl) return;
        const box = card.querySelector(`[data-media-for="${r.id}"]`);
        box.style.display = 'block';
        const body = box.querySelector('.body');
        const url = m.mediaUrl;
        if (/\.(mp4|webm|mov)(\?|$)/i.test(url)) body.innerHTML = `<video src="${url}" controls></video>`;
        else if (/\.(mp3|wav|m4a|aac)(\?|$)/i.test(url)) body.innerHTML = `<audio src="${url}" controls></audio>`;
        else body.innerHTML = `<img src="${url}" alt="media" />`;
      }).catch(() => {});
    }
    card.querySelector('.btn-ignore').addEventListener('click', async () => {
      try { await api(`/api/admin/reports/${r.id}/ignore`, { method: 'POST' }); toast('Report ignored', 'success'); loadReports(); loadDashboard(); }
      catch (e) { toast(e.message, 'error'); }
    });
    card.querySelector('.btn-warn').addEventListener('click', async () => {
      try { const res = await api(`/api/admin/reports/${r.id}/warn`, { method: 'POST' }); toast(`Warned ${res.warned}`, 'success'); loadReports(); }
      catch (e) { toast(e.message, 'error'); }
    });
    const delBtn = card.querySelector('.btn-delete-post');
    if (delBtn) delBtn.addEventListener('click', () => {
      openDialog(`
        <div class="title">Delete this post?</div>
        <div class="body">This permanently removes the post. This cannot be undone.</div>
        <div class="actions">
          <button class="btn btn-outline" id="cancelDel">Cancel</button>
          <button class="btn btn-red" id="confirmDel">Delete Post</button>
        </div>`);
      $('#cancelDel').addEventListener('click', closeDialog);
      $('#confirmDel').addEventListener('click', async () => {
        try { await api(`/api/admin/posts/${delBtn.dataset.postId}`, { method: 'DELETE' }); toast('Post deleted', 'success'); closeDialog(); loadReports(); }
        catch (e) { toast(e.message, 'error'); }
      });
    });
  }

  // ─── USERS ────────────────────────────────────────────────────────────
  let userSearchTimer = null;
  $('#userSearch').addEventListener('input', () => {
    clearTimeout(userSearchTimer);
    userSearchTimer = setTimeout(loadUsers, 350);
  });

  async function loadUsers() {
    const el = $('#usersList');
    el.innerHTML = '<div class="empty-note">Loading…</div>';
    try {
      const search = $('#userSearch').value.trim();
      const { result } = await api(`/api/admin/users?search=${encodeURIComponent(search)}&pageSize=50`);
      el.innerHTML = result.length ? result.map(userCardHtml).join('') : '<div class="empty-note">No users found</div>';
      result.forEach((u) => {
        $(`#user-${u.id}`)?.addEventListener('click', () => openUserDetail(u.id));
      });
    } catch (e) { toast(e.message, 'error'); }
  }

  function initials(name) {
    return (name || '?').slice(0, 2).toUpperCase();
  }

  function userCardHtml(u) {
    const chips = [];
    if (u.is_banned) chips.push(`<span class="chip red">Banned</span>`);
    if (u.ban_expires_at && new Date(u.ban_expires_at) > new Date()) chips.push(`<span class="chip orange">Suspended</span>`);
    if (u.warnings_count > 0) chips.push(`<span class="chip orange">${u.warnings_count} warning${u.warnings_count === 1 ? '' : 's'}</span>`);
    if (u.calls_restricted) chips.push(`<span class="chip purple">Calls Restricted</span>`);
    if (!chips.length) chips.push(`<span class="chip green">Good Standing</span>`);
    return `
      <div class="user-card ${u.is_banned ? 'suspended' : ''}" id="user-${u.id}">
        <div class="avatar">${initials(u.username)}</div>
        <div class="info">
          <div class="name">${escapeHtml(u.username)}</div>
          <div class="email">${escapeHtml(u.email)}</div>
          <div class="chips">${chips.join('')}</div>
        </div>
        <button class="menu-btn"><i class="fas fa-chevron-right"></i></button>
      </div>`;
  }

  async function openUserDetail(id) {
    let u;
    try { u = await api(`/api/admin/users/${id}`); } catch (e) { return toast(e.message, 'error'); }
    const banInfo = u.is_banned
      ? (u.ban_expires_at ? `Suspended until ${fmtDate(u.ban_expires_at)}` : 'Permanently banned')
      : 'Not banned';
    openDialog(`
      <div class="title">${escapeHtml(u.username)}</div>
      <div class="body">
        <p><strong>Email:</strong> ${escapeHtml(u.email)}</p>
        <p><strong>Joined:</strong> ${fmtDate(u.created_at)}</p>
        <p><strong>Posts:</strong> ${u.postCount} &nbsp; <strong>Warnings:</strong> ${u.warnings_count}</p>
        <p><strong>Status:</strong> ${banInfo}</p>
        <p><strong>Reports against:</strong> ${u.reportsAgainst}</p>
        ${u.violations?.length ? `
          <p style="margin-top:10px"><strong>Recent violations:</strong></p>
          <ul style="margin:6px 0 0 18px">
            ${u.violations.map((v) => `<li>${escapeHtml(v.reason)} — ${v.status} (${timeAgo(v.created_at)})</li>`).join('')}
          </ul>` : ''}
      </div>
      <div class="actions" style="flex-wrap:wrap">
        <button class="btn btn-orange" id="udWarn"><i class="fas fa-triangle-exclamation"></i> Warn</button>
        <button class="btn btn-orange" id="udSuspend"><i class="fas fa-clock"></i> Suspend</button>
        ${u.is_banned
          ? `<button class="btn btn-green" id="udLift"><i class="fas fa-unlock"></i> Lift Ban</button>`
          : `<button class="btn btn-red" id="udBan"><i class="fas fa-ban"></i> Ban</button>`}
        <button class="btn btn-outline" id="udClose">Close</button>
      </div>`);
    $('#udClose').addEventListener('click', closeDialog);
    $('#udWarn').addEventListener('click', async () => {
      try { await api(`/api/admin/users/${id}/warn`, { method: 'POST' }); toast('User warned', 'success'); closeDialog(); loadUsers(); }
      catch (e) { toast(e.message, 'error'); }
    });
    $('#udSuspend').addEventListener('click', () => openSuspendDialog(id));
    if (u.is_banned) {
      $('#udLift').addEventListener('click', async () => {
        try { await api(`/api/admin/users/${id}/lift-ban`, { method: 'POST' }); toast('Ban lifted', 'success'); closeDialog(); loadUsers(); }
        catch (e) { toast(e.message, 'error'); }
      });
    } else {
      $('#udBan').addEventListener('click', async () => {
        try { await api(`/api/admin/users/${id}/ban`, { method: 'POST', body: { reason: 'Policy violation' } }); toast('User banned', 'success'); closeDialog(); loadUsers(); }
        catch (e) { toast(e.message, 'error'); }
      });
    }
  }

  function openSuspendDialog(id) {
    openDialog(`
      <div class="title">Suspend user</div>
      <div class="body">
        <label class="field-label">Duration</label>
        <select id="suspendDays" style="width:100%;padding:10px;border:1px solid #ddd;border-radius:8px;margin-bottom:12px">
          <option value="1">1 day</option>
          <option value="7" selected>7 days</option>
          <option value="30">30 days</option>
        </select>
        <label class="field-label">Reason</label>
        <textarea id="suspendReason" rows="3" placeholder="Reason for suspension"></textarea>
      </div>
      <div class="actions">
        <button class="btn btn-outline" id="susCancel">Cancel</button>
        <button class="btn btn-orange" id="susConfirm">Suspend</button>
      </div>`);
    $('#susCancel').addEventListener('click', closeDialog);
    $('#susConfirm').addEventListener('click', async () => {
      try {
        await api(`/api/admin/users/${id}/suspend`, {
          method: 'POST',
          body: { days: parseInt($('#suspendDays').value, 10), reason: $('#suspendReason').value || null },
        });
        toast('User suspended', 'success'); closeDialog(); loadUsers();
      } catch (e) { toast(e.message, 'error'); }
    });
  }

  // ─── CONTENT ──────────────────────────────────────────────────────────
  $$('#contentFilters .filter-chip').forEach((chip) => chip.addEventListener('click', () => {
    contentFilter = chip.dataset.type;
    $$('#contentFilters .filter-chip').forEach((c) => c.classList.toggle('active', c === chip));
    loadContent();
  }));

  async function loadContent() {
    const grid = $('#contentGrid');
    grid.innerHTML = '<div class="empty-note">Loading…</div>';
    try {
      const type = contentFilter === 'all' ? '' : `&type=${contentFilter}`;
      const { result } = await api(`/api/admin/content?pageSize=48${type}`);
      grid.innerHTML = result.length ? result.map(contentCardHtml).join('') : '<div class="empty-note">No content found</div>';
      result.forEach((p) => {
        $(`#content-del-${p.id}`)?.addEventListener('click', () => deleteContent(p.id));
      });
    } catch (e) { toast(e.message, 'error'); }
  }

  function contentCardHtml(p) {
    let preview = `<div class="type"><i class="fas fa-align-left" style="font-size:28px"></i></div>`;
    if (p.post_format === 'image' && p.image_content) preview = `<img src="${p.image_content}" />`;
    else if (p.post_format === 'video' && p.video_content) preview = `<video src="${p.video_content}" muted></video>`;
    else if (p.post_format === 'audio') preview = `<div class="type"><i class="fas fa-music" style="font-size:28px"></i><br/>Audio</div>`;
    return `
      <div class="content-card">
        <div class="preview">${preview}</div>
        <div class="body">
          <div class="by">${escapeHtml(p.sender_username)} · ${timeAgo(p.created_at)}</div>
          <div class="stats">
            <span><i class="fas fa-heart"></i> ${p.like_count}</span>
            <span><i class="fas fa-share"></i> ${p.share_count}</span>
          </div>
          <button class="btn btn-red" id="content-del-${p.id}"><i class="fas fa-trash"></i> Delete</button>
        </div>
      </div>`;
  }

  async function deleteContent(id) {
    openDialog(`
      <div class="title">Delete this post?</div>
      <div class="body">This permanently removes the post.</div>
      <div class="actions">
        <button class="btn btn-outline" id="cCancel">Cancel</button>
        <button class="btn btn-red" id="cConfirm">Delete</button>
      </div>`);
    $('#cCancel').addEventListener('click', closeDialog);
    $('#cConfirm').addEventListener('click', async () => {
      try { await api(`/api/admin/posts/${id}`, { method: 'DELETE' }); toast('Post deleted', 'success'); closeDialog(); loadContent(); }
      catch (e) { toast(e.message, 'error'); }
    });
  }

  // ─── TRENDING ─────────────────────────────────────────────────────────
  $$('#screen-trending .filter-chip').forEach((chip) => chip.addEventListener('click', () => {
    trendingPeriod = chip.dataset.period;
    $$('#screen-trending .filter-chip').forEach((c) => c.classList.toggle('active', c === chip));
    loadTrending();
  }));

  async function loadTrending() {
    const el = $('#trendingList');
    el.innerHTML = '<div class="empty-note">Loading…</div>';
    try {
      const rows = await api(`/api/admin/trending?period=${trendingPeriod}&limit=30`);
      el.innerHTML = rows.length ? rows.map(trendItemHtml).join('') : '<div class="empty-note">No trending posts in this period</div>';
      rows.forEach((p) => {
        $(`#trend-remove-${p.id}`)?.addEventListener('click', async () => {
          try { await api(`/api/admin/trending/${p.id}/remove`, { method: 'POST' }); toast('Removed from trending', 'success'); loadTrending(); }
          catch (e) { toast(e.message, 'error'); }
        });
        $(`#trend-boost-${p.id}`)?.addEventListener('click', async () => {
          try { await api(`/api/admin/posts/${p.id}/boost`, { method: 'POST' }); toast('Post boosted', 'success'); loadTrending(); }
          catch (e) { toast(e.message, 'error'); }
        });
      });
    } catch (e) { toast(e.message, 'error'); }
  }

  function trendItemHtml(p, i) {
    return `
      <div class="trend-item">
        <div class="head">
          <div class="rank-badge">#${i + 1}</div>
          <div>
            <div style="font-weight:700">${escapeHtml(p.sender_username)}</div>
            <div style="font-size:12px;color:var(--text-lo)">${escapeHtml(p.post_format)} · ${timeAgo(p.created_at)}</div>
          </div>
        </div>
        <div class="metrics">
          <span class="metric-chip chip blue"><i class="fas fa-heart"></i> ${p.like_count} likes</span>
          <span class="metric-chip chip purple"><i class="fas fa-comment"></i> ${p.comment_count} comments</span>
          <span class="metric-chip chip green"><i class="fas fa-share"></i> ${p.share_count} shares</span>
          <span class="metric-chip chip orange"><i class="fas fa-fire"></i> score ${p.score}</span>
        </div>
        <div class="action-row">
          <button class="btn btn-outline" id="trend-remove-${p.id}"><i class="fas fa-eye-slash"></i> Remove</button>
          <button class="btn btn-orange" id="trend-boost-${p.id}"><i class="fas fa-rocket"></i> Boost</button>
        </div>
      </div>`;
  }

  // ─── RANDOM CALLS ─────────────────────────────────────────────────────
  $$('#screen-calls .tab').forEach((tab) => tab.addEventListener('click', () => {
    callsTab = tab.dataset.tab;
    $$('#screen-calls .tab').forEach((t) => t.classList.toggle('active', t === tab));
    renderCallsTab();
  }));

  async function renderCallsTab() {
    const el = $('#callsTabContent');
    el.innerHTML = '<div class="empty-note">Loading…</div>';
    try {
      if (callsTab === 'active') {
        const calls = await api('/api/admin/calls/active');
        el.innerHTML = calls.length ? calls.map(activeCallHtml).join('') : '<div class="empty-note">No active calls right now</div>';
        calls.forEach((c) => {
          $(`#call-end-${c.dbId || c.id}`)?.addEventListener('click', () => endCall(c.dbId || c.id));
        });
      } else if (callsTab === 'history') {
        const calls = await api('/api/admin/calls/history?limit=50');
        el.innerHTML = calls.length ? calls.map(historyCallHtml).join('') : '<div class="empty-note">No call history yet</div>';
      } else {
        const rows = await api('/api/admin/users/flagged');
        el.innerHTML = rows.length ? rows.map(flaggedUserHtml).join('') : '<div class="empty-note">No flagged users</div>';
        rows.forEach((r) => {
          $(`#watch-${r.userId}`)?.addEventListener('click', async () => {
            try { await api(`/api/admin/users/${r.userId}/watch-calls`, { method: 'POST' }); toast('User flagged for call monitoring', 'success'); renderCallsTab(); }
            catch (e) { toast(e.message, 'error'); }
          });
          $(`#restrict-${r.userId}`)?.addEventListener('click', async () => {
            try { await api(`/api/admin/users/${r.userId}/restrict-random-calls`, { method: 'POST' }); toast('Random calls restricted', 'success'); renderCallsTab(); }
            catch (e) { toast(e.message, 'error'); }
          });
        });
      }
    } catch (e) { toast(e.message, 'error'); }
  }

  function activeCallHtml(c) {
    const id = c.dbId || c.id;
    const icon = c.ageAlert ? 'alert' : (c.callType === 'video' ? 'video' : 'voice');
    const iconGlyph = c.ageAlert ? 'fa-triangle-exclamation' : (c.callType === 'video' ? 'fa-video' : 'fa-phone');
    return `
      <div class="call-card ${c.ageAlert ? 'age-alert' : ''}">
        ${c.ageAlert ? `
        <div class="age-banner">
          <i class="fas fa-triangle-exclamation"></i>
          <div>
            <div class="title">⚠ CRITICAL AGE ALERT</div>
            <div class="msg">${escapeHtml(c.ageAlertReason || 'Age mismatch detected between participants')}</div>
          </div>
        </div>` : ''}
        <div class="call-row">
          <div class="type-icon ${icon}"><i class="fas ${iconGlyph}"></i></div>
          <div class="details">
            <div class="pair">${escapeHtml(c.callerUsername)} ↔ ${escapeHtml(c.calleeUsername)}</div>
            <div class="meta">${escapeHtml(c.callType || 'voice')} · ${fmtDuration(c.durationSeconds)} elapsed${c.isDiscover ? ' · Random Match' : ''}</div>
          </div>
          <span class="live-badge ${c.ageAlert ? 'danger' : ''}"><span class="live-dot"></span> LIVE</span>
        </div>
        <div class="action-row">
          <button class="btn ${c.ageAlert ? 'btn-red' : 'btn-outline'}" id="call-end-${id}">
            <i class="fas fa-phone-slash"></i> ${c.ageAlert ? 'END IMMEDIATELY' : 'End Call'}
          </button>
        </div>
      </div>`;
  }

  function historyCallHtml(c) {
    return `
      <div class="call-card">
        <div class="call-row">
          <div class="type-icon ${c.call_type === 'video' ? 'video' : 'voice'}"><i class="fas ${c.call_type === 'video' ? 'fa-video' : 'fa-phone'}"></i></div>
          <div class="details">
            <div class="pair">${escapeHtml(c.caller_username)} ↔ ${escapeHtml(c.callee_username || 'N/A')}</div>
            <div class="meta">${c.status} · ${fmtDate(c.started_at)}${c.reports_count > 0 ? ` · ${c.reports_count} report(s)` : ''}${c.age_alert ? ' · ⚠ age alert' : ''}</div>
          </div>
        </div>
      </div>`;
  }

  function flaggedUserHtml(r) {
    return `
      <div class="user-card">
        <div class="avatar">${initials(r.username)}</div>
        <div class="info">
          <div class="name">${escapeHtml(r.username)}</div>
          <div class="email">${r.totalCalls} calls · ${r.reportsReceived} reports · rate ${r.reportRate}</div>
          <div class="chips">
            <span class="chip ${r.status === 'High Risk' ? 'red' : 'orange'}">${r.status}</span>
            ${r.watched ? '<span class="chip blue">Watched</span>' : ''}
          </div>
        </div>
        <div style="display:flex;flex-direction:column;gap:6px">
          <button class="btn btn-outline" id="watch-${r.userId}" style="font-size:11px">Watch</button>
          <button class="btn btn-red" id="restrict-${r.userId}" style="font-size:11px">Restrict</button>
        </div>
      </div>`;
  }

  async function endCall(id) {
    try { await api(`/api/admin/calls/${id}/end`, { method: 'POST', body: { reason: 'admin_action' } }); toast('Call ended', 'success'); renderCallsTab(); }
    catch (e) { toast(e.message, 'error'); }
  }

  // ─── APPEALS ──────────────────────────────────────────────────────────
  async function loadAppeals() {
    const el = $('#appealsList');
    el.innerHTML = '<div class="empty-note">Loading…</div>';
    try {
      const rows = await api('/api/admin/appeals');
      el.innerHTML = rows.length ? rows.map(appealCardHtml).join('') : '<div class="empty-note">No appeals to review</div>';
      rows.forEach((a) => {
        if (a.status !== 'pending') return;
        $(`#appeal-approve-${a.id}`)?.addEventListener('click', async () => {
          try { await api(`/api/admin/appeals/${a.id}/approve`, { method: 'POST' }); toast('Appeal approved, ban lifted', 'success'); loadAppeals(); }
          catch (e) { toast(e.message, 'error'); }
        });
        $(`#appeal-deny-${a.id}`)?.addEventListener('click', async () => {
          try { await api(`/api/admin/appeals/${a.id}/deny`, { method: 'POST' }); toast('Appeal denied', 'success'); loadAppeals(); }
          catch (e) { toast(e.message, 'error'); }
        });
      });
    } catch (e) { toast(e.message, 'error'); }
  }

  function appealCardHtml(a) {
    return `
      <div class="appeal-card">
        <div class="appeal-header">
          <i class="fas fa-gavel gavel"></i>
          <div class="info">
            <div class="title">${escapeHtml(a.username)}</div>
            <div class="sub">Submitted ${timeAgo(a.created_at)} · <span class="chip ${a.status === 'pending' ? 'orange' : a.status === 'approved' ? 'green' : 'red'}">${a.status}</span></div>
          </div>
        </div>
        <div class="violation-summary">
          <div class="head">Original violation</div>
          ${escapeHtml(a.violation_type || 'Not specified')}${a.original_action ? ` — action taken: ${escapeHtml(a.original_action)}` : ''}
        </div>
        <div class="appeal-message">
          <div class="head">User's appeal message</div>
          ${escapeHtml(a.message || 'No message provided')}
        </div>
        ${a.status === 'pending' ? `
        <div class="action-row">
          <button class="btn btn-outline" id="appeal-deny-${a.id}"><i class="fas fa-xmark"></i> Deny</button>
          <button class="btn btn-green" id="appeal-approve-${a.id}"><i class="fas fa-check"></i> Approve &amp; Lift Ban</button>
        </div>` : ''}
      </div>`;
  }

  // ─── SETTINGS ─────────────────────────────────────────────────────────
  async function loadSettings() {
    try {
      const [settings, words, rules] = await Promise.all([
        api('/api/admin/settings'),
        api('/api/admin/banned-words'),
        api('/api/admin/rules'),
      ]);
      $('#guidelinesText').value = settings.communityGuidelines || '';
      renderBannedWords(words);
      renderRules(rules);
    } catch (e) { toast(e.message, 'error'); }
  }

  function renderBannedWords(words) {
    const el = $('#bannedWordsTags');
    el.innerHTML = words.length ? words.map((w) => `
      <span class="tag" data-word="${escapeHtml(w)}">${escapeHtml(w)} <i class="fas fa-xmark"></i></span>`).join('') : '<span style="color:var(--text-lo);font-size:12px">No banned words yet</span>';
    $$('#bannedWordsTags .tag i').forEach((icon) => icon.addEventListener('click', async () => {
      const word = icon.parentElement.dataset.word;
      try { await api(`/api/admin/banned-words/${encodeURIComponent(word)}`, { method: 'DELETE' }); loadSettings(); }
      catch (e) { toast(e.message, 'error'); }
    }));
  }

  $('#addBannedWordBtn').addEventListener('click', async () => {
    const input = $('#bannedWordInput');
    const word = input.value.trim();
    if (!word) return;
    try { await api('/api/admin/banned-words', { method: 'POST', body: { word } }); input.value = ''; loadSettings(); toast('Banned word added', 'success'); }
    catch (e) { toast(e.message, 'error'); }
  });

  const ruleColors = { flag: '#FF9800', warn: '#F57C00', remove: '#E53935', ban: '#B71C1C' };
  function renderRules(rules) {
    const el = $('#rulesList');
    el.innerHTML = rules.length ? rules.map((r) => `
      <div class="rule-card">
        <div class="icon" style="background:${ruleColors[r.action] || '#999'}"><i class="fas fa-list-check"></i></div>
        <div class="body">
          <div class="name">${escapeHtml(r.name)}</div>
          <div class="pattern">${escapeHtml(r.pattern)}</div>
          <div class="meta">
            <span class="chip orange">${escapeHtml(r.action)}</span>
            <span>${r.strikes} strike${r.strikes === 1 ? '' : 's'}</span>
          </div>
        </div>
        <button class="btn btn-outline" id="rule-del-${r.id}" style="font-size:11px">Delete</button>
      </div>`).join('') : '<div class="empty-note">No violation rules configured</div>';
    rules.forEach((r) => {
      $(`#rule-del-${r.id}`)?.addEventListener('click', async () => {
        try { await api(`/api/admin/rules/${r.id}`, { method: 'DELETE' }); loadSettings(); }
        catch (e) { toast(e.message, 'error'); }
      });
    });
  }

  $('#addRuleBtn').addEventListener('click', async () => {
    const name = $('#ruleNameInput').value.trim();
    const pattern = $('#rulePatternInput').value.trim();
    const action = $('#ruleActionInput').value;
    const strikes = parseInt($('#ruleStrikesInput').value, 10) || 1;
    if (!name || !pattern) return toast('Name and pattern are required', 'error');
    try {
      await api('/api/admin/rules', { method: 'POST', body: { name, pattern, action, strikes } });
      $('#ruleNameInput').value = ''; $('#rulePatternInput').value = ''; $('#ruleStrikesInput').value = '1';
      loadSettings(); toast('Rule added', 'success');
    } catch (e) { toast(e.message, 'error'); }
  });

  $('#saveGuidelinesBtn').addEventListener('click', async () => {
    try {
      await api('/api/admin/settings', { method: 'PATCH', body: { communityGuidelines: $('#guidelinesText').value } });
      toast('Guidelines saved', 'success');
    } catch (e) { toast(e.message, 'error'); }
  });

  // ─── BOOT ─────────────────────────────────────────────────────────────
  if (token) loadMeAndStart();
})();
