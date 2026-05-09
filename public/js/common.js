// =============================================================
// SUPABASE CLIENT + SHARED UTILS
// =============================================================

const { createClient } = window.supabase;
// We use 'sb' globally as you defined it
window.sb = createClient(
  window.SUPABASE_URL,
  window.SUPABASE_ANON_KEY
);

window.sb.auth.onAuthStateChange((event, session) => {
  if (event === 'SIGNED_IN' && session) {
    if (window.location.pathname.endsWith('/login.html') || window.location.pathname === '/login.html') {
      window.location.replace('index.html');
    }
  }
});

async function signInWithGoogle() {
  const { error } = await window.sb.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: `${window.location.origin}/index.html`
    }
  });

  if (error) {
    console.error('Google sign-in error:', error.message);
    alert(error.message);
  }
}
// ---- Auth guard: redirect to login if not authenticated -----
async function requireAuth() {
  const queryParams = new URLSearchParams(window.location.search);
  const hashParams = new URLSearchParams(window.location.hash.slice(1));

  const errorDesc =
    queryParams.get('error_description') ||
    hashParams.get('error_description');

  if (errorDesc) {
    alert("Login failed: " + errorDesc);
    return null;
  }

  const { data, error } = await window.sb.auth.getSession();

  if (error || !data.session) {
    window.location.replace('login.html');
    return null;
  }

  return data.session.user;
}
// ---- Toast notifications -----
function toast(message, type = 'success') {
  const colors = {
    success: 'bg-emerald-600',
    error: 'bg-rose-600',
    info: 'bg-slate-700'
  };
  const container = document.getElementById('toast-container');
  if(!container) return;

  const el = document.createElement('div');
  el.className = `${colors[type]} text-white px-5 py-3 rounded-xl shadow-2xl font-medium animate-slide-in mb-2`;
  el.textContent = message;
  container.appendChild(el);
  
  setTimeout(() => {
    el.style.opacity = '0';
    el.style.transform = 'translateY(-10px)';
    el.style.transition = '0.3s';
    setTimeout(() => el.remove(), 300);
  }, 3000);
}

// ---- Currency formatter -----
function fmtCurrency(amount) {
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 2
  }).format(amount || 0);
}

// ---- Date formatter -----
function fmtDate(dateStr) {
  if (!dateStr) return 'N/A';
  return new Date(dateStr).toLocaleDateString('en-IN', {
    day: 'numeric', month: 'short', year: 'numeric'
  });
}

// ---- Logout helper -----
async function logout() {
  // FIX: Changed 'supabase' to 'window.sb'
  await window.sb.auth.signOut();
  window.location.href = 'login.html';
}

// ---- Get user's profile (with Fallback for Google Users) -----
async function getMyProfile() {
  const { data: { user } } = await window.sb.auth.getUser();
  if (!user) return null;

  const { data, error } = await window.sb
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .single();

  if (error || !data) {
    return {
      full_name: user.user_metadata?.full_name || user.user_metadata?.name || user.email.split('@')[0],
      email: user.email,
      avatar_url: user.user_metadata?.avatar_url || ''
    };
  }
  return data;
}

async function openProfile() {
  const profile = await getMyProfile();
  if (!profile) return;

  document.getElementById('profile-name').textContent = profile.full_name || 'User';
  document.getElementById('profile-email').textContent = profile.email || '';

  const avatarEl = document.getElementById('profile-avatar');
  if (avatarEl) {
    avatarEl.innerHTML = profile.avatar_url
      ? `<img src="${profile.avatar_url}" class="w-full h-full object-cover" alt="">`
      : (profile.full_name || 'U')[0].toUpperCase();
  }

  openModal('profile-modal');
}

// ---- Setup nav user widget -----
async function renderUserNav() {
  const profile = await getMyProfile();
  const navEl = document.getElementById('user-nav');
  if (!navEl || !profile) return;

  const displayName = profile.full_name || 'User';
  const initial = displayName[0].toUpperCase();

  navEl.innerHTML = `
    <button id="profile-nav-btn" class="flex items-center gap-3 rounded-full px-2 py-1 hover:bg-stone-100 transition">
      <div class="hidden sm:block text-right">
        <div class="text-sm font-semibold text-stone-800">${displayName}</div>
        <div class="text-xs text-stone-500">${profile.email}</div>
      </div>
      <div class="w-10 h-10 rounded-full bg-gradient-to-br from-amber-500 to-rose-500 text-white flex items-center justify-center font-bold shadow-md overflow-hidden">
        ${profile.avatar_url ? `<img src="${profile.avatar_url}" class="w-full h-full object-cover" alt="">` : initial}
      </div>
    </button>
  `;

  const btn = document.getElementById('profile-nav-btn');
  if (btn) btn.addEventListener('click', openProfile);
}

// ---- Modal helpers -----
function openModal(id) {
  const el = document.getElementById(id);
  if (el) {
    el.classList.remove('hidden');
    el.classList.add('flex');
  }
}
function closeModal(id) {
  const el = document.getElementById(id);
  if (el) {
    el.classList.add('hidden');
    el.classList.remove('flex');
  }
}

// ---- Run on Load ----
document.addEventListener('DOMContentLoaded', () => {
    renderUserNav();
});