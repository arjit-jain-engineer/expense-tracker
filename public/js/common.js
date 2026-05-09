// =============================================================
// SUPABASE CLIENT + SHARED UTILS
// =============================================================

const { createClient } = window.supabase;

window.sb = createClient(
  window.SUPABASE_URL,
  window.SUPABASE_ANON_KEY
);

// -------------------------------------------------------------
// AUTH
// -------------------------------------------------------------
window.sb.auth.onAuthStateChange((event, session) => {
  if (event === 'SIGNED_IN' && session) {
    const path = window.location.pathname;
    if (
      path.endsWith('/login.html') ||
      path === '/login.html' ||
      path.endsWith('login.html')
    ) {
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

async function requireAuth() {
  const queryParams = new URLSearchParams(window.location.search);
  const hashParams = new URLSearchParams(window.location.hash.slice(1));

  const errorDesc =
    queryParams.get('error_description') ||
    hashParams.get('error_description');

  if (errorDesc) {
    alert('Login failed: ' + errorDesc);
    return null;
  }

  const { data, error } = await window.sb.auth.getSession();

  if (error || !data.session) {
    window.location.replace('login.html');
    return null;
  }

  return data.session.user;
}

async function logout() {
  await window.sb.auth.signOut();
  window.location.replace('login.html');
}

// -------------------------------------------------------------
// TOAST
// -------------------------------------------------------------
function toast(message, type = 'success') {
  const colors = {
    success: 'bg-emerald-600',
    error: 'bg-rose-600',
    info: 'bg-slate-700'
  };

  const durations = {
    success: 5000,
    info: 6000,
    error: 10000
  };

  let container = document.getElementById('toast-container');

  if (!container) {
    container = document.createElement('div');
    container.id = 'toast-container';
    container.className = 'fixed top-6 right-6 z-[99999] flex flex-col gap-3';
    document.body.appendChild(container);
  }

  const el = document.createElement('div');
  el.className = `${colors[type] || colors.success} text-white px-5 py-4 rounded-2xl shadow-2xl font-medium animate-slide-in max-w-sm break-words`;
  el.textContent = message;

  container.appendChild(el);

  setTimeout(() => {
    el.style.opacity = '0';
    el.style.transform = 'translateY(-10px)';
    el.style.transition = '0.3s ease';
    setTimeout(() => el.remove(), 300);
  }, durations[type] || 5000);
}

// -------------------------------------------------------------
// FORMATTERS
// -------------------------------------------------------------
function fmtCurrency(amount) {
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 2
  }).format(Number(amount || 0));
}

function fmtDate(dateStr, showTime = false) {
  if (!dateStr) return 'N/A';
  const d = new Date(dateStr);
  const date = d.toLocaleDateString('en-IN', {
    day: 'numeric',
    month: 'short',
    year: 'numeric'
  });
  if (!showTime) return date;
  const time = d.toLocaleTimeString('en-IN', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: true
  });
  return `${date} · ${time}`;
}

function normalizeSourceType(type) {
  if (!type) return 'expense';
  return String(type).toLowerCase();
}

function sourceTypeLabel(expense) {
  const type = normalizeSourceType(expense?.source_type);
  if (type === 'group_expense_payment') return 'Group payment';
  if (type === 'settlement_paid') return 'Settlement paid';
  if (type === 'settlement_received') return 'Settlement received';
  return 'Expense';
}

function sourceTypeBadgeClass(expense) {
  const type = normalizeSourceType(expense?.source_type);
  if (type === 'group_expense_payment') return 'bg-amber-100 text-amber-700';
  if (type === 'settlement_paid') return 'bg-rose-100 text-rose-700';
  if (type === 'settlement_received') return 'bg-emerald-100 text-emerald-700';
  return 'bg-stone-100 text-stone-600';
}

// -------------------------------------------------------------
// PROFILE
// -------------------------------------------------------------
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
      full_name:
        user.user_metadata?.full_name ||
        user.user_metadata?.name ||
        user.email?.split('@')[0] ||
        'User',
      email: user.email || '',
      avatar_url: user.user_metadata?.avatar_url || ''
    };
  }

  return data;
}

async function openProfile() {
  const profile = await getMyProfile();
  if (!profile) return;

  const nameEl = document.getElementById('profile-name');
  const emailEl = document.getElementById('profile-email');
  const avatarEl = document.getElementById('profile-avatar');

  if (nameEl) nameEl.textContent = profile.full_name || 'User';
  if (emailEl) emailEl.textContent = profile.email || '';

  if (avatarEl) {
    avatarEl.innerHTML = profile.avatar_url
      ? `<img src="${profile.avatar_url}" class="w-full h-full object-cover" alt="">`
      : (profile.full_name || 'U')[0].toUpperCase();
  }

  openModal('profile-modal');
}

async function renderUserNav() {
  const profile = await getMyProfile();
  const navEl = document.getElementById('user-nav');

  if (!navEl || !profile) return;

  const displayName = profile.full_name || 'User';
  const initial = displayName[0].toUpperCase();

  navEl.innerHTML = `
    <button id="profile-nav-btn" class="flex items-center gap-3 rounded-full px-2 py-1 hover:bg-stone-100 transition" type="button">
      <div class="hidden sm:block text-right">
        <div class="text-sm font-semibold text-stone-800">${displayName}</div>
        <div class="text-xs text-stone-500">${profile.email || ''}</div>
      </div>
      <div class="w-10 h-10 rounded-full bg-gradient-to-br from-amber-500 to-rose-500 text-white flex items-center justify-center font-bold shadow-md overflow-hidden">
        ${profile.avatar_url
          ? `<img src="${profile.avatar_url}" class="w-full h-full object-cover" alt="">`
          : initial}
      </div>
    </button>
  `;

  const btn = document.getElementById('profile-nav-btn');
  if (btn) btn.addEventListener('click', openProfile);
}

// -------------------------------------------------------------
// MODALS
// -------------------------------------------------------------
function openModal(id) {
  const el = document.getElementById(id);
  if (!el) return;
  el.classList.remove('hidden');
  el.classList.add('flex');
}

function closeModal(id) {
  const el = document.getElementById(id);
  if (!el) return;
  el.classList.add('hidden');
  el.classList.remove('flex');
}

// -------------------------------------------------------------
// EXPENSE HELPERS
// -------------------------------------------------------------
function isAutoExpense(expense) {
  return !!expense?.is_auto_generated;
}

function normalizeSettlementAmount(expense) {
  return Number(expense?.gross_amount ?? expense?.reimbursed_amount ?? expense?.amount ?? 0);
}

function getExpenseDisplayAmount(expense) {
  const type = normalizeSourceType(expense?.source_type);
  if (type === 'settlement_paid' || type === 'settlement_received') {
    return normalizeSettlementAmount(expense);
  }
  return Number(expense?.net_amount ?? expense?.amount ?? 0);
}

function getExpenseGrossAmount(expense) {
  const type = normalizeSourceType(expense?.source_type);
  if (type === 'settlement_paid' || type === 'settlement_received') {
    return normalizeSettlementAmount(expense);
  }
  return Number(expense?.gross_amount ?? expense?.amount ?? 0);
}

function getExpenseReimbursedAmount(expense) {
  return Number(expense?.reimbursed_amount ?? 0);
}

function isGroupPaymentExpense(expense) {
  return normalizeSourceType(expense?.source_type) === 'group_expense_payment' || !!expense?.is_group_payment;
}

function isSettlementPaidExpense(expense) {
  return normalizeSourceType(expense?.source_type) === 'settlement_paid';
}

function isSettlementReceivedExpense(expense) {
  return normalizeSourceType(expense?.source_type) === 'settlement_received';
}

function shouldHideFromRecentExpenses(expense) {
  // Pehle wala: return isSettlementReceivedExpense(expense) && Number(expense?.amount ?? 0) <= 0;
  // Naya:
  return isSettlementReceivedExpense(expense);
}

function formatExpenseMeta(expense) {
  const type = normalizeSourceType(expense?.source_type);
  if (type === 'group_expense_payment') {
    const paid = fmtCurrency(getExpenseGrossAmount(expense));
    const reimbursed = fmtCurrency(getExpenseReimbursedAmount(expense));
    return `Paid ${paid} • Reimbursed ${reimbursed}`;
  }
  if (type === 'settlement_paid') {
    return `Settlement paid • ${fmtCurrency(getExpenseDisplayAmount(expense))}`;
  }
  if (type === 'settlement_received') {
    const received = getExpenseDisplayAmount(expense);
    if (received <= 0) return 'Settlement received';
    return `Settlement received • ${fmtCurrency(received)}`;
  }
  return '';
}

function resolveExpenseCategory(expense) {
  if (isSettlementPaidExpense(expense) && expense._resolvedCategory?.name)
    return expense._resolvedCategory.name;
  if (expense?.categories?.name) return expense.categories.name;
  if (expense?.category?.name) return expense.category.name;
  return 'Other';
}

function resolveExpenseCategoryIcon(expense) {
  if (isSettlementPaidExpense(expense) && expense._resolvedCategory?.icon)
    return expense._resolvedCategory.icon;
  if (expense?.categories?.icon) return expense.categories.icon;
  if (expense?.category?.icon) return expense.category.icon;
  return '💸';
}

function resolveExpenseCategoryColor(expense) {
  if (isSettlementPaidExpense(expense) && expense._resolvedCategory?.color)
    return expense._resolvedCategory.color;
  if (expense?.categories?.color) return expense.categories.color;
  if (expense?.category?.color) return expense.category.color;
  return '#6b7280';
}

// -------------------------------------------------------------
// DATA HELPERS
// -------------------------------------------------------------
async function fetchMyExpenses() {
  const { data, error } = await window.sb
    .from('expenses')
    .select(`
      id,
      amount,
      gross_amount,
      reimbursed_amount,
      net_amount,
      description,
      expense_date,
      created_at,
      source_type,
      source_id,
      source_group_id,
      is_group_payment,
      is_auto_generated,
      category_id,
      categories (
        id,
        name,
        icon,
        color
      )
    `)
    .order('expense_date', { ascending: false })
    .order('created_at', { ascending: false });

  if (error) throw error;
  const rows = data || [];

  // Settlement paid entries ke liye original group expense ki category fetch karo
  const settlementRows = rows.filter(e => isSettlementPaidExpense(e) && e.source_id);
  if (settlementRows.length) {
    const sourceIds = settlementRows.map(e => e.source_id);
    const { data: settlements } = await window.sb
      .from('settlements')
      .select('id, group_expense_id, group_expense:group_expenses(category_id, categories(id, name, icon, color))')
      .in('id', sourceIds);

    if (settlements) {
      const map = {};
      settlements.forEach(s => { map[s.id] = s.group_expense?.categories; });
      rows.forEach(e => {
        if (isSettlementPaidExpense(e) && map[e.source_id]) {
          e._resolvedCategory = map[e.source_id];
        }
      });
    }
  }

  return rows.filter(expense => !shouldHideFromRecentExpenses(expense));
}

async function fetchMyCategories() {
  const { data, error } = await window.sb
    .from('categories')
    .select('*')
    .order('name', { ascending: true });

  if (error) throw error;
  return data || [];
}

async function fetchMyGroups() {
  const { data, error } = await window.sb
    .from('groups')
    .select('*')
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data || [];
}

async function fetchGroupExpenses(groupId) {
  const { data, error } = await window.sb
    .from('group_expenses')
    .select(`
      id,
      group_id,
      paid_by,
      amount,
      description,
      expense_date,
      created_at,
      category_id,
      categories (
        id,
        name,
        icon,
        color
      ),
      payer:profiles!group_expenses_paid_by_fkey (
        id,
        full_name,
        email
      ),
      expense_splits (
        id,
        user_id,
        share_amount
      )
    `)
    .eq('group_id', groupId)
    .order('expense_date', { ascending: false })
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data || [];
}

async function fetchGroupMembers(groupId) {
  const { data, error } = await window.sb
    .from('group_members')
    .select(`
      id,
      group_id,
      user_id,
      profiles:user_id (
        id,
        full_name,
        email,
        avatar_url
      )
    `)
    .eq('group_id', groupId);

  if (error) throw error;
  return data || [];
}

// -------------------------------------------------------------
// DASHBOARD HELPERS
// -------------------------------------------------------------
function calculateExpenseStats(expenses) {
  return expenses.reduce((acc, expense) => {
    acc.netSpent += Number(expense?.net_amount ?? expense?.amount ?? 0);
    acc.outOfPocket += Number(expense?.gross_amount ?? expense?.amount ?? 0);
    acc.reimbursed += Number(expense?.reimbursed_amount ?? expense?.amount ?? 0);
    return acc;
  }, {
    netSpent: 0,
    outOfPocket: 0,
    reimbursed: 0
  });
}

function buildCategoryTotals(expenses) {
  return expenses.reduce((acc, expense) => {
    if (isSettlementReceivedExpense(expense)) return acc;
    const key = resolveExpenseCategory(expense);
    const icon = resolveExpenseCategoryIcon(expense);
    const color = resolveExpenseCategoryColor(expense);
    const amount = getExpenseDisplayAmount(expense);

    if (!acc[key]) {
      acc[key] = {
        name: key,
        icon,
        color,
        amount: 0
      };
    }

    acc[key].amount += amount;
    return acc;
  }, {});
}

// -------------------------------------------------------------
// RUN ON LOAD
// -------------------------------------------------------------
document.addEventListener('DOMContentLoaded', () => {
  renderUserNav();
});