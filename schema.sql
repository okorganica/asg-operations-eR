-- ASG Operations ERP starter schema for Supabase (Postgres)
-- Run in Supabase Dashboard > SQL Editor. Review role grants before production use.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default '',
 role text not null default 'User' check (role in ('CEO','Admin','Accounts','Sales','Storekeeper','Project Manager','Service Technician','HR','User')),
 department text,
 created_at timestamptz not null default now()
);
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$ begin
 insert into public.profiles(id, full_name, role)
 values(new.id, coalesce(new.raw_user_meta_data->>'full_name',''), 'User')
 on conflict (id) do nothing;
 return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.current_app_role()
returns text language sql stable security definer set search_path = public
as $$ select role from public.profiles where id = auth.uid() $$;
create or replace function public.is_manager()
returns boolean language sql stable security definer set search_path = public
as $$ select coalesce(public.current_app_role() in ('CEO','Admin'), false) $$;

create table if not exists public.projects (
 id uuid primary key default gen_random_uuid(), reference text not null unique default ('PRJ-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8))),
 name text not null, client text, location text, status text not null default 'Planning',
 value numeric(14,2) not null default 0, due_date date, manager_id uuid references public.profiles(id),
 description text, created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.crm_records (
 id uuid primary key default gen_random_uuid(), reference text not null unique default ('CRM-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8))),
 name text not null, client text, location text, status text not null default 'New Lead', value numeric(14,2) not null default 0,
 due_date date, contact_name text, email text, phone text, source text, notes text, owner_id uuid references public.profiles(id),
 created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.inventory_items (
 id uuid primary key default gen_random_uuid(), sku text not null unique default ('SKU-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8))),
 name text not null, client text, location text, status text not null default 'In Stock', value numeric(14,2) not null default 0,
 quantity integer not null default 0 check(quantity >= 0), reorder_level integer not null default 0, supplier text, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.procurement_orders (
 id uuid primary key default gen_random_uuid(), reference text not null unique default ('PO-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8))),
 name text not null, client text, location text, status text not null default 'Draft', value numeric(14,2) not null default 0,
 due_date date, supplier_name text, approved_by uuid references public.profiles(id), created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.finance_records (
 id uuid primary key default gen_random_uuid(), reference text not null unique default ('FIN-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8))),
 name text not null, client text, location text, status text not null default 'Draft', value numeric(14,2) not null default 0,
 due_date date, record_type text not null default 'Invoice', invoice_number text, notes text, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.service_orders (
 id uuid primary key default gen_random_uuid(), reference text not null unique default ('WO-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8))),
 name text not null, client text, location text, status text not null default 'Open', value numeric(14,2) not null default 0,
 due_date date, project_id uuid references public.projects(id), assigned_to uuid references public.profiles(id), priority text default 'Normal',
 service_type text default 'Maintenance', notes text, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.employees (
 id uuid primary key default gen_random_uuid(), reference text not null unique default ('EMP-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8))),
 name text not null, client text, location text, status text not null default 'Active', value numeric(14,2) not null default 0,
 due_date date, department text, job_title text, work_email text, phone text, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.tasks (
 id uuid primary key default gen_random_uuid(), reference text not null unique default ('TASK-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8))),
 name text not null, client text, location text, status text not null default 'Pending', value numeric(14,2) not null default 0,
 due_date date, assigned_to uuid references public.profiles(id), priority text default 'Normal', created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.audit_logs (
 id uuid primary key default gen_random_uuid(), actor_id uuid references auth.users(id), action text not null, table_name text, record_id text, details jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.projects enable row level security;
alter table public.crm_records enable row level security;
alter table public.inventory_items enable row level security;
alter table public.procurement_orders enable row level security;
alter table public.finance_records enable row level security;
alter table public.service_orders enable row level security;
alter table public.employees enable row level security;
alter table public.tasks enable row level security;
alter table public.audit_logs enable row level security;

-- Base starter policies: signed-in team members can access operational records.
-- Finance/payroll requires tighter production policies before real data is loaded.
drop policy if exists "Profiles visible to signed in users" on public.profiles;
create policy "Profiles visible to signed in users" on public.profiles for select to authenticated using (true);
drop policy if exists "Users update own profile or managers update all" on public.profiles;
create policy "Users update own profile or managers update all" on public.profiles for update to authenticated using (id=auth.uid() or public.is_manager()) with check (id=auth.uid() or public.is_manager());

do $$ declare t text; begin
 foreach t in array array['projects','crm_records','inventory_items','procurement_orders','finance_records','service_orders','employees','tasks'] loop
  execute format('drop policy if exists "Signed in users read %1$s" on public.%1$I',t);
  execute format('create policy "Signed in users read %1$s" on public.%1$I for select to authenticated using (true)',t);
  execute format('drop policy if exists "Signed in users create %1$s" on public.%1$I',t);
  execute format('create policy "Signed in users create %1$s" on public.%1$I for insert to authenticated with check (auth.uid() = created_by or public.is_manager())',t);
  execute format('drop policy if exists "Managers update %1$s" on public.%1$I',t);
  execute format('create policy "Managers update %1$s" on public.%1$I for update to authenticated using (public.is_manager()) with check (public.is_manager())',t);
  execute format('drop policy if exists "Managers delete %1$s" on public.%1$I',t);
  execute format('create policy "Managers delete %1$s" on public.%1$I for delete to authenticated using (public.is_manager())',t);
 end loop;
end $$;
drop policy if exists "Managers read audit logs" on public.audit_logs;
create policy "Managers read audit logs" on public.audit_logs for select to authenticated using (public.is_manager());
drop policy if exists "Signed in users create audit logs" on public.audit_logs;
create policy "Signed in users create audit logs" on public.audit_logs for insert to authenticated with check (actor_id=auth.uid());

create index if not exists projects_status_idx on public.projects(status);
create index if not exists crm_status_idx on public.crm_records(status);
create index if not exists inventory_sku_idx on public.inventory_items(sku);
create index if not exists service_due_date_idx on public.service_orders(due_date);
create index if not exists tasks_due_date_idx on public.tasks(due_date);
