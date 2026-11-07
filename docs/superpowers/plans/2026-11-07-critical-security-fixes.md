# Critical Security Remediation Plan

> **For agentic workers:** Use superpowers:executing-plans. Steps use `- [ ]`.

**Goal:** Close the critical findings that can be fixed safely in code and SQL, keeping Razorpay and without breaking existing flows.

**Architecture:** Server-side Razorpay order creation + amount-bound verification; DB trigger and rate limiting repaired; account deletion made transactional and called while the session is still valid; release signing wired to an external keystore; low-risk platform hardening.

**Tech Stack:** Flutter/Dart, Supabase (Postgres + Edge Functions/Deno), Razorpay Orders API, Gradle Kotlin DSL.

**Spec:** the 2026-11-07 verification matrix against `22cb38d` (the prior HTML/PDF reports were removed from the working tree).

## Scope

In scope (critical): **C1, N1, N2, C2, C5**, plus **H1/M4** (delivered by the N2 rewrite) and **N7** (trivial, same files).

Explicitly out of scope for this pass, with reasons:

- **C3 (RLS):** enabling RLS blind would break every anon co-owner/field-user read. Needs the live schema and a staging run.
- **C4 (private bucket):** an anon client cannot mint signed URLs on a private bucket (RLS applies to `createSignedUrl`). Making it private without a server-side URL signer breaks every image. Needs a storage-auth redesign.
- **H4 / H2 / N6:** store billing, legal copy, and Google Cloud console — not code.
- **C6:** trust model decision, not a patch.

## Global Constraints

- Do not change the co-owner login response shape: `{co_owner_id, co_owner_name, owner}`.
- Keep `razorpayKeyId` as a fallback; the server-issued order returns the key.
- All Edge Function errors return generic messages; details go to `console.error`.
- No Flutter SDK is available in this environment: Dart changes are verified by inspection, not compilation.
- SQL must be idempotent and safe to run after `20261102_security_hardening.sql`.

## Tasks

### Task 1: C1 + C5 database repair
**Files:** Create `supabase/migrations/20261107_critical_security_fixes.sql`
- [ ] Fix `protect_owner_subscription_fields` to use `current_setting('role')` only (drop `current_user = 'postgres'`, which is always true under `SECURITY DEFINER`).
- [ ] Add the unique constraint required by `ON CONFLICT (identifier, attempt_type)`.
- [ ] Add `owner_admins.access_code_expires_at`, backfill active codes to +180 days.
- [ ] Re-create `login_co_owner_with_code` calling `check_rate_limit` / `record_failed_attempt` / `clear_rate_limit`, enforcing expiry, preserving the return shape.

### Task 2: N1 order creation
**Files:** Create `supabase/functions/create-order/index.ts`
- [ ] Authenticate the caller by JWT.
- [ ] Validate `extra_projects` 1..20; compute amount from `PRO_PRICE_PAISE` (default 49900).
- [ ] Create the Razorpay order with `notes.owner_id` and `notes.extra_projects`.
- [ ] Return `{order_id, amount, currency, key_id, extra_projects}`.

### Task 3: N1 verification
**Files:** Modify `supabase/functions/verify-payment/index.ts`
- [ ] Keep HMAC verification (constant-time).
- [ ] Fetch the order from Razorpay; require `notes.owner_id === user.id`, `currency === INR`, and `amount === slots * PRICE`.
- [ ] Derive `slots` from the order, never from the request body.
- [ ] Idempotency: if `last_payment_id` already equals this payment, return success without adding slots.

### Task 4: N2 + H1 + M4 account deletion
**Files:** Modify `supabase/functions/delete-account/index.ts`, `lib/providers/auth_provider.dart`, `lib/repositories/auth_repository.dart`
- [ ] Check `error` on every delete; tolerate only `42P01` (undefined table).
- [ ] Delete images by `submission_id`, and remove their Storage objects.
- [ ] Delete the auth user last.
- [ ] Invoke the function **before** `logout()` and surface non-200 responses.
- [ ] Return generic error text (N7).

### Task 5: Razorpay client
**Files:** Modify `lib/features/owner/billing/screens/billing_screen.dart`
- [ ] Make `_startPayment` async: call `create-order`, then open checkout with `order_id` and the server amount.
- [ ] `_onSuccess` sends only payment/order/signature.

### Task 6: C2 release signing
**Files:** Modify `android/app/build.gradle.kts`, `.gitignore`
- [ ] Load `android/key.properties` when present; define a release signing config.
- [ ] Fall back to debug only when the file is absent, with a build warning.
- [ ] Ignore `key.properties`, `*.jks`, `*.keystore`.

### Task 7: N8 platform hygiene
**Files:** Modify `android/app/src/main/AndroidManifest.xml`
- [ ] Remove `android:requestLegacyExternalStorage="true"`.

## Verification

- [ ] `git grep` confirms no client write to `plan_type` / `pro_project_slots` / `pro_expires_at`.
- [ ] `git grep` confirms the billing screen sends `order_id`.
- [ ] `git grep` confirms `triggerAccountDeletion()` precedes `logout()`.
- [ ] `git grep` confirms no `String(e)` / `error.message` echoed from Edge Functions.
- [ ] Confirm the SQL parses by inspection; run in staging first.
- [ ] Cannot run `flutter analyze` (no SDK). State this in the handoff.
