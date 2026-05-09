# 💸 Paisa — Expense Tracker with Friend Settlements

> Track personal expenses + split costs with friends + auto-calculate "kisko kitna dena hai". Full-stack app, zero-cost hosting.

A production-ready expense tracker built with vanilla JS, Tailwind, and Supabase. Track your personal spending across categories, create groups for trips/flatmates/dinners, split expenses (equal or exact), and let the app figure out the optimal settlements between everyone.

**🔥 Tech stack:** HTML + Tailwind CSS + Vanilla JS · Supabase (PostgreSQL + Auth + REST API + RLS) · Chart.js · Vercel

**💰 Cost:** $0 forever (within free tier limits)

---

## Features

- 🔐 **Auth** — Email/password + Google OAuth (Supabase Auth)
- 💸 **Personal expenses** — Categories with icons, color-coded charts, search
- 📊 **Dashboard** — Monthly trends (bar chart), category breakdown (donut), this/last month + yearly stats
- 👥 **Groups** — Create groups for any shared expense context
- ➗ **Splits** — Equal or exact-amount splits among any subset of members
- ⚖️ **Auto-settlement** — Greedy debt simplification: minimum number of transfers to settle everyone
- ✓ **Settle up** — Record actual payments, balances update in real-time
- 📥 **CSV export** — Download all your personal expenses
- 🛡️ **Row-Level Security** — Database-enforced isolation; users see only their own data
- 📱 **Responsive** — Works on mobile, tablet, desktop

---

## Quick Start (15 minutes total)

### Prerequisites
- A GitHub account
- A free Supabase account → [supabase.com](https://supabase.com)
- A free Vercel account → [vercel.com](https://vercel.com)
- (Optional) Google Cloud account for Google OAuth

---

## Step 1 — Supabase setup (5 min)

### 1.1 Create project
1. Go to [supabase.com](https://supabase.com) → **Start your project** → sign in with GitHub.
2. Click **New project**:
   - **Name:** `paisa` (or anything)
   - **Database password:** generate strong, save it somewhere
   - **Region:** Mumbai or Singapore (closest to India)
   - **Plan:** Free
3. Wait ~2 minutes for it to provision.

### 1.2 Run database schema
1. In your Supabase project, click **SQL Editor** (left sidebar) → **New query**.
2. Open `sql/schema.sql` from this repo, copy the entire contents, paste into the editor.
3. Click **Run**. You should see "Success. No rows returned."
4. Click **Table Editor** — you should see 8 tables: `profiles`, `categories`, `expenses`, `groups`, `group_members`, `group_expenses`, `expense_splits`, `settlements`. All should show a green **RLS enabled** badge.

### 1.3 Get API credentials
1. Click **Project Settings** (gear icon) → **API**.
2. Copy these two values somewhere safe:
   - **Project URL** (e.g. `https://xxxxxx.supabase.co`)
   - **anon public** key (long JWT starting with `eyJ...`)

### 1.4 Configure Auth (email)
1. Click **Authentication** → **Providers**.
2. **Email** is enabled by default. For local testing, you may want to disable email confirmation:
   - Click **Email** → toggle off **Confirm email** → **Save**.
   - (For production, keep this ON.)

---

## Step 2 — Local test (3 min)

### 2.1 Add credentials
Edit `public/config.js`:

```js
window.SUPABASE_URL = 'https://YOUR-PROJECT-REF.supabase.co';
window.SUPABASE_ANON_KEY = 'eyJhbGciOi...your-long-anon-key...';
```

### 2.2 Serve locally
You need to serve over HTTP (not file://) for Supabase to work. Pick one:

**Option A — Python (already installed):**
```bash
cd public
python3 -m http.server 8000
```

**Option B — Node:**
```bash
npx serve public
```

**Option C — VSCode Live Server extension** — right-click `public/login.html` → "Open with Live Server".

### 2.3 Test
1. Open [http://localhost:8000/login.html](http://localhost:8000/login.html)
2. Click **Sign up** — create an account with email + password
3. You should land on the dashboard
4. Add an expense, create a group, add yourself + a test member, split an expense

To test multi-user flow: open an incognito window, create a second account, share an email between groups.

---

## Step 3 — Google OAuth setup (5 min, optional but recommended)

### 3.1 Google Cloud Console
1. Go to [console.cloud.google.com](https://console.cloud.google.com/) → create a new project (or use existing).
2. **APIs & Services** → **OAuth consent screen**:
   - User Type: **External** → Create
   - App name: `Paisa`
   - User support email: your email
   - Developer contact: your email
   - **Save and Continue** through scopes (no need to add any) and test users.
3. **APIs & Services** → **Credentials** → **Create Credentials** → **OAuth client ID**:
   - Application type: **Web application**
   - Name: `Paisa Web`
   - **Authorized JavaScript origins:** `https://YOUR-PROJECT-REF.supabase.co`
   - **Authorized redirect URIs:** `https://YOUR-PROJECT-REF.supabase.co/auth/v1/callback`
   - Click **Create**. Copy the **Client ID** and **Client Secret**.

### 3.2 Supabase
1. Supabase dashboard → **Authentication** → **Providers** → **Google**.
2. Toggle ON, paste **Client ID** and **Client Secret**, **Save**.

### 3.3 Site URL
1. Supabase → **Authentication** → **URL Configuration**.
2. **Site URL:** for local dev → `http://localhost:8000`. After deployment, change this to your Vercel URL.
3. **Redirect URLs:** add both `http://localhost:8000/index.html` and (later) `https://your-app.vercel.app/index.html`.

---

## Step 4 — Deploy to Vercel (3 min)

### 4.1 Push to GitHub
```bash
cd /path/to/expense-tracker
git init
git add .
git commit -m "Initial commit: Paisa expense tracker"
git branch -M main
# Create a new repo on github.com (public, no README), then:
git remote add origin https://github.com/YOUR-USERNAME/paisa.git
git push -u origin main
```

⚠️ **`config.js` me anon key public hai** — it's safe to commit because RLS protects your data at the database level. The anon key is *meant* to be public (Supabase says so). However, **never commit your service role key** (you don't need it for this app).

### 4.2 Deploy
1. Go to [vercel.com](https://vercel.com) → sign in with GitHub.
2. Click **Add New** → **Project** → import your `paisa` repo.
3. **Framework preset:** Other (auto-detected).
4. **Output directory:** `public` (already set in `vercel.json`).
5. Click **Deploy**.
6. ~1 minute later, you'll get a URL like `https://paisa-xyz.vercel.app`.

### 4.3 Update OAuth redirect URLs
- **Supabase** → Authentication → URL Configuration → add `https://paisa-xyz.vercel.app/index.html` to **Redirect URLs**, and update **Site URL** to your Vercel URL.
- **Google Cloud Console** → Credentials → edit your OAuth client → add `https://paisa-xyz.vercel.app` to authorized JS origins (no redirect URI change needed since callback still goes to Supabase).

### 4.4 Test production
Open your Vercel URL → sign up → use the app. Done! 🎉

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Browser (Vercel CDN)                 │
│  HTML + Tailwind CDN + Vanilla JS + Chart.js            │
│  └─ Supabase JS SDK                                     │
└────────────────────┬────────────────────────────────────┘
                     │ HTTPS + JWT
                     ▼
┌─────────────────────────────────────────────────────────┐
│                       Supabase                          │
│  ┌──────────────┐ ┌─────────────┐ ┌──────────────────┐  │
│  │     Auth     │ │  REST API   │ │  PostgREST       │  │
│  │ (email +     │→│ (auto from  │→│  RLS policies    │  │
│  │   Google)    │ │  schema)    │ │  enforce auth    │  │
│  └──────────────┘ └─────────────┘ └────────┬─────────┘  │
│                                             ▼            │
│                              ┌──────────────────────┐    │
│                              │   PostgreSQL         │    │
│                              │   8 tables + indexes │    │
│                              └──────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

**Why no separate backend?** Supabase auto-generates a secure REST API from the Postgres schema, with row-level security policies enforcing authorization at the database level. The browser uses a JWT (from Supabase Auth) to authenticate every API call. This is more secure than a hand-rolled Node.js backend would be, and it's how production Supabase apps are built.

---

## Database schema

| Table | Purpose |
|---|---|
| `profiles` | User info (linked to `auth.users`, auto-created on signup) |
| `categories` | Personal expense categories (auto-seeded with 6 defaults per user) |
| `expenses` | Personal expenses |
| `groups` | Groups for splitting (trips, flatmates, etc.) |
| `group_members` | Many-to-many: which users are in which groups |
| `group_expenses` | Expenses paid in a group context |
| `expense_splits` | How a group expense is divided across members |
| `settlements` | Records of actual payments between members |

### Settlement algorithm

When you click "Balances" on a group, the app:
1. Calculates each member's **net balance** = (paid by them) − (their total share) + (received via settlements) − (paid via settlements).
2. Splits members into **creditors** (positive balance, owed money) and **debtors** (negative balance, owe money).
3. **Greedy match**: largest debtor pays largest creditor until one is settled, then move to the next. This minimizes the number of transactions.

For example, if A owes ₹500 to the group, B owes ₹300, and C is owed ₹800, the app shows just two transfers (A→C ₹500, B→C ₹300) instead of separate per-expense settlements.

---

## File structure

```
expense-tracker/
├── public/                      # Static site (deployed to Vercel)
│   ├── config.js                # ⚠️  Add Supabase credentials here
│   ├── index.html               # Personal dashboard + charts
│   ├── login.html               # Auth (email + Google)
│   ├── groups.html              # List of user's groups
│   ├── group.html               # Group detail (expenses, balances, settlements)
│   ├── css/
│   │   └── styles.css           # Design tokens + animations
│   └── js/
│       └── common.js            # Shared utils: auth guard, toast, formatters
├── sql/
│   └── schema.sql               # Full DB schema + RLS + triggers
├── docs/
│   └── (extra docs if needed)
├── vercel.json                  # Vercel config
├── .gitignore
└── README.md                    # ← you are here
```

---

## Common issues

**"Could not find table" or 401 errors**
→ RLS policies didn't apply. Re-run `sql/schema.sql` fully.

**Google login redirects to localhost in production**
→ Update Supabase → Authentication → URL Configuration → Site URL to your Vercel URL.

**"User not found" when adding member to group**
→ Add member ko pehle Paisa pe signup krna hoga. The email lookup is against the `profiles` table.

**Email confirmations not arriving**
→ For development, disable email confirmation in Supabase → Auth → Providers → Email. For production, set up an SMTP provider (free: Resend, Brevo).

**CORS errors locally**
→ You're opening files via `file://`. Use `python3 -m http.server` or any static server.

---

## Roadmap (extensions you can add)

- [ ] Recurring expenses (rent, subscriptions)
- [ ] Currency selection (multi-currency for travel)
- [ ] Receipt photo upload (Supabase Storage — also free tier)
- [ ] Push notifications when added to group / new expense
- [ ] Optional Node.js Express backend for analytics endpoints (if you want a "real backend" on resume)
- [ ] PWA (installable on mobile)
- [ ] Dark mode

---

## Resume bullet points

> **Paisa — Full-stack expense tracker** ([github.com/you/paisa](https://github.com/) · [paisa.vercel.app](https://))
> - Built a Splitwise-style expense tracker with personal expense categorization, group cost splitting (equal/exact), and automated debt-simplification algorithm reducing N×N settlements to optimal transfers.
> - Designed normalized PostgreSQL schema with 8 tables, deployed via Supabase, secured with row-level security policies enforcing per-user isolation at the database layer.
> - Implemented OAuth 2.0 (Google) and email/password auth with JWT-based session management; auto-provisioned user profiles via Postgres triggers.
> - Frontend in vanilla JavaScript + Tailwind CSS, deployed to Vercel with CDN caching; Chart.js dashboards for monthly and category-wise spend analytics.
> - Tech: PostgreSQL, Supabase, Vanilla JS, Tailwind CSS, Chart.js, Vercel, OAuth 2.0, RLS, JWT.

---

## License

MIT — do whatever you want with this.

Built with chai and `console.log`. ☕
