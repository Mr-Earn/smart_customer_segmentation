-- Run after schema.sql and after at least one admin or analyst profile exists.
-- Create a Customer Auth account with olivia.chen@email.com to see her record.
do $seed$
declare
  demo_owner uuid;
begin
  select id
  into demo_owner
  from public.profiles
  where role in ('admin', 'analyst')
  order by case role when 'admin' then 0 else 1 end, created_at
  limit 1;

  if demo_owner is null then
    raise exception 'Create an Admin or Analyst account before running demo_seed.sql';
  end if;

  insert into public.customer_records (
    email, name, segment_name, lifetime_spend, order_count,
    days_since_purchase, created_by
  ) values
    ('olivia.chen@email.com', 'Olivia Chen', 'Champions', 1248, 18, 12, demo_owner),
    ('marcus.j@email.com', 'Marcus Johnson', 'Regulars', 682, 11, 21, demo_owner),
    ('sofia.patel@email.com', 'Sofia Patel', 'At risk', 534, 8, 86, demo_owner),
    ('noah.w@email.com', 'Noah Williams', 'New customers', 186, 2, 6, demo_owner),
    ('amara.o@email.com', 'Amara Okafor', 'Champions', 1104, 16, 18, demo_owner),
    ('ethan.r@email.com', 'Ethan Rivera', 'Regulars', 428, 7, 14, demo_owner),
    ('priya.n@email.com', 'Priya Nair', 'At risk', 388, 6, 104, demo_owner),
    ('liam.b@email.com', 'Liam Brooks', 'New customers', 74, 1, 3, demo_owner)
  on conflict (created_by, email) do nothing;

  insert into public.campaigns (
    name, segment_name, message, status, created_by
  ) values
    (
      'Champions thank-you',
      'Champions',
      'Thanks for being one of our most valued customers. Enjoy a reward on your next order.',
      'active',
      demo_owner
    ),
    (
      'Regulars loyalty reward',
      'Regulars',
      'Your loyalty means a lot. Here is something extra for your next visit.',
      'active',
      demo_owner
    ),
    (
      'At-risk welcome back',
      'At risk',
      'It has been a while. We would love to welcome you back with a special offer.',
      'pendingApproval',
      demo_owner
    ),
    (
      'New customer welcome',
      'New customers',
      'Welcome to the community. Enjoy a little extra on your next order.',
      'approved',
      demo_owner
    ),
    (
      'New customer first-order offer',
      'New customers',
      'Welcome. Your first order comes with a little something extra.',
      'active',
      demo_owner
    ),
    (
      'Champions early access',
      'Champions',
      'Get an early look at what is coming next, just for you.',
      'scheduled',
      demo_owner
    )
  on conflict (created_by, name) do nothing;
end;
$seed$;