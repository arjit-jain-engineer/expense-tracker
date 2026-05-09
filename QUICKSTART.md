# ⚡ QUICKSTART — Get running in 15 minutes

> Bilkul minimum steps. Detailed explanations + Google OAuth + troubleshooting README.md me hai.

## 1. Supabase setup (5 min)

1. **[supabase.com](https://supabase.com)** → sign in with GitHub → **New project**
   - Name: `paisa`, Region: Mumbai/Singapore, Plan: Free
2. Wait ~2 min, then click **SQL Editor** → **New query**
3. Paste full content of `sql/schema.sql` → click **Run**
4. **Project Settings → API** → copy 2 things:
   - Project URL
   - anon public key
5. (For local testing) **Authentication → Providers → Email** → toggle OFF "Confirm email"

## 2. Add credentials (1 min)

Edit `public/config.js`:
```js
window.SUPABASE_URL = 'https://YOUR-PROJECT-REF.supabase.co';
window.SUPABASE_ANON_KEY = 'eyJhbGciOi...';
```

## 3. Test locally (1 min)

```bash
cd public
python3 -m http.server 8000
```

Open [http://localhost:8000/login.html](http://localhost:8000/login.html) → sign up → use the app.

## 4. Push to GitHub (2 min)

Create new public repo on github.com (no README), then:

```bash
git init
git add .
git commit -m "Initial commit: Paisa"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/paisa.git
git push -u origin main
```

## 5. Deploy to Vercel (3 min)

1. **[vercel.com](https://vercel.com)** → sign in with GitHub
2. **Add New → Project** → import your repo → **Deploy** (vercel.json auto-detected)
3. Get your URL: `https://paisa-xyz.vercel.app`

## 6. Update Supabase Site URL (1 min)

**Supabase → Authentication → URL Configuration:**
- Site URL: `https://paisa-xyz.vercel.app`
- Redirect URLs: add `https://paisa-xyz.vercel.app/index.html`

## ✅ Done!

Open your Vercel URL → sign up → done. Resume me link daal.

For Google OAuth setup → README.md Step 3.
