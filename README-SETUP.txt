# ID Vault — ID Management CRM

A Vercel static portal backed by Supabase Auth + Postgres.

## Included
- `index.html` — responsive admin/team lead portal with public account creation
- `supabase-schema.sql` — database tables, row-level security, and automatic Team Lead profiles
- `README-SETUP.txt` — setup instructions

## 1. Set up Supabase
1. Create a Supabase project.
2. Open **SQL Editor**, paste `supabase-schema.sql`, and run it.
3. In `index.html`, replace `PASTE_SUPABASE_URL_HERE` and `PASTE_SUPABASE_PUBLISHABLE_OR_ANON_KEY_HERE` with your project's URL and publishable/anon key.
4. Never put a `service_role` or secret key in frontend code.

## 2. Create the first admin
1. In Supabase **Authentication → Users**, create an account for yourself (you can use the portal sign-up after deploying, too).
2. Copy that user's UUID from Authentication → Users.
3. In SQL Editor, run:
   ```sql
   update public.profiles set role = 'admin', full_name = 'Admin Name'
   where id = 'AUTH_USER_UUID';
   ```
   Public sign-ups are always `team_lead`; only the trusted project owner can promote an account to admin.

## 3. Public team lead sign-up
- Users can click **Create an account** on the portal.
- New accounts get the `team_lead` role automatically by a database trigger.
- If email confirmation is enabled in Supabase, the user must confirm their email before signing in. Configure this under **Authentication → URL Configuration** and **Providers** if needed.
- A public sign-up never grants admin access.

## 4. Deploy to Vercel
1. Put `index.html` in the root of a GitHub repository.
2. Import the repository in Vercel.
3. Framework preset: **Other**.
4. Build command: empty / no build command.
5. Output directory: `.`.
6. Deploy. No `npm run build` is needed.

## 5. Access rules
- Team leads can read/update their own entries only.
- Admin can read/update/delete all entries and view team profiles.
- Supabase Row Level Security enforces permissions at the database layer.

## Credential caution
The Password field stores the external account password entered into the portal. This is sensitive information. Collect it only if authorized, and limit access. The Supabase publishable/anon key is for frontend use; never expose the service-role key.
