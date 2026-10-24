# ID Vault — ID Management CRM

A deployable Vercel static portal backed by Supabase Auth + Postgres.

## Included
- `index.html` — responsive admin/team lead portal
- `supabase-schema.sql` — database tables, indexes, and row-level security policies

## 1. Set up Supabase
1. Create a Supabase project.
2. Open **SQL Editor**, paste `supabase-schema.sql`, and run it.
3. In **Project Settings → API** (or Connect), copy the Project URL and the publishable key (older projects may call it the `anon` key).
4. Open `index.html` and replace:
   - `PASTE_SUPABASE_URL_HERE`
   - `PASTE_SUPABASE_PUBLISHABLE_OR_ANON_KEY_HERE`
5. Never put a `service_role` or secret key in frontend code.

## 2. Create the first admin
1. In Supabase, open **Authentication → Users → Add user** and create the admin's email/password.
2. Copy that user's UUID.
3. In SQL Editor, run this, replacing the values:
   ```sql
   insert into public.profiles (id, full_name, role)
   values ('AUTH_USER_UUID', 'Admin Name', 'admin');
   ```
4. Sign in to the portal with that account.

## 3. Add team leads
For each team lead:
1. Create a user in **Authentication → Users → Add user**.
2. Copy their UUID.
3. Run:
   ```sql
   insert into public.profiles (id, full_name, role)
   values ('AUTH_USER_UUID', 'Team Lead Name', 'team_lead');
   ```
Accounts are created by the project admin, not through public sign-up.

## 4. Deploy to Vercel
1. Put `index.html` in a GitHub repository (root directory).
2. Import the repository in Vercel.
3. Framework preset: **Other**.
4. Build command: leave empty / override it with no build command.
5. Output directory: `.` (root).
6. Deploy.

No `npm run build` is needed for this static HTML version.

## 5. Access rules
- Team leads can read and update their own entries only.
- Admin can read/update/delete all entries and view team profiles.
- Database row-level security (RLS) is the actual access boundary.
- Admin can create accounts in Supabase Auth and add the corresponding profile row.

## Credential caution
The portal has a Password field because it was part of the requested workflow. This value is stored in the database and is readable by the entry owner and administrators under these RLS policies. Treat these as third-party account credentials: restrict access, use strong Supabase project-owner security, and avoid collecting credentials unless your organization is authorized to manage them. The Supabase publishable/anon key is meant for frontend use; never expose the service-role key.
