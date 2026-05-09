-- ==============================================================
-- PAISA EXPENSE TRACKER — FULL DB SETUP (FIXED)
-- Copy-paste into Supabase SQL Editor and Run
-- ==============================================================

-- ============= TABLES =============

create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    full_name text,
    email text unique not null,
    avatar_url text,
    created_at timestamptz default now()
);

create table if not exists public.categories (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references public.profiles(id) on delete cascade not null,
    name text not null,
    icon text default '💸',
    color text default '#6366f1',
    created_at timestamptz default now(),
    unique(user_id, name)
);

create table if not exists public.expenses (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references public.profiles(id) on delete cascade not null,
    category_id uuid references public.categories(id) on delete set null,
    amount numeric(12, 2) not null check (amount > 0),
    description text,
    expense_date date not null default current_date,
    created_at timestamptz default now()
);

create table if not exists public.groups (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    description text,
    created_by uuid references public.profiles(id) on delete cascade not null,
    created_at timestamptz default now()
);

create table if not exists public.group_members (
    id uuid primary key default gen_random_uuid(),
    group_id uuid references public.groups(id) on delete cascade not null,
    user_id uuid references public.profiles(id) on delete cascade not null,
    joined_at timestamptz default now(),
    unique(group_id, user_id)
);

create table if not exists public.group_expenses (
    id uuid primary key default gen_random_uuid(),
    group_id uuid references public.groups(id) on delete cascade not null,
    paid_by uuid references public.profiles(id) on delete cascade not null,
    amount numeric(12, 2) not null check (amount > 0),
    description text not null,
    expense_date date not null default current_date,
    created_at timestamptz default now()
);

create table if not exists public.expense_splits (
    id uuid primary key default gen_random_uuid(),
    group_expense_id uuid references public.group_expenses(id) on delete cascade not null,
    user_id uuid references public.profiles(id) on delete cascade not null,
    share_amount numeric(12, 2) not null check (share_amount >= 0),
    created_at timestamptz default now(),
    unique(group_expense_id, user_id)
);

create table if not exists public.settlements (
    id uuid primary key default gen_random_uuid(),
    group_id uuid references public.groups(id) on delete cascade not null,
    from_user uuid references public.profiles(id) on delete cascade not null,
    to_user uuid references public.profiles(id) on delete cascade not null,
    amount numeric(12, 2) not null check (amount > 0),
    settled_at timestamptz default now(),
    note text
);

-- ============= INDEXES =============

create index if not exists idx_expenses_user_date on public.expenses(user_id, expense_date desc);
create index if not exists idx_group_expenses_group on public.group_expenses(group_id, expense_date desc);
create index if not exists idx_expense_splits_user on public.expense_splits(user_id);
create index if not exists idx_group_members_user on public.group_members(user_id);
create index if not exists idx_group_members_group on public.group_members(group_id);

-- ============= AUTO-CREATE PROFILE TRIGGER =============

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, email, full_name, avatar_url)
    values (
        new.id,
        new.email,
        coalesce(
            new.raw_user_meta_data->>'full_name',
            new.raw_user_meta_data->>'name',
            split_part(new.email, '@', 1)
        ),
        new.raw_user_meta_data->>'avatar_url'
    );

    insert into public.categories (user_id, name, icon, color) values
        (new.id, 'Food', '🍔', '#f59e0b'),
        (new.id, 'Travel', '✈️', '#3b82f6'),
        (new.id, 'Shopping', '🛍️', '#ec4899'),
        (new.id, 'Bills', '📄', '#ef4444'),
        (new.id, 'Entertainment', '🎬', '#8b5cf6'),
        (new.id, 'Other', '💸', '#6b7280');

    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- ============= ROW LEVEL SECURITY =============

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.expenses enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_expenses enable row level security;
alter table public.expense_splits enable row level security;
alter table public.settlements enable row level security;

-- ============= GRANTS =============
-- These are needed along with RLS policies.

grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.categories to authenticated;
grant select, insert, update, delete on public.expenses to authenticated;
grant select, insert, update, delete on public.groups to authenticated;
grant select, insert, update, delete on public.group_members to authenticated;
grant select, insert, update, delete on public.group_expenses to authenticated;
grant select, insert, update, delete on public.expense_splits to authenticated;
grant select, insert, update, delete on public.settlements to authenticated;

-- ============= POLICIES =============

-- PROFILES
drop policy if exists "Profiles viewable by authenticated" on public.profiles;
create policy "Profiles viewable by authenticated"
on public.profiles
for select
to authenticated
using (true);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

-- CATEGORIES
drop policy if exists "Own categories select" on public.categories;
create policy "Own categories select"
on public.categories
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Own categories insert" on public.categories;
create policy "Own categories insert"
on public.categories
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Own categories update" on public.categories;
create policy "Own categories update"
on public.categories
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Own categories delete" on public.categories;
create policy "Own categories delete"
on public.categories
for delete
to authenticated
using ((select auth.uid()) = user_id);

-- EXPENSES
drop policy if exists "Own expenses select" on public.expenses;
create policy "Own expenses select"
on public.expenses
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Own expenses insert" on public.expenses;
create policy "Own expenses insert"
on public.expenses
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Own expenses update" on public.expenses;
create policy "Own expenses update"
on public.expenses
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Own expenses delete" on public.expenses;
create policy "Own expenses delete"
on public.expenses
for delete
to authenticated
using ((select auth.uid()) = user_id);

-- GROUPS
drop policy if exists "View groups where member" on public.groups;
create policy "View groups where member"
on public.groups
for select
to authenticated
using (
    exists (
        select 1
        from public.group_members gm
        where gm.group_id = groups.id
          and gm.user_id = (select auth.uid())
    )
    or created_by = (select auth.uid())
);

drop policy if exists "Create groups" on public.groups;
create policy "Create groups"
on public.groups
for insert
to authenticated
with check ((select auth.uid()) = created_by);

drop policy if exists "Group creator can update" on public.groups;
create policy "Group creator can update"
on public.groups
for update
to authenticated
using ((select auth.uid()) = created_by)
with check ((select auth.uid()) = created_by);

drop policy if exists "Group creator can delete" on public.groups;
create policy "Group creator can delete"
on public.groups
for delete
to authenticated
using ((select auth.uid()) = created_by);

-- GROUP MEMBERS
drop policy if exists "View members of own groups" on public.group_members;
create policy "View members of own groups"
on public.group_members
for select
to authenticated
using (
    exists (
        select 1
        from public.groups g
        where g.id = group_members.group_id
          and (
            g.created_by = (select auth.uid())
            or exists (
                select 1
                from public.group_members gm2
                where gm2.group_id = g.id
                  and gm2.user_id = (select auth.uid())
            )
          )
    )
);

drop policy if exists "Group creator can add members" on public.group_members;
create policy "Group creator can add members"
on public.group_members
for insert
to authenticated
with check (
    exists (
        select 1
        from public.groups g
        where g.id = group_members.group_id
          and g.created_by = (select auth.uid())
    )
    or (select auth.uid()) = user_id
);

drop policy if exists "Remove members - creator or self" on public.group_members;
create policy "Remove members - creator or self"
on public.group_members
for delete
to authenticated
using (
    (select auth.uid()) = user_id
    or exists (
        select 1
        from public.groups g
        where g.id = group_members.group_id
          and g.created_by = (select auth.uid())
    )
);

-- GROUP EXPENSES
drop policy if exists "View group expenses if member" on public.group_expenses;
create policy "View group expenses if member"
on public.group_expenses
for select
to authenticated
using (
    exists (
        select 1
        from public.group_members gm
        where gm.group_id = group_expenses.group_id
          and gm.user_id = (select auth.uid())
    )
);

drop policy if exists "Add group expenses if member" on public.group_expenses;
create policy "Add group expenses if member"
on public.group_expenses
for insert
to authenticated
with check (
    (select auth.uid()) = paid_by
    and exists (
        select 1
        from public.group_members gm
        where gm.group_id = group_expenses.group_id
          and gm.user_id = (select auth.uid())
    )
);

drop policy if exists "Update own group expenses" on public.group_expenses;
create policy "Update own group expenses"
on public.group_expenses
for update
to authenticated
using ((select auth.uid()) = paid_by)
with check ((select auth.uid()) = paid_by);

drop policy if exists "Delete own group expenses" on public.group_expenses;
create policy "Delete own group expenses"
on public.group_expenses
for delete
to authenticated
using ((select auth.uid()) = paid_by);

-- EXPENSE SPLITS
drop policy if exists "View splits of group expenses" on public.expense_splits;
create policy "View splits of group expenses"
on public.expense_splits
for select
to authenticated
using (
    exists (
        select 1
        from public.group_expenses ge
        join public.group_members gm on gm.group_id = ge.group_id
        where ge.id = expense_splits.group_expense_id
          and gm.user_id = (select auth.uid())
    )
);

drop policy if exists "Manage splits if expense payer" on public.expense_splits;
create policy "Manage splits if expense payer"
on public.expense_splits
for all
to authenticated
using (
    exists (
        select 1
        from public.group_expenses ge
        where ge.id = expense_splits.group_expense_id
          and ge.paid_by = (select auth.uid())
    )
)
with check (
    exists (
        select 1
        from public.group_expenses ge
        where ge.id = expense_splits.group_expense_id
          and ge.paid_by = (select auth.uid())
    )
);

-- SETTLEMENTS
drop policy if exists "View settlements of own groups" on public.settlements;
create policy "View settlements of own groups"
on public.settlements
for select
to authenticated
using (
    exists (
        select 1
        from public.group_members gm
        where gm.group_id = settlements.group_id
          and gm.user_id = (select auth.uid())
    )
);

drop policy if exists "Add settlements where involved" on public.settlements;
create policy "Add settlements where involved"
on public.settlements
for insert
to authenticated
with check (
    ((select auth.uid()) = from_user or (select auth.uid()) = to_user)
    and exists (
        select 1
        from public.group_members gm
        where gm.group_id = settlements.group_id
          and gm.user_id = (select auth.uid())
    )
);

-- ============= DONE =============
-- After running:
-- 1) Refresh the app
-- 2) Re-login
-- 3) Check categories dropdown
-- 4) Try Add Expense