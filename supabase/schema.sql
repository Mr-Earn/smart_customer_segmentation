create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null unique,
  full_name text not null default '',
  role text not null default 'analyst'
    check (role in ('admin', 'analyst', 'marketing', 'customer')),
  created_at timestamptz not null default now()
);

create table if not exists public.customer_records (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  name text not null,
  segment_name text not null default 'New customers',
  lifetime_spend numeric(14, 2) not null default 0 check (lifetime_spend >= 0),
  order_count integer not null default 0 check (order_count >= 0),
  days_since_purchase integer not null default 0 check (days_since_purchase >= 0),
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  unique (created_by, email)
);

create table if not exists public.customer_segments (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  rule jsonb not null default '{}'::jsonb,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now()
);

create table if not exists public.campaigns (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  segment_name text not null,
  message text not null default '',
  status text not null default 'pendingApproval'
    check (status in ('draft', 'pendingApproval', 'approved', 'scheduled', 'active')),
  scheduled_at timestamptz,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now()
);

create table if not exists public.segmentation_settings (
  id integer primary key default 1 check (id = 1),
  algorithm text not null default 'rfm'
    check (algorithm in ('rfm', 'ruleBased')),
  high_value_spend integer not null default 500 check (high_value_spend >= 0),
  at_risk_days integer not null default 60 check (at_risk_days >= 0),
  updated_by uuid references public.profiles (id),
  updated_at timestamptz not null default now()
);

create table if not exists public.app_user_state (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  favorites text[] not null default '{}',
  notes jsonb not null default '{}'::jsonb,
  preferences jsonb not null default '{}'::jsonb,
  saved_campaigns text[] not null default '{}',
  updated_at timestamptz not null default now()
);

create table if not exists public.customer_orders (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  customer_email text not null,
  items jsonb not null check (jsonb_typeof(items) = 'array'),
  total numeric(14, 2) not null check (total >= 0),
  status text not null default 'received',
  created_at timestamptz not null default now()
);

alter table public.customer_orders
  drop constraint if exists customer_orders_status_check;
alter table public.customer_orders
  add constraint customer_orders_status_check
  check (status in ('received', 'processing', 'fulfilled', 'cancelled'));

alter table public.app_user_state
  add column if not exists saved_campaigns text[] not null default '{}';

create unique index if not exists customer_segments_owner_name_idx
  on public.customer_segments (created_by, name);
create unique index if not exists campaigns_owner_name_idx
  on public.campaigns (created_by, name);
create index if not exists customer_records_email_lower_idx
  on public.customer_records (lower(email));
create index if not exists customer_records_segment_idx
  on public.customer_records (segment_name);
create index if not exists campaigns_status_idx
  on public.campaigns (status);

create or replace function public.current_app_role()
returns text language sql stable security definer set search_path = ''
as $$
  select role from public.profiles where id = (select auth.uid())
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
  select coalesce(public.current_app_role() = 'admin', false)
$$;

create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    case
      when new.raw_user_meta_data ->> 'requested_role' in ('analyst', 'marketing', 'customer')
        then new.raw_user_meta_data ->> 'requested_role'
      else 'analyst'
    end
  )
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

create or replace function public.admin_assign_role(target_user_id uuid, target_role text)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_admin() then raise exception 'Only administrators can assign roles'; end if;
  if target_role not in ('admin', 'analyst', 'marketing', 'customer') then
    raise exception 'Unknown application role';
  end if;
  update public.profiles set role = target_role where id = target_user_id;
  if not found then raise exception 'Profile not found'; end if;
end;
$$;

revoke all on function public.admin_assign_role(uuid, text) from public;
grant execute on function public.admin_assign_role(uuid, text) to authenticated;

alter table public.profiles enable row level security;
alter table public.customer_records enable row level security;
alter table public.customer_segments enable row level security;
alter table public.campaigns enable row level security;
alter table public.segmentation_settings enable row level security;
alter table public.app_user_state enable row level security;
alter table public.customer_orders enable row level security;

grant select on public.profiles to authenticated;
grant update (full_name) on public.profiles to authenticated;
grant select, insert, update, delete on public.customer_records to authenticated;
grant select, insert, update, delete on public.customer_segments to authenticated;
grant select, insert, update on public.campaigns to authenticated;
grant select, insert, update on public.segmentation_settings to authenticated;
grant select, insert, update on public.app_user_state to authenticated;
grant select, insert on public.customer_orders to authenticated;
revoke update on public.customer_orders from authenticated;
grant update (status) on public.customer_orders to authenticated;

drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select to authenticated
  using (id = (select auth.uid()) or public.is_admin());

drop policy if exists profiles_update_name on public.profiles;
create policy profiles_update_name on public.profiles for update to authenticated
  using (id = (select auth.uid()) or public.is_admin())
  with check (id = (select auth.uid()) or public.is_admin());

drop policy if exists customers_read on public.customer_records;
create policy customers_read on public.customer_records for select to authenticated
  using (
    public.current_app_role() in ('admin', 'analyst', 'marketing')
    or (public.current_app_role() = 'customer'
      and lower(email) = lower((select auth.jwt() ->> 'email')))
  );

drop policy if exists customers_insert on public.customer_records;
create policy customers_insert on public.customer_records for insert to authenticated
  with check (public.current_app_role() in ('admin', 'analyst')
    and created_by = (select auth.uid()));

drop policy if exists customers_update on public.customer_records;
create policy customers_update on public.customer_records for update to authenticated
  using (public.current_app_role() in ('admin', 'analyst'))
  with check (public.current_app_role() in ('admin', 'analyst'));

drop policy if exists customers_delete on public.customer_records;
create policy customers_delete on public.customer_records for delete to authenticated
  using (public.current_app_role() in ('admin', 'analyst'));

drop policy if exists segments_read on public.customer_segments;
create policy segments_read on public.customer_segments for select to authenticated
  using (public.current_app_role() in ('admin', 'analyst', 'marketing'));

drop policy if exists segments_manage on public.customer_segments;
create policy segments_manage on public.customer_segments for all to authenticated
  using (public.current_app_role() in ('admin', 'analyst'))
  with check (public.current_app_role() in ('admin', 'analyst')
    and created_by = (select auth.uid()));

drop policy if exists campaigns_read on public.campaigns;
create policy campaigns_read on public.campaigns for select to authenticated
  using (public.current_app_role() in ('admin', 'analyst', 'marketing'));

drop policy if exists campaigns_customer_read_active_segment on public.campaigns;
create policy campaigns_customer_read_active_segment on public.campaigns
  for select to authenticated
  using (
    public.current_app_role() = 'customer'
    and status = 'active'
    and exists (
      select 1 from public.customer_records as customer
      where lower(customer.email) = lower((select auth.jwt() ->> 'email'))
        and customer.segment_name = campaigns.segment_name
    )
  );

drop policy if exists campaigns_create on public.campaigns;
create policy campaigns_create on public.campaigns for insert to authenticated
  with check (public.current_app_role() in ('admin', 'analyst', 'marketing')
    and created_by = (select auth.uid())
    and (public.current_app_role() = 'admin' or status = 'pendingApproval'));

drop policy if exists campaigns_admin_update on public.campaigns;
create policy campaigns_admin_update on public.campaigns for update to authenticated
  using (public.current_app_role() = 'admin')
  with check (public.current_app_role() = 'admin');

drop policy if exists campaigns_owner_launch on public.campaigns;
create policy campaigns_owner_launch on public.campaigns for update to authenticated
  using (public.current_app_role() in ('analyst', 'marketing')
    and created_by = (select auth.uid())
    and status in ('approved', 'scheduled'))
  with check (public.current_app_role() in ('analyst', 'marketing')
    and created_by = (select auth.uid()) and status = 'active');

drop policy if exists settings_read on public.segmentation_settings;
create policy settings_read on public.segmentation_settings for select to authenticated
  using (public.current_app_role() in ('admin', 'analyst', 'marketing'));

drop policy if exists settings_admin_manage on public.segmentation_settings;
create policy settings_admin_manage on public.segmentation_settings for all to authenticated
  using (public.current_app_role() = 'admin')
  with check (public.current_app_role() = 'admin');

drop policy if exists user_state_owner_manage on public.app_user_state;
create policy user_state_owner_manage on public.app_user_state for all to authenticated
  using (profile_id = (select auth.uid()) or public.is_admin())
  with check (profile_id = (select auth.uid()) or public.is_admin());

drop policy if exists customer_orders_read_own on public.customer_orders;
create policy customer_orders_read_own on public.customer_orders
  for select to authenticated
  using (profile_id = (select auth.uid()) or public.is_admin());

drop policy if exists customer_orders_insert_own on public.customer_orders;
create policy customer_orders_insert_own on public.customer_orders
  for insert to authenticated
  with check (
    profile_id = (select auth.uid())
    and public.current_app_role() = 'customer'
    and lower(customer_email) = lower((select auth.jwt() ->> 'email'))
  );

drop policy if exists customer_orders_admin_update on public.customer_orders;
create policy customer_orders_admin_update on public.customer_orders
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists customer_orders_customer_cancel on public.customer_orders;
create policy customer_orders_customer_cancel on public.customer_orders
  for update to authenticated
  using (
    profile_id = (select auth.uid())
    and public.current_app_role() = 'customer'
    and status = 'received'
  )
  with check (
    profile_id = (select auth.uid())
    and public.current_app_role() = 'customer'
    and status = 'cancelled'
  );
