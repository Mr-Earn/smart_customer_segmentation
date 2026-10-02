# Smart Customer Segmentation

A Flutter app for customer segmentation, analytics, and role-scoped workspaces.

## Supabase Setup

Supabase is the primary runtime backend. The project URL and publishable key
are configured for the supplied project; local storage is retained only as an
explicit offline/test fallback when the app is constructed without a backend.

1. Create a Supabase project and open its SQL Editor.
2. Run [`supabase/schema.sql`](supabase/schema.sql) to create the profile,
   customer, segment, campaign, and settings tables with row-level security.
3. Set the Auth email-confirmation policy to match your sign-up flow.
4. Deploy the Admin Edge Function. It must hold the service-role key only in
    Supabase Function secrets, never in Flutter:

```powershell
supabase functions secrets set SUPABASE_SERVICE_ROLE_KEY=YOUR_ROTATED_SECRET_KEY
supabase functions deploy admin-user
```

5. Run the app with the project URL and **publishable** client key when
    overriding the configured defaults:

```powershell
flutter run --dart-define=SUPABASE_URL=https://yrbfbexdojzvdkazpggd.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

The repository includes [`supabase/config.toml`](supabase/config.toml) for
project reference `yrbfbexdojzvdkazpggd`. With the Supabase CLI installed and
authenticated, deploy the Admin function from the project root:

```powershell
supabase link --project-ref yrbfbexdojzvdkazpggd
supabase db execute --file supabase/schema.sql
supabase functions secrets set SUPABASE_SERVICE_ROLE_KEY=YOUR_ROTATED_SECRET
supabase functions deploy admin-user
```

Use `--dart-define` with `flutter build web --release` or
`flutter build apk --release` for release builds as well. Never put a Supabase
`service_role` key in the Flutter app or pass it as a dart-define.

Supabase signup accepts the `analyst`, `marketing`, or `customer` role. The
`handle_new_auth_user` database trigger validates the requested role; signup
metadata cannot grant Admin. For an existing project, ensure the deployed
trigger matches the function in [`supabase/schema.sql`](supabase/schema.sql).
If new signups always land in the Analyst workspace, run
[`supabase/refresh_signup_role_trigger.sql`](supabase/refresh_signup_role_trigger.sql)
in the Supabase SQL Editor. This affects new accounts only; an existing
account's role must be changed by an administrator.
Assign the first administrator from the trusted Supabase SQL Editor, for
example:

```sql
update public.profiles
set role = 'admin'
where email = 'your-admin@example.com';
```

Subsequent role changes should use the `admin_assign_role` database function.
The app reads profile names and roles from Supabase and uses Supabase Auth for
password sign-in, account creation, session restore, and sign-out. Existing
customer records, segments, campaigns, segmentation settings, user profiles,
and user state use Supabase in the normal app entry point.

The client uses only the publishable key. The secret key previously shared in
chat must be rotated before deployment.

## App Journey

MOSAIC takes a customer dataset from import, through segmentation and campaign
review, to relevant offers in the customer workspace. Users see only the
workspace allowed by their account role.

### Run the app

Install the Flutter SDK and configure the Supabase project as described above.
From the Flutter project directory, fetch packages and start the app:

```powershell
flutter pub get
flutter run
```

For a web or Android release build, pass the Supabase URL and publishable key
with `--dart-define` as shown in [Supabase Setup](#supabase-setup). Never ship a
service-role key in a client build.

### Sign in

Use **Sign in** with an existing Supabase account, or choose **Create account**
and provide a name, email, password, and confirmation. If email confirmation is
enabled, follow the link in the confirmation email before signing in. The sign
in screen also supports remembering the email address, password recovery, and
resending a confirmation email when those Supabase flows are enabled.

During signup, select Analyst, Marketing, or Customer to choose the initial
workspace. Admin access must be assigned separately by an existing
administrator. In a local preview without a Supabase backend, the role
selector is for trying each workspace and does not manage production
permissions. The first local preview seeds demo staff accounts and campaigns
once. Choose Customer and sign in with `olivia.chen@email.com` to see linked
Champions activity and active offers. Other roles share the same demo audience
and campaign data.

For Supabase demo data, first apply `supabase/schema.sql`, create at least one
Admin or Analyst profile, and run `supabase/demo_seed.sql` in the Supabase SQL
Editor. Then create or use a Customer Auth account with
`olivia.chen@email.com`. The seed adds records only when they do not already
exist and does not create Auth accounts.

### Analyst workflow

1. Start on **Data** to review the loaded customer count, high-value and
    at-risk counts, and the segment report.
2. Choose **Import CSV or connect API**. A CSV must include `name` and `email`;
    spend, order count, days since purchase, and segment are optional. You can
    also load CSV or JSON from an HTTPS API endpoint (localhost is allowed for
    development). Preview the records, then confirm the import.
3. Choose **Run segmentation** to refresh the current RFM or rule-based
    classification. Administrators configure the algorithm and thresholds.
4. Open **Segments** to inspect segment membership, build a segment from
    customer rules, or compare segments.
5. Open **People** to search and filter customer records, inspect profiles,
    manage favorites and notes, and export or act on a selected cohort.
6. Draft a campaign from a segment when you want Marketing to contact that
    audience.

### Marketing workflow

1. Open **Segments** and choose the draft action for an audience.
2. Edit the campaign name and message. Copy the draft for use elsewhere, or
    choose **Submit for approval** to send it to the Admin workspace.
3. After approval or scheduling, open **Campaigns** and choose **Launch** when
    ready. Launched campaigns are shown to customers whose segment matches the
    campaign target and whose Special offers preference is enabled.

### Admin workflow

Use **Accounts** to invite users, change their roles, or remove accounts. Use
**Models** to choose RFM or rule-based segmentation and adjust model thresholds.
Use **Campaigns** to review pending campaigns, approve them, or schedule an
approved campaign. Use **Orders** to review customer requests and advance them
through Received, Processing, and Fulfilled, or cancel an unfulfilled request.
These are demo orders; no payment is collected. Admins can also import customer
data from the console.

### Customer workflow

Customer accounts have **Home**, **Shop**, **Offers**, **Orders**, and **Profile** navigation:

- **Home** shows purchase totals and loyalty insights when a customer record
  matches the signed-in email. Insights include the RFM tier and scores,
  average order value, and time since the last purchase.
- **Offers** shows the personal offer and active campaigns targeted to the
    customer’s segment. Campaign messages can be copied and saved offers remain
    available after signing out and back in. Turning off **Special offers** in
    Profile hides promotional content.
- **Shop** provides a sample catalog, cart quantity controls, and a confirmation
    step. Checkout creates a demo order request and does not collect payment.
- **Orders** lists the customer’s submitted demo order requests and line totals.
    Customers can cancel an order while it is still Received; cancellation is
    unavailable after processing begins. **Buy again** copies available items to
    the cart at current demo catalog prices and still requires checkout
    confirmation.
- **Profile** lets customers update their display name and manage preferences
  for special offers, product news, and recommendations.

Customer activity is linked by email address. If no record matches the signed-in
email, the workspace shows an unlinked state instead of estimated purchase
figures. Use the account menu in the upper-right corner to sign out.

## Data and Persistence

With Supabase configured, authentication and app data use the Supabase project
and its row-level security policies. Imported customer records, segments,
campaigns, model settings, profiles, and user preferences persist there. When
the app is created without a Supabase backend (such as in tests), it uses local
device storage instead. Customer financial amounts are displayed in South
African rand (ZAR).

Run the automated widget tests from the project directory with:

```powershell
flutter test
```
