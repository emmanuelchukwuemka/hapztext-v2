// Hapzo Admin — vanilla JS, no build step, no mock data. Every number on
// this page comes from a real request to this same backend.

const TOKEN_KEY = 'hapzo_admin_token';

function getToken() { return localStorage.getItem(TOKEN_KEY); }
function setToken(t) { localStorage.setItem(TOKEN_KEY, t); }
function clearToken() { localStorage.removeItem(TOKEN_KEY); }

async function api(path, opts = {}) {
  const res = await fetch(path, {
    ...opts,
    headers: {
      'Content-Type': 'application/json',
      ...(getToken() ? { Authorization: `Bearer ${getToken()}` } : {}),
      ...(opts.headers || {}),
    },
  });
  const body = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(body?.errors?.detail || `Request failed (${res.status})`);
  }
  return body?.data;
}

// ─── AUTH ─────────────────────────────────────────────────────────────────

const loginScreen = document.getElementById('loginScreen');
const appShell = document.getElementById('app');

async function tryResumeSession() {
  if (!getToken()) return showLogin();
  try {
    const me = await api('/api/admin/me');
    document.getElementById('adminName').textContent = me.username || me.email;
    showApp();
  } catch (e) {
    clearToken();
    showLogin();
  }
}

function showLogin() {
  loginScreen.classList.remove('hidden');
  appShell.classList.add('hidden');
}

function showApp() {
  loginScreen.classList.add('hidden');
  appShell.classList.remove('hidden');
  router();
}

document.getElementById('loginForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  const email = document.getElementById('loginEmail').value.trim();
  const password = document.getElementById('loginPassword').value;
  const errEl = document.getElementById('loginError');
  errEl.textContent = '';
  try {
    const loginData = await api('/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) });
    setToken(loginData.tokens.auth);
    // Confirm the account is actually an admin before letting them in —
    // a valid Hapzo login isn't enough on its own.
    const me = await api('/api/admin/me');
    document.getElementById('adminName').textContent = me.username || me.email;
    showApp();
  } catch (err) {
    clearToken();
    errEl.textContent = err.message.includes('Admin access')
      ? "This account doesn't have admin access."
      : err.message;
  }
});

document.getElementById('logoutBtn').addEventListener('click', () => {
  clearToken();
  showLogin();
});

// ─── ROUTING ────────────────────────────────────────────────────────────

const PAGES = ['dashboard', 'reports', 'users'];
const TITLES = {
  dashboard: ['Dashboard', "Here's what's happening on Hapzo today."],
  reports: ['Reports', 'Review and act on user-submitted content reports.'],
  users: ['Users', 'Search, inspect, and manage user accounts.'],
};

function router() {
  const page = (location.hash.replace('#', '') || 'dashboard');
  const active = PAGES.includes(page) ? page : 'dashboard';

  PAGES.forEach((p) => {
    document.getElementById(`page-${p}`).classList.toggle('hidden', p !== active);
  });
  document.querySelectorAll('.nav-link[data-page]').forEach((el) => {
    el.classList.toggle('active', el.dataset.page === active);
  });
  document.getElementById('pageTitle').innerHTML =
    active === 'dashboard'
      ? `Good day, <span id="adminName">${document.getElementById('adminName')?.textContent || 'Admin'}</span>! 👋`
      : TITLES[active][0];
  document.getElementById('pageSubtitle').textContent = TITLES[active][1];

  if (active === 'dashboard') loadDashboard();
  if (active === 'reports') loadReports();
  if (active === 'users') loadUsers();
}

window.addEventListener('hashchange', router);
document.getElementById('refreshBtn').addEventListener('click', router);

// ─── FORMATTERS ─────────────────────────────────────────────────────────

function timeAgo(iso) {
  if (!iso) return '—';
  const diffMs = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diffMs / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins} min ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs} hour${hrs > 1 ? 's' : ''} ago`;
  const days = Math.floor(hrs / 24);
  return `${days} day${days > 1 ? 's' : ''} ago`;
}

function fmtDate(iso) {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
}

function fmtDuration(seconds) {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${s.toString().padStart(2, '0')}`;
}

function statusBadge(status) {
  return `<span class="badge ${status}">${status.replace('_', ' ')}</span>`;
}

// ─── DASHBOARD ──────────────────────────────────────────────────────────

const STAT_ICONS = {
  totalUsers: { icon: '👥', bg: '#fdeceb', label: 'Total Users' },
  totalPosts: { icon: '📄', bg: '#e6f0ff', label: 'Total Posts' },
  reportsReceived: { icon: '⚠️', bg: '#fff4e0', label: 'Reports Received' },
  totalCalls: { icon: '📞', bg: '#e6f9ec', label: 'Random Calls' },
  activeNow: { icon: '🟣', bg: '#f1e9ff', label: 'Active Now' },
};

async function loadDashboard() {
  try {
    const overview = await api('/api/admin/stats/overview');
    renderStatGrid(overview);
  } catch (e) {
    console.error(e);
  }

  loadUserGrowthChart();
  loadContentDistributionChart();
  loadReportsByTypeChart();
  loadRecentReports();
  loadRecentUsers();
  loadLiveCalls();
}

function renderStatGrid(overview) {
  const grid = document.getElementById('statGrid');
  const cards = [
    { key: 'totalUsers', value: overview.totalUsers, deltaPct: overview.totalUsersChangePct },
    { key: 'totalPosts', value: overview.totalPosts, deltaPct: overview.totalPostsChangePct },
    { key: 'reportsReceived', value: overview.reportsReceived, deltaPct: overview.reportsChangePct },
    { key: 'totalCalls', value: overview.totalCalls, deltaPct: overview.callsChangePct },
    { key: 'activeNow', value: overview.activeNow, deltaPct: null },
  ];
  grid.innerHTML = cards.map((c) => {
    const meta = STAT_ICONS[c.key];
    const deltaHtml = c.deltaPct === null
      ? '<span class="delta muted">live</span>'
      : `<span class="delta ${c.deltaPct >= 0 ? 'up' : 'down'}">${c.deltaPct >= 0 ? '↑' : '↓'} ${Math.abs(c.deltaPct)}% vs last month</span>`;
    return `
      <div class="stat-card">
        <div class="icon" style="background:${meta.bg}">${meta.icon}</div>
        <div class="label">${meta.label}</div>
        <div class="value">${c.value.toLocaleString()}</div>
        ${deltaHtml}
      </div>`;
  }).join('');
}

let userGrowthChart, contentDistChart, reportsByTypeChart;

async function loadUserGrowthChart() {
  try {
    const series = await api('/api/admin/stats/user-growth?days=30');
    const ctx = document.getElementById('userGrowthChart');
    userGrowthChart?.destroy();
    userGrowthChart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: series.map((p) => p.date.slice(5)),
        datasets: [{
          data: series.map((p) => p.total),
          borderColor: '#e14b4b',
          backgroundColor: 'rgba(225,75,75,0.08)',
          fill: true,
          tension: 0.35,
          pointRadius: 0,
        }],
      },
      options: {
        plugins: { legend: { display: false } },
        scales: { y: { beginAtZero: true } },
      },
    });
  } catch (e) { console.error(e); }
}

async function loadContentDistributionChart() {
  try {
    const rows = await api('/api/admin/stats/content-distribution');
    const labelMap = { image: 'Images', video: 'Videos', text: 'Text', audio: 'Audio' };
    const colors = { image: '#ef4444', video: '#3b82f6', text: '#f59e0b', audio: '#22c55e' };
    const known = rows.filter((r) => labelMap[r.type]);
    const otherCount = rows.filter((r) => !labelMap[r.type]).reduce((s, r) => s + r.count, 0);
    const labels = known.map((r) => labelMap[r.type]);
    const data = known.map((r) => r.count);
    const bg = known.map((r) => colors[r.type]);
    if (otherCount > 0) { labels.push('Other'); data.push(otherCount); bg.push('#8b5cf6'); }

    const ctx = document.getElementById('contentDistChart');
    contentDistChart?.destroy();
    if (data.length === 0) { ctx.getContext('2d').clearRect(0, 0, ctx.width, ctx.height); return; }
    contentDistChart = new Chart(ctx, {
      type: 'doughnut',
      data: { labels, datasets: [{ data, backgroundColor: bg, borderWidth: 0 }] },
      options: { plugins: { legend: { position: 'bottom', labels: { boxWidth: 10, font: { size: 11 } } } } },
    });
  } catch (e) { console.error(e); }
}

async function loadReportsByTypeChart() {
  try {
    const rows = await api('/api/admin/stats/reports-by-type');
    const ctx = document.getElementById('reportsByTypeChart');
    reportsByTypeChart?.destroy();
    reportsByTypeChart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: rows.map((r) => r.reason.replace('_', ' ')),
        datasets: [{ data: rows.map((r) => r.count), backgroundColor: '#e14b4b', borderRadius: 6 }],
      },
      options: { plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true } } },
    });
  } catch (e) { console.error(e); }
}

async function loadRecentReports() {
  const tbody = document.querySelector('#recentReportsTable tbody');
  try {
    const { result } = await api('/api/admin/reports?pageSize=5');
    tbody.innerHTML = result.length
      ? result.map((r) => `
        <tr>
          <td>@${r.username}</td>
          <td>${r.contentType}</td>
          <td>${r.reason.replace('_', ' ')}</td>
          <td>${statusBadge(r.status)}</td>
          <td class="muted">${timeAgo(r.createdAt)}</td>
        </tr>`).join('')
      : '';
    if (!result.length) tbody.innerHTML = '<tr><td colspan="5" class="muted">No reports yet</td></tr>';
  } catch (e) { tbody.innerHTML = `<tr><td colspan="5" class="muted">${e.message}</td></tr>`; }
}

async function loadRecentUsers() {
  const tbody = document.querySelector('#recentUsersTable tbody');
  try {
    const { result } = await api('/api/admin/users?pageSize=5');
    tbody.innerHTML = result.map((u) => `
      <tr>
        <td>@${u.username}</td>
        <td class="muted">${timeAgo(u.created_at)}</td>
        <td>${u.is_banned ? statusBadge('banned') : statusBadge('ok')}</td>
      </tr>`).join('') || '<tr><td colspan="3" class="muted">No users yet</td></tr>';
  } catch (e) { tbody.innerHTML = `<tr><td colspan="3" class="muted">${e.message}</td></tr>`; }
}

async function loadLiveCalls() {
  const tbody = document.querySelector('#liveCallsTable tbody');
  try {
    const calls = await api('/api/admin/calls/live');
    tbody.innerHTML = calls.length
      ? calls.map((c) => `
        <tr>
          <td>@${c.callerUsername}</td>
          <td>@${c.calleeUsername}</td>
          <td>${c.callType}</td>
          <td>${fmtDuration(c.durationSeconds)}</td>
        </tr>`).join('')
      : '<tr><td colspan="4" class="muted">No calls in progress right now</td></tr>';
  } catch (e) { tbody.innerHTML = `<tr><td colspan="4" class="muted">${e.message}</td></tr>`; }
}

// ─── REPORTS PAGE ───────────────────────────────────────────────────────

document.getElementById('reportsStatusFilter').addEventListener('change', loadReports);

async function loadReports() {
  const tbody = document.querySelector('#reportsTable tbody');
  const status = document.getElementById('reportsStatusFilter').value;
  try {
    const { result } = await api(`/api/admin/reports?pageSize=50${status ? `&status=${status}` : ''}`);
    document.getElementById('reportsEmpty').classList.toggle('hidden', result.length > 0);
    tbody.innerHTML = result.map((r) => `
      <tr>
        <td>@${r.username}</td>
        <td>${r.contentType}</td>
        <td>${r.reason.replace('_', ' ')}</td>
        <td>@${r.reporterUsername}</td>
        <td>${statusBadge(r.status)}</td>
        <td class="muted">${timeAgo(r.createdAt)}</td>
        <td>
          ${r.status !== 'resolved' ? `<button class="row-btn primary" data-action="resolve" data-id="${r.id}">Resolve</button>` : ''}
          ${r.status !== 'dismissed' ? `<button class="row-btn danger" data-action="dismiss" data-id="${r.id}">Dismiss</button>` : ''}
        </td>
      </tr>`).join('');
  } catch (e) {
    tbody.innerHTML = `<tr><td colspan="7" class="muted">${e.message}</td></tr>`;
  }
}

document.querySelector('#reportsTable tbody').addEventListener('click', async (e) => {
  const btn = e.target.closest('button[data-action]');
  if (!btn) return;
  const status = btn.dataset.action === 'resolve' ? 'resolved' : 'dismissed';
  try {
    await api(`/api/admin/reports/${btn.dataset.id}`, { method: 'PUT', body: JSON.stringify({ status }) });
    loadReports();
  } catch (e) { alert(e.message); }
});

// ─── USERS PAGE ─────────────────────────────────────────────────────────

let usersSearchDebounce;
document.getElementById('usersSearch').addEventListener('input', () => {
  clearTimeout(usersSearchDebounce);
  usersSearchDebounce = setTimeout(loadUsers, 300);
});

async function loadUsers() {
  const tbody = document.querySelector('#usersTable tbody');
  const search = document.getElementById('usersSearch').value.trim();
  try {
    const { result } = await api(`/api/admin/users?pageSize=50${search ? `&search=${encodeURIComponent(search)}` : ''}`);
    tbody.innerHTML = result.length
      ? result.map((u) => `
        <tr>
          <td>@${u.username}</td>
          <td class="muted">${u.email}</td>
          <td class="muted">${fmtDate(u.created_at)}</td>
          <td>${u.is_banned ? statusBadge('banned') : statusBadge('ok')}</td>
          <td>
            ${u.is_admin ? '' : (u.is_banned
              ? `<button class="row-btn primary" data-action="unban" data-id="${u.id}">Unban</button>`
              : `<button class="row-btn danger" data-action="ban" data-id="${u.id}">Ban</button>`)}
          </td>
        </tr>`).join('')
      : '<tr><td colspan="5" class="muted">No users found</td></tr>';
  } catch (e) {
    tbody.innerHTML = `<tr><td colspan="5" class="muted">${e.message}</td></tr>`;
  }
}

document.querySelector('#usersTable tbody').addEventListener('click', async (e) => {
  const btn = e.target.closest('button[data-action]');
  if (!btn) return;
  try {
    if (btn.dataset.action === 'ban') {
      const reason = prompt('Reason for ban (optional):') || null;
      await api(`/api/admin/users/${btn.dataset.id}/ban`, { method: 'PUT', body: JSON.stringify({ reason }) });
    } else {
      await api(`/api/admin/users/${btn.dataset.id}/unban`, { method: 'PUT' });
    }
    loadUsers();
  } catch (e) { alert(e.message); }
});

// ─── BOOT ───────────────────────────────────────────────────────────────

tryResumeSession();
