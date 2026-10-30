# MOSAIC Beta Prototype

## Project overview

MOSAIC is a customer segmentation and campaign-management prototype built with
Flutter and Supabase. It explores how customer purchase history can be turned
into useful audience segments and relevant offers, while giving Analysts,
Marketing staff, Admins, and Customers role-specific workspaces.

The beta's objectives are to:

- Import and review customer data, then identify actionable customer groups.
- Let staff create, review, and manage targeted campaign drafts.
- Give customers a place to view relevant offers and manage demo orders and
  communication preferences.
- Keep staff access role-scoped and preserve shared data when connected to
  Supabase.

## Beta access and test setup

The repository is the current lecturer-accessible beta. It can be run locally
for a UI and workflow demonstration, or connected to the configured Supabase
project for shared authentication and persistence. No public hosted beta URL or
lecturer account credentials are included in this repository; share those
separately if a hosted deployment is provided.

### Local run

Prerequisites: Flutter SDK, a web browser, and the project dependencies.

```powershell
cd smart_customer_segmentation
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL= --dart-define=SUPABASE_PUBLISHABLE_KEY=
```

The empty compile-time values explicitly disable Supabase, so this mode uses
local device storage. Use it to exercise the interface and role workflows; it
does not provide shared lecturer/student data. In local preview, the sign-up
role selector can be used to try Analyst, Marketing, and Customer workspaces.
Without these empty values, the app uses the configured Supabase project.

### Supabase-backed run

For shared data and real authentication, configure Supabase using the steps in
the project [README](README.md#supabase-setup). Apply `supabase/schema.sql`,
deploy the `admin-user` Edge Function with its service-role key stored only in
Supabase secrets, and prepare demo data with `supabase/demo_seed.sql`. Use a
lecturer/demo account created in Supabase; Admin access must be granted by an
administrator and cannot be self-selected at sign-up. Provide the lecturer
with the deployed web URL and account credentials through a separate channel.

Never put a Supabase service-role key in a Flutter build or share it with
lecturers. The app's financial amounts are sample values in South African rand.

## Core function status

| Core function | Beta status | Notes |
| --- | --- | --- |
| Sign-up, sign-in, session restore, and sign-out | Implemented | Supabase-backed in the configured app; local preview is available without a backend. Password recovery and confirmation depend on Supabase Auth settings. |
| Role-specific Analyst, Marketing, Admin, and Customer workspaces | Implemented | Admin access is assigned separately; signup roles are Analyst, Marketing, or Customer. |
| Customer CSV/API import and data-quality review | Implemented | CSV requires `name` and `email`; quality findings flag records for review rather than editing them. |
| RFM/rule-based segmentation and scenario preview | Implemented | Staff can inspect segment outcomes; scenario changes are previews and are not saved until a run. |
| Custom segments, customer search, profile notes, and cohort export | Implemented | Available in the staff workflow. |
| Campaign drafting, personalization, review, scheduling, and launch state | Implemented | Campaigns are managed in-app; external message delivery is not part of this beta. |
| Staff inbox and Admin audit history | Implemented | Shared persistence and Admin operations require the Supabase schema and Edge Function to be deployed. |
| Customer offers, preferences, sample catalog, and demo orders | Implemented | Checkout creates a demo order request only; it does not collect payment. |
| Delivery, conversion, and revenue attribution analytics | Outstanding | Campaign figures are audience and purchase snapshots, not delivery or conversion measurements. |

Status describes the features documented and wired into the current prototype;
backend-dependent functions still require the Supabase setup above for a shared
test session.

## Suggested realistic test flow

Use [`sample_customers.csv`](sample_customers.csv) for an import demonstration.
It contains eight sample customers across Champions, Regulars, At risk, and New
customers, with spend, order counts, and recency values.

1. Sign in as an Analyst. Open **Data** and review the audience summary and data
   quality review.
2. Import `sample_customers.csv`, inspect the preview, and confirm the import.
3. Run segmentation and review the resulting counts and changed assignments.
   Open **Threshold scenario preview** to compare alternate settings without
   saving them.
4. Open **Segments**, inspect Champions or At risk, then draft a campaign for
   that audience.
5. Sign in as Marketing, personalize the message with `{first_name}` and
   `{segment}`, inspect its sample preview, and submit it for Admin approval.
6. As Admin, approve or schedule the draft and inspect the audit or campaign
   queue. A launched campaign becomes visible to matching customers in the
   prototype; it is not sent through an external marketing provider.
7. As a Customer whose email matches a customer record, inspect Home and
   Offers, adjust the special-offers preference, and optionally submit a sample
   catalog order. The order is a demo request with no payment.

For the seeded Supabase customer example, the README identifies
`olivia.chen@email.com`; an Auth account for that email must exist and be linked
to the seeded customer record. Do not assume the seed script creates an Auth
account.

## Narrated demonstration video

Target length: about 12 minutes, with a hard maximum of 15 minutes. Keep the
application text readable, use a large browser window, and narrate the purpose
of each action. Use the test flow above and avoid showing passwords, secret
keys, or private customer information.

| Time | Narration and demonstration |
| --- | --- |
| 0:00-1:00 | Introduce MOSAIC, its research problem, intended users, and objectives. |
| 1:00-2:15 | Show the sign-in screen and explain the four workspaces. Summarize feature status: implemented workflows, backend setup dependencies, and outstanding delivery/conversion analytics. |
| 2:15-5:00 | As Analyst, review data quality, import the sample CSV, run segmentation, and compare a threshold scenario. |
| 5:00-6:15 | Inspect a segment and explain how its customer membership can guide a campaign audience. |
| 6:15-8:15 | As Marketing, personalize a campaign, inspect the preview, and submit it for approval. As Admin, show the review action or explain the hand-off if only one demo account is available. |
| 8:15-10:15 | As Customer, show relevant offers and preferences, then submit a sample order and point out that it is not a payment. |
| 10:15-11:15 | Explain the value-adding feature: scenario preview lets an Analyst compare segmentation outcomes before applying threshold changes, helping make audience decisions more transparent and reducing trial-and-error on the live dataset. |
| 11:15-12:00 | Discuss implementation challenges and next steps (below), then close with the beta's limitations. |

### Development challenges to discuss

- **Different user needs and permissions:** separate workspaces and role checks
  keep analyst, marketing, admin, and customer tasks distinct. Admin privilege
  is not granted through signup metadata.
- **Keeping local demos and shared data useful:** a local-storage fallback
  supports offline/UI testing, while Supabase is needed for shared accounts and
  persistence. The lecturer should know which mode is being demonstrated.
- **Interpreting imperfect customer data:** quality checks surface invalid or
  duplicate emails and inconsistent records for review without silently
  changing imported data.
- **Avoiding misleading campaign claims:** the prototype shows audience
  snapshots and in-app campaign status, not proof of external message delivery
  or conversion.

## Next steps

1. Publish a stable web beta URL and create time-limited lecturer/demo accounts
   with least-privilege roles.
2. Confirm Supabase schema, signup-role trigger, demo seed data, and Admin Edge
   Function are deployed and tested in the target environment.
3. Add campaign delivery integration and consent-aware delivery reporting, then
   measure conversions against a defined baseline.
4. Evaluate segmentation quality with a larger, representative dataset and
   user feedback; document privacy, data-retention, and access-control
   requirements before using real customer data.
5. Expand automated tests for end-to-end role workflows, imports, segmentation
   edge cases, campaign approval, and order status changes.

## Beta limitations

This is a demonstrable research prototype, not a production commerce or
marketing system. Catalog orders do not take payment, campaign launch does not
send messages externally, and the displayed audience/purchase summaries are
not delivery or conversion metrics. Use sample data for the demonstration.