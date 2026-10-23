# ASG Operations ERP

A GitHub-ready starter ERP aligned to ASG Systems' business areas: security and automation projects, site delivery, CRM, inventory, procurement, finance, HR, installation, and maintenance.

## Important status

This is a **starter application**, not a fully audited production ERP. It includes an executive dashboard, module navigation, search, CSV export, add-record forms, Supabase email/password authentication, a PostgreSQL schema, and row-level security starter policies. Dashboard sample data is illustrative only. Some complex workflows (full accounting ledger, payroll calculations, approvals, stock movement ledger, scheduled notifications, document uploads, and complete role-by-role authorization) still need implementation and acceptance testing before real business use.

## Recommended deployment

GitHub Pages only serves static frontend files; it does not host a backend or database. This project uses:
- **Frontend:** React + Vite
- **Authentication/database:** Supabase Auth + PostgreSQL
- **Source control:** GitHub
- **Static hosting:** GitHub Pages for a project site, or another static host if you later need smoother SPA routing.

### 1. Create a Supabase project
1. Open https://supabase.com/ and create a project.
2. In Project Settings → API, copy the Project URL and the publishable/anon key.
3. Open SQL Editor, paste `supabase/schema.sql`, and run it.
4. In Authentication settings, decide whether to require email confirmation. For a company ERP, use managed invitations / approved accounts rather than public signup for general staff.
5. IMPORTANT: The included schema is a baseline. Before entering real company data, restrict `finance_records` and employee compensation data with stricter role-specific policies, add approval controls, test RLS as every role, and arrange backups.

### 2. Configure locally
Install Node.js LTS from https://nodejs.org/.
```bash
npm install
```
Copy `.env.example` to `.env` and set:
```env
VITE_SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
VITE_SUPABASE_ANON_KEY=YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY
```
Never put a Supabase service-role key in frontend code. Never commit `.env`.
Run:
```bash
npm run dev
```
Open the local URL printed by Vite. If no `.env` is configured, the app runs in demo mode. Demo data is not cloud-persisted and should not be used for real company records.

### 3. Create your GitHub repository
1. Create a repository, e.g. `asg-operations-erp`.
2. Upload the project source files (not `node_modules`, not `.env`).
3. Commit `.env.example`, `package.json`, `index.html`, `vite.config.js`, `src/`, `supabase/`, and this README.
4. You can build locally with `npm run build`; the output is `dist/`.

### 4. GitHub Pages deployment
1. Add the following repository Actions secret/variable values for the frontend build: `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`. The anon/publishable key is designed for frontend use when Row Level Security is correctly configured; do not use a service-role secret.
2. Add `.github/workflows/deploy.yml` (sample below).
3. In GitHub, open Settings → Pages and choose GitHub Actions if prompted.
4. Push to `main` and check the Actions tab. GitHub Pages serves the frontend only; Supabase remains the hosted backend/database.

Create `.github/workflows/deploy.yml`:
```yaml
name: Deploy ASG ERP to GitHub Pages
on:
  push:
    branches: [main]
  workflow_dispatch:
permissions:
  contents: read
  pages: write
  id-token: write
concurrency:
  group: pages
  cancel-in-progress: true
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm install
      - run: npm run build
        env:
          VITE_SUPABASE_URL: ${{ vars.VITE_SUPABASE_URL }}
          VITE_SUPABASE_ANON_KEY: ${{ vars.VITE_SUPABASE_ANON_KEY }}
      - uses: actions/upload-pages-artifact@v3
        with:
          path: dist
  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```
For a private repository or sensitive ERP use, confirm your organization's GitHub plan and access requirements before choosing GitHub Pages. A public website URL is not a private ERP: application authentication and database RLS must be configured correctly.

## First account / roles
New users receive the `User` role by default. A trusted administrator can assign a role in Supabase SQL Editor after confirming the user's identity:
```sql
update public.profiles
set role = 'CEO', full_name = 'Approved Administrator'
where id = 'AUTH_USER_UUID';
```
Do not make the public signup flow the permanent company onboarding process. Disable open registration or restrict account creation after the initial administrator is established.

## Included modules
- CEO dashboard and portfolio metrics
- Projects and contract value tracking
- CRM / sales opportunities
- Inventory items and stock levels
- Procurement orders
- Finance records (starter, not double-entry accounting)
- Installation and maintenance work orders
- Employee directory (starter; not full payroll)
- Tasks and approvals (starter workflow)
- CSV export and search
- Settings / cloud connection status

## Before go-live checklist
- [ ] Confirm the company is authorized to use ASG branding and data.
- [ ] Configure Supabase environment variables and execute the SQL schema.
- [ ] Replace demo data with approved initial data.
- [ ] Restrict finance and employee data by role; do not rely on hiding UI elements.
- [ ] Test sign-in, account recovery, RLS, insert/update/delete and CSV exports.
- [ ] Add proper approval history and audit events for sensitive changes.
- [ ] Configure database backups, retention and incident response.
- [ ] Have the business owner and accountant validate financial reports.
- [ ] Test on mobile and desktop before sharing the production URL.

## ASG source reference
The module selection is informed by ASG Systems' public website, which describes perimeter intrusion detection, electric fencing, vehicle access automation, video surveillance, access control, security screening, fire and life safety, parking management, smart buildings, hospitality automation, skylights, project delivery, and after-sales maintenance.
