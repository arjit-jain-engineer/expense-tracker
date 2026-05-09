-- ==============================================================
-- PAISA EXPENSE TRACKER — FULL DB SETUP
-- FINAL + RECURSION FIXED + GROUP PAYMENT CATEGORY SYNC + SETTLEMENT MIRROR SYNC
-- Production-safe corrected version
-- FIX: Group creator auto-added to group_members to satisfy RLS on group_expenses
-- ============================================================== 

create extension if not exists pgcrypto;

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
    category_id uuid references public.categories(id) on delete set null,
    amount numeric(12, 2) not null check (amount > 0),
    description text not null,
    expense_date date not null default current_date,
    created_at timestamptz default now()
);

create table if not exists public.expenses (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references public.profiles(id) on delete cascade not null,
    category_id uuid references public.categories(id) on delete set null,
    amount numeric(12, 2) not null check (amount >= 0),
    description text,
    expense_date date not null default current_date,
    created_at timestamptz default now(),
    source_type text,
    source_id uuid,
    source_group_id uuid references public.groups(id) on delete set null,
    gross_amount numeric(12,2),
    reimbursed_amount numeric(12,2) default 0,
    net_amount numeric(12,2),
    is_group_payment boolean default false,
    is_auto_generated boolean default false
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
    group_expense_id uuid references public.group_expenses(id) on delete set null,
    from_user uuid references public.profiles(id) on delete cascade not null,
    to_user uuid references public.profiles(id) on delete cascade not null,
    amount numeric(12, 2) not null check (amount > 0),
    settled_at timestamptz default now(),
    note text
);

alter table public.group_expenses add column if not exists category_id uuid references public.categories(id) on delete set null;
alter table public.expenses add column if not exists source_type text;
alter table public.expenses add column if not exists source_id uuid;
alter table public.expenses add column if not exists source_group_id uuid references public.groups(id) on delete set null;
alter table public.expenses add column if not exists gross_amount numeric(12,2);
alter table public.expenses add column if not exists reimbursed_amount numeric(12,2) default 0;
alter table public.expenses add column if not exists net_amount numeric(12,2);
alter table public.expenses add column if not exists is_group_payment boolean default false;
alter table public.expenses add column if not exists is_auto_generated boolean default false;
alter table public.settlements add column if not exists group_expense_id uuid references public.group_expenses(id) on delete set null;

do $$
begin
    if exists (select 1 from pg_constraint where conname = 'expenses_amount_check') then
        alter table public.expenses drop constraint expenses_amount_check;
    end if;
exception when others then
    null;
end $$;

alter table public.expenses
add constraint expenses_amount_check
check (amount >= 0);

create index if not exists idx_expenses_user_date on public.expenses(user_id, expense_date desc);
create index if not exists idx_group_expenses_group on public.group_expenses(group_id, expense_date desc);
create index if not exists idx_expense_splits_user on public.expense_splits(user_id);
create index if not exists idx_group_members_user on public.group_members(user_id);
create index if not exists idx_group_members_group on public.group_members(group_id);
create index if not exists idx_settlements_group on public.settlements(group_id);
create index if not exists idx_settlements_group_expense on public.settlements(group_expense_id);
create index if not exists idx_expenses_source on public.expenses(source_type, source_id);
create index if not exists idx_expenses_group_payment on public.expenses(user_id, is_group_payment);

create unique index if not exists idx_expenses_group_expense_unique
on public.expenses (source_id)
where source_type = 'group_expense_payment';

create unique index if not exists idx_expenses_settlement_paid_unique
on public.expenses (source_id, user_id)
where source_type = 'settlement_paid';

create unique index if not exists idx_expenses_settlement_received_unique
on public.expenses (source_id, user_id)
where source_type = 'settlement_received';

-- -------------------------------------------------------
-- AUTH: New user handler — creates profile + default categories
-- -------------------------------------------------------

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
        coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
        new.raw_user_meta_data->>'avatar_url'
    )
    on conflict (id) do nothing;

    insert into public.categories (user_id, name, icon, color) values
        (new.id, 'Food', '🍔', '#f59e0b'),
        (new.id, 'Travel', '✈️', '#3b82f6'),
        (new.id, 'Shopping', '🛍️', '#ec4899'),
        (new.id, 'Bills', '📄', '#ef4444'),
        (new.id, 'Entertainment', '🎬', '#8b5cf6'),
        (new.id, 'Other', '💸', '#6b7280'),
        (new.id, 'Settlement Paid', '↗️', '#ef4444'),
        (new.id, 'Settlement Received', '↙️', '#10b981')
    on conflict (user_id, name) do nothing;

    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- -------------------------------------------------------
-- FIX: Auto-add group creator to group_members on group creation
-- This ensures is_group_member() returns true for the creator,
-- which is required by the RLS insert policy on group_expenses.
-- -------------------------------------------------------

create or replace function public.handle_new_group()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.group_members (group_id, user_id)
    values (new.id, new.created_by)
    on conflict (group_id, user_id) do nothing;
    return new;
end;
$$;

drop trigger if exists on_group_created on public.groups;
create trigger on_group_created
after insert on public.groups
for each row execute function public.handle_new_group();

-- Backfill: ensure all existing group creators are in group_members
insert into public.group_members (group_id, user_id)
select g.id, g.created_by
from public.groups g
where not exists (
    select 1 from public.group_members gm
    where gm.group_id = g.id and gm.user_id = g.created_by
)
on conflict (group_id, user_id) do nothing;

-- -------------------------------------------------------
-- RLS helper functions
-- -------------------------------------------------------

drop policy if exists "View groups where member" on public.groups;
drop policy if exists "View members of own groups" on public.group_members;
drop policy if exists "Group creator can add members" on public.group_members;
drop policy if exists "Remove members - creator or self" on public.group_members;
drop policy if exists "View group expenses if member" on public.group_expenses;
drop policy if exists "Add group expenses if member" on public.group_expenses;
drop policy if exists "View splits of group expenses" on public.expense_splits;
drop policy if exists "View settlements of own groups" on public.settlements;
drop policy if exists "Add settlements where involved" on public.settlements;
drop policy if exists "Update settlements where involved" on public.settlements;
drop policy if exists "Delete settlements where involved" on public.settlements;

drop function if exists public.is_group_member(uuid);
drop function if exists public.is_group_creator(uuid);

create or replace function public.is_group_member(p_group_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.group_members gm
        where gm.group_id = p_group_id
          and gm.user_id = auth.uid()
    );
$$;

create or replace function public.is_group_creator(p_group_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.groups g
        where g.id = p_group_id
          and g.created_by = auth.uid()
    );
$$;

grant execute on function public.is_group_member(uuid) to authenticated;
grant execute on function public.is_group_creator(uuid) to authenticated;

-- -------------------------------------------------------
-- Triggers: drop before recreating
-- -------------------------------------------------------

drop trigger if exists trg_validate_settlement_group_expense on public.settlements;
drop trigger if exists trg_group_expense_personal_sync on public.group_expenses;
drop trigger if exists trg_settlement_personal_sync on public.settlements;

drop function if exists public.validate_settlement_group_expense();
drop function if exists public.recompute_group_payment_personal_expense(uuid);
drop function if exists public.handle_group_expense_personal_sync();
drop function if exists public.handle_settlement_personal_sync();
drop function if exists public.get_or_create_special_category(uuid, text, text, text);
drop function if exists public.upsert_settlement_mirror_expenses(uuid);
drop function if exists public.delete_settlement_mirror_expenses(uuid);

-- -------------------------------------------------------
-- Helper: get or create special category for a user
-- -------------------------------------------------------

create or replace function public.get_or_create_special_category(
    p_user_id uuid,
    p_name text,
    p_icon text,
    p_color text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_category_id uuid;
begin
    select c.id into v_category_id
    from public.categories c
    where c.user_id = p_user_id
      and lower(c.name) = lower(p_name)
    limit 1;

    if v_category_id is null then
        insert into public.categories (user_id, name, icon, color)
        values (p_user_id, p_name, p_icon, p_color)
        on conflict (user_id, name) do update
        set icon = excluded.icon,
            color = excluded.color
        returning id into v_category_id;
    end if;

    return v_category_id;
end;
$$;

-- -------------------------------------------------------
-- Validate settlement against group expense
-- -------------------------------------------------------

create or replace function public.validate_settlement_group_expense()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    ge record;
    split_row record;
    total_settled numeric(12,2);
begin
    if new.from_user = new.to_user then
        raise exception 'Settlement payer and receiver cannot be same user';
    end if;

    if not exists (select 1 from public.group_members gm where gm.group_id = new.group_id and gm.user_id = new.from_user) then
        raise exception 'Settlement from_user is not a member of this group';
    end if;

    if not exists (select 1 from public.group_members gm where gm.group_id = new.group_id and gm.user_id = new.to_user) then
        raise exception 'Settlement to_user is not a member of this group';
    end if;

    if new.group_expense_id is null then
        return new;
    end if;

    select * into ge from public.group_expenses where id = new.group_expense_id;
    if not found then
        raise exception 'Invalid group_expense_id';
    end if;

    if ge.group_id <> new.group_id then
        raise exception 'Settlement group_id does not match group_expense.group_id';
    end if;

    if ge.paid_by <> new.to_user then
        raise exception 'Settlement receiver must be the original payer';
    end if;

    select es.* into split_row
    from public.expense_splits es
    where es.group_expense_id = new.group_expense_id
      and es.user_id = new.from_user;

    if not found then
        raise exception 'Settlement payer must be part of the selected expense split';
    end if;

    select coalesce(sum(s.amount), 0)
    into total_settled
    from public.settlements s
    where s.group_expense_id = new.group_expense_id
      and s.from_user = new.from_user
      and s.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid);

    total_settled := total_settled + new.amount;

    if total_settled > split_row.share_amount then
        raise exception 'Total settlements for this user cannot exceed their split share';
    end if;

    return new;
end;
$$;

-- -------------------------------------------------------
-- Recompute personal expense for group payment payer
-- -------------------------------------------------------

create or replace function public.recompute_group_payment_personal_expense(p_group_expense_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    ge record;
    total_reimbursed numeric(12,2) := 0;
begin
    select * into ge from public.group_expenses where id = p_group_expense_id;
    if not found then return; end if;

    select coalesce(sum(s.amount), 0)
    into total_reimbursed
    from public.settlements s
    where s.group_expense_id = p_group_expense_id
      and s.to_user = ge.paid_by;

    if total_reimbursed > ge.amount then
        total_reimbursed := ge.amount;
    end if;

    insert into public.expenses (
        user_id, category_id, amount, gross_amount, reimbursed_amount, net_amount,
        description, expense_date, source_type, source_id, source_group_id,
        is_group_payment, is_auto_generated
    )
    values (
        ge.paid_by,
        ge.category_id,
        ge.amount - total_reimbursed,
        ge.amount,
        total_reimbursed,
        ge.amount - total_reimbursed,
        ge.description || ' (Group payment)',
        ge.expense_date,
        'group_expense_payment',
        ge.id,
        ge.group_id,
        true,
        true
    )
    on conflict (source_id) where source_type = 'group_expense_payment'
    do update set
        category_id = excluded.category_id,
        amount = excluded.amount,
        gross_amount = excluded.gross_amount,
        reimbursed_amount = excluded.reimbursed_amount,
        net_amount = excluded.net_amount,
        description = excluded.description,
        expense_date = excluded.expense_date,
        source_group_id = excluded.source_group_id,
        is_group_payment = excluded.is_group_payment,
        is_auto_generated = excluded.is_auto_generated;
end;
$$;

-- -------------------------------------------------------
-- Settlement mirror expense helpers
-- -------------------------------------------------------

create or replace function public.delete_settlement_mirror_expenses(p_settlement_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    delete from public.expenses
    where source_id = p_settlement_id
      and source_type in ('settlement_paid', 'settlement_received');
end;
$$;

create or replace function public.upsert_settlement_mirror_expenses(p_settlement_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    s record;
    paid_category_id uuid;
    received_category_id uuid;
    expense_desc text;
    receive_desc text;
begin
    select st.* into s from public.settlements st where st.id = p_settlement_id;
    if not found then return; end if;

    paid_category_id := public.get_or_create_special_category(s.from_user, 'Settlement Paid', '↗️', '#ef4444');
    received_category_id := public.get_or_create_special_category(s.to_user, 'Settlement Received', '↙️', '#10b981');
    expense_desc := coalesce(nullif(trim(s.note), ''), 'Settlement paid');
    receive_desc := coalesce(nullif(trim(s.note), ''), 'Settlement received');

    insert into public.expenses (
        user_id, category_id, amount, gross_amount, reimbursed_amount, net_amount,
        description, expense_date, source_type, source_id, source_group_id,
        is_group_payment, is_auto_generated
    )
    values (
        s.from_user,
        paid_category_id,
        s.amount,
        s.amount,
        0,
        s.amount,
        expense_desc,
        coalesce(s.settled_at::date, current_date),
        'settlement_paid',
        s.id,
        s.group_id,
        false,
        true
    )
    on conflict (source_id, user_id) where source_type = 'settlement_paid'
    do update set
        category_id = excluded.category_id,
        amount = excluded.amount,
        gross_amount = excluded.gross_amount,
        reimbursed_amount = excluded.reimbursed_amount,
        net_amount = excluded.net_amount,
        description = excluded.description,
        expense_date = excluded.expense_date,
        source_group_id = excluded.source_group_id,
        is_group_payment = excluded.is_group_payment,
        is_auto_generated = excluded.is_auto_generated;

    insert into public.expenses (
        user_id, category_id, amount, gross_amount, reimbursed_amount, net_amount,
        description, expense_date, source_type, source_id, source_group_id,
        is_group_payment, is_auto_generated
    )
    values (
        s.to_user,
        received_category_id,
        s.amount,
        s.amount,
        s.amount,
        0,
        receive_desc,
        coalesce(s.settled_at::date, current_date),
        'settlement_received',
        s.id,
        s.group_id,
        false,
        true
    )
    on conflict (source_id, user_id) where source_type = 'settlement_received'
    do update set
        category_id = excluded.category_id,
        amount = excluded.amount,
        gross_amount = excluded.gross_amount,
        reimbursed_amount = excluded.reimbursed_amount,
        net_amount = excluded.net_amount,
        description = excluded.description,
        expense_date = excluded.expense_date,
        source_group_id = excluded.source_group_id,
        is_group_payment = excluded.is_group_payment,
        is_auto_generated = excluded.is_auto_generated;
end;
$$;

-- -------------------------------------------------------
-- Trigger functions: group expense + settlement personal sync
-- -------------------------------------------------------

create or replace function public.handle_group_expense_personal_sync()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if tg_op = 'DELETE' then
        delete from public.expenses where source_type = 'group_expense_payment' and source_id = old.id;
        return old;
    end if;
    perform public.recompute_group_payment_personal_expense(new.id);
    return new;
end;
$$;

create or replace function public.handle_settlement_personal_sync()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if tg_op = 'DELETE' then
        perform public.delete_settlement_mirror_expenses(old.id);
        if old.group_expense_id is not null then
            perform public.recompute_group_payment_personal_expense(old.group_expense_id);
        end if;
        return old;
    end if;

    if tg_op = 'UPDATE' and old.group_expense_id is distinct from new.group_expense_id and old.group_expense_id is not null then
        perform public.recompute_group_payment_personal_expense(old.group_expense_id);
    end if;

    perform public.upsert_settlement_mirror_expenses(new.id);

    if new.group_expense_id is not null then
        perform public.recompute_group_payment_personal_expense(new.group_expense_id);
    end if;

    return new;
end;
$$;

create trigger trg_validate_settlement_group_expense before insert or update on public.settlements for each row execute function public.validate_settlement_group_expense();
create trigger trg_group_expense_personal_sync after insert or update or delete on public.group_expenses for each row execute function public.handle_group_expense_personal_sync();
create trigger trg_settlement_personal_sync after insert or update or delete on public.settlements for each row execute function public.handle_settlement_personal_sync();

-- -------------------------------------------------------
-- Backfill: settlement categories for existing profiles
-- -------------------------------------------------------

insert into public.categories (user_id, name, icon, color)
select p.id, 'Settlement Paid', '↗️', '#ef4444'
from public.profiles p
on conflict (user_id, name) do nothing;

insert into public.categories (user_id, name, icon, color)
select p.id, 'Settlement Received', '↙️', '#10b981'
from public.profiles p
on conflict (user_id, name) do nothing;

-- -------------------------------------------------------
-- Backfill: personal expenses from existing group expenses
-- -------------------------------------------------------

insert into public.expenses (
    user_id, category_id, amount, gross_amount, reimbursed_amount, net_amount,
    description, expense_date, source_type, source_id, source_group_id,
    is_group_payment, is_auto_generated
)
select
    ge.paid_by,
    ge.category_id,
    ge.amount - least(ge.amount, coalesce(sett.total_reimbursed, 0)),
    ge.amount,
    least(ge.amount, coalesce(sett.total_reimbursed, 0)),
    ge.amount - least(ge.amount, coalesce(sett.total_reimbursed, 0)),
    ge.description || ' (Group payment)',
    ge.expense_date,
    'group_expense_payment',
    ge.id,
    ge.group_id,
    true,
    true
from public.group_expenses ge
left join (
    select s.group_expense_id, coalesce(sum(s.amount), 0) as total_reimbursed
    from public.settlements s
    where s.group_expense_id is not null
    group by s.group_expense_id
) sett on sett.group_expense_id = ge.id
on conflict (source_id) where source_type = 'group_expense_payment'
do update set
    category_id = excluded.category_id,
    amount = excluded.amount,
    gross_amount = excluded.gross_amount,
    reimbursed_amount = excluded.reimbursed_amount,
    net_amount = excluded.net_amount,
    description = excluded.description,
    expense_date = excluded.expense_date,
    source_group_id = excluded.source_group_id,
    is_group_payment = excluded.is_group_payment,
    is_auto_generated = excluded.is_auto_generated;

-- -------------------------------------------------------
-- Backfill: personal expenses from existing settlements (paid)
-- -------------------------------------------------------

insert into public.expenses (
    user_id, category_id, amount, gross_amount, reimbursed_amount, net_amount,
    description, expense_date, source_type, source_id, source_group_id,
    is_group_payment, is_auto_generated
)
select
    s.from_user,
    cp.id,
    s.amount,
    s.amount,
    0,
    s.amount,
    coalesce(nullif(trim(s.note), ''), 'Settlement paid'),
    coalesce(s.settled_at::date, current_date),
    'settlement_paid',
    s.id,
    s.group_id,
    false,
    true
from public.settlements s
join public.categories cp
  on cp.user_id = s.from_user
 and lower(cp.name) = lower('Settlement Paid')
on conflict (source_id, user_id) where source_type = 'settlement_paid'
do update set
    category_id = excluded.category_id,
    amount = excluded.amount,
    gross_amount = excluded.gross_amount,
    reimbursed_amount = excluded.reimbursed_amount,
    net_amount = excluded.net_amount,
    description = excluded.description,
    expense_date = excluded.expense_date,
    source_group_id = excluded.source_group_id,
    is_group_payment = excluded.is_group_payment,
    is_auto_generated = excluded.is_auto_generated;

-- -------------------------------------------------------
-- Backfill: personal expenses from existing settlements (received)
-- -------------------------------------------------------

insert into public.expenses (
    user_id, category_id, amount, gross_amount, reimbursed_amount, net_amount,
    description, expense_date, source_type, source_id, source_group_id,
    is_group_payment, is_auto_generated
)
select
    s.to_user,
    cr.id,
    s.amount,
    s.amount,
    s.amount,
    0,
    coalesce(nullif(trim(s.note), ''), 'Settlement received'),
    coalesce(s.settled_at::date, current_date),
    'settlement_received',
    s.id,
    s.group_id,
    false,
    true
from public.settlements s
join public.categories cr
  on cr.user_id = s.to_user
 and lower(cr.name) = lower('Settlement Received')
on conflict (source_id, user_id) where source_type = 'settlement_received'
do update set
    category_id = excluded.category_id,
    amount = excluded.amount,
    gross_amount = excluded.gross_amount,
    reimbursed_amount = excluded.reimbursed_amount,
    net_amount = excluded.net_amount,
    description = excluded.description,
    expense_date = excluded.expense_date,
    source_group_id = excluded.source_group_id,
    is_group_payment = excluded.is_group_payment,
    is_auto_generated = excluded.is_auto_generated;

-- -------------------------------------------------------
-- Enable Row Level Security
-- -------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.expenses enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_expenses enable row level security;
alter table public.expense_splits enable row level security;
alter table public.settlements enable row level security;

-- -------------------------------------------------------
-- Grants
-- -------------------------------------------------------

grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.categories to authenticated;
grant select, insert, update, delete on public.expenses to authenticated;
grant select, insert, update, delete on public.groups to authenticated;
grant select, insert, update, delete on public.group_members to authenticated;
grant select, insert, update, delete on public.group_expenses to authenticated;
grant select, insert, update, delete on public.expense_splits to authenticated;
grant select, insert, update, delete on public.settlements to authenticated;

-- -------------------------------------------------------
-- Drop existing policies before recreating
-- -------------------------------------------------------

drop policy if exists "Profiles viewable by authenticated" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "Own categories select" on public.categories;
drop policy if exists "Own categories insert" on public.categories;
drop policy if exists "Own categories update" on public.categories;
drop policy if exists "Own categories delete" on public.categories;
drop policy if exists "Own expenses select" on public.expenses;
drop policy if exists "Own expenses insert" on public.expenses;
drop policy if exists "Own expenses update" on public.expenses;
drop policy if exists "Own expenses delete" on public.expenses;
drop policy if exists "View groups where member" on public.groups;
drop policy if exists "Create groups" on public.groups;
drop policy if exists "Group creator can update" on public.groups;
drop policy if exists "Group creator can delete" on public.groups;
drop policy if exists "View members of own groups" on public.group_members;
drop policy if exists "Group creator can add members" on public.group_members;
drop policy if exists "Remove members - creator or self" on public.group_members;
drop policy if exists "View group expenses if member" on public.group_expenses;
drop policy if exists "Add group expenses if member" on public.group_expenses;
drop policy if exists "Update own group expenses" on public.group_expenses;
drop policy if exists "Delete own group expenses" on public.group_expenses;
drop policy if exists "View splits of group expenses" on public.expense_splits;
drop policy if exists "Manage splits if expense payer" on public.expense_splits;
drop policy if exists "View settlements of own groups" on public.settlements;
drop policy if exists "Add settlements where involved" on public.settlements;
drop policy if exists "Update settlements where involved" on public.settlements;
drop policy if exists "Delete settlements where involved" on public.settlements;

-- -------------------------------------------------------
-- RLS Policies
-- -------------------------------------------------------

create policy "Profiles viewable by authenticated" on public.profiles for select to authenticated using (true);
create policy "Users can update own profile" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

create policy "Own categories select" on public.categories for select to authenticated using (auth.uid() = user_id);
create policy "Own categories insert" on public.categories for insert to authenticated with check (auth.uid() = user_id);
create policy "Own categories update" on public.categories for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Own categories delete" on public.categories for delete to authenticated using (auth.uid() = user_id);

create policy "Own expenses select" on public.expenses for select to authenticated using (auth.uid() = user_id);
create policy "Own expenses insert" on public.expenses for insert to authenticated with check (auth.uid() = user_id);
create policy "Own expenses update" on public.expenses for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Own expenses delete" on public.expenses for delete to authenticated using (auth.uid() = user_id);

create policy "View groups where member" on public.groups for select to authenticated using (created_by = auth.uid() or public.is_group_member(id));
create policy "Create groups" on public.groups for insert to authenticated with check (auth.uid() = created_by);
create policy "Group creator can update" on public.groups for update to authenticated using (auth.uid() = created_by) with check (auth.uid() = created_by);
create policy "Group creator can delete" on public.groups for delete to authenticated using (auth.uid() = created_by);

create policy "View members of own groups" on public.group_members for select to authenticated using (user_id = auth.uid() or public.is_group_creator(group_id) or public.is_group_member(group_id));
create policy "Group creator can add members" on public.group_members for insert to authenticated with check (user_id = auth.uid() or public.is_group_creator(group_id));
create policy "Remove members - creator or self" on public.group_members for delete to authenticated using (user_id = auth.uid() or public.is_group_creator(group_id));

create policy "View group expenses if member" on public.group_expenses for select to authenticated using (public.is_group_member(group_id) or public.is_group_creator(group_id));
create policy "Add group expenses if member" on public.group_expenses for insert to authenticated with check (public.is_group_member(group_id) or public.is_group_creator(group_id));
create policy "Update own group expenses" on public.group_expenses for update to authenticated using (auth.uid() = paid_by) with check (auth.uid() = paid_by);
create policy "Delete own group expenses" on public.group_expenses for delete to authenticated using (auth.uid() = paid_by);

create policy "View splits of group expenses" on public.expense_splits for select to authenticated using (exists (select 1 from public.group_expenses ge where ge.id = expense_splits.group_expense_id and (public.is_group_member(ge.group_id) or public.is_group_creator(ge.group_id))));
create policy "Manage splits if expense payer" on public.expense_splits for all to authenticated using (exists (select 1 from public.group_expenses ge where ge.id = expense_splits.group_expense_id and (public.is_group_member(ge.group_id) or public.is_group_creator(ge.group_id)))) with check (exists (select 1 from public.group_expenses ge where ge.id = expense_splits.group_expense_id and (public.is_group_member(ge.group_id) or public.is_group_creator(ge.group_id))));

create policy "View settlements of own groups" on public.settlements for select to authenticated using (public.is_group_member(group_id) or public.is_group_creator(group_id));
create policy "Add settlements where involved" on public.settlements for insert to authenticated with check ((auth.uid() = from_user or auth.uid() = to_user) and (public.is_group_member(group_id) or public.is_group_creator(group_id)));
create policy "Update settlements where involved" on public.settlements for update to authenticated using ((auth.uid() = from_user or auth.uid() = to_user) and (public.is_group_member(group_id) or public.is_group_creator(group_id))) with check ((auth.uid() = from_user or auth.uid() = to_user) and (public.is_group_member(group_id) or public.is_group_creator(group_id)));
create policy "Delete settlements where involved" on public.settlements for delete to authenticated using ((auth.uid() = from_user or auth.uid() = to_user) and (public.is_group_member(group_id) or public.is_group_creator(group_id)));

-- DONE

drop policy if exists "Delete own group expenses" on public.group_expenses;

create policy "Delete own group expenses" on public.group_expenses
for delete to authenticated
using (
  auth.uid() = paid_by 
  or public.is_group_creator(group_id)
);