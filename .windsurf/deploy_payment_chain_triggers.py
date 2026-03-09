#!/usr/bin/env python3
"""
Deploy payment chain notification triggers:
1.1 Remove legacy trigger (doublon)
1.2 New student trigger with precise status
1.3 Notify commercial when prospect declares payment
1.4 Notify commercial when payment confirmed
1.5 Enrich university payload with payment_reason
"""
import requests
import time

PROJECT_REF = "thevdfcwlcqzdoybfvgs"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

RPC_URL = f"https://{PROJECT_REF}.supabase.co/rest/v1/rpc/execute_sql"
HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

def inject_ddl(label, ddl_sql):
    payload = f"SELECT 1) t; {ddl_sql}; SELECT * FROM (SELECT 1"
    r = requests.post(RPC_URL, headers=HEADERS, json={"sql_query": payload}, timeout=60)
    result = r.json()
    if isinstance(result, dict) and result.get('error'):
        print(f"  ❌ {label}: {result['error'][:200]}")
        return False
    else:
        print(f"  ✅ {label}")
        return True

STEPS = []

# ============================================================
# 1.1 — Remove legacy trigger (doublon, ne notifie qu'1 admin)
# ============================================================
STEPS.append(("1.1 Drop legacy trigger", 
    "DROP TRIGGER IF EXISTS trg_app_application_payments_notify ON app.application_payments"))
STEPS.append(("1.1 Drop legacy function",
    "DROP FUNCTION IF EXISTS public.app_notify_application_payment_change() CASCADE"))

# ============================================================
# 1.2 — New student trigger: notifie l'étudiant avec statut précis
# ============================================================
STEPS.append(("1.2 Fn: notify_student_payment_status", """
CREATE OR REPLACE FUNCTION public.app_notify_student_payment_status()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_student_name TEXT; v_program_name TEXT;
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status AND NEW.student_id IS NOT NULL THEN
        SELECT s.full_name INTO v_student_name FROM app.students s WHERE s.id = NEW.student_id;
        SELECT p.name INTO v_program_name FROM app.programs p
            JOIN app.applications a ON a.program_id = p.id
            WHERE a.id = NEW.application_id;
        PERFORM public.app_queue_notification_event(
            NEW.student_id,
            'student_payments',
            'payment_status_changed',
            JSONB_BUILD_OBJECT(
                'payment_id', NEW.id,
                'old_status', OLD.status,
                'new_status', NEW.status,
                'payment_reason', NEW.payment_reason,
                'amount_paid', COALESCE(NEW.amount_paid, 0),
                'amount_due', NEW.amount_due,
                'currency', NEW.currency,
                'program_name', COALESCE(v_program_name, ''),
                'reference_code', COALESCE(NEW.reference_code, '')
            )
        );
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("1.2 Drop old student payment trigger",
    "DROP TRIGGER IF EXISTS trg_student_payment_status_notify ON app.application_payments"))
STEPS.append(("1.2 Create student payment trigger",
    "CREATE TRIGGER trg_student_payment_status_notify AFTER UPDATE ON app.application_payments FOR EACH ROW EXECUTE FUNCTION public.app_notify_student_payment_status()"))

# ============================================================
# 1.3 — Notify commercial when prospect declares a payment
# ============================================================
STEPS.append(("1.3 Fn: notify_commercial_prospect_payment", """
CREATE OR REPLACE FUNCTION public.app_notify_commercial_prospect_payment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE
    v_commercial_id UUID;
    v_student_name TEXT;
    v_program_name TEXT;
    v_reason_label TEXT;
BEGIN
    -- Fire on declaration (INSERT with declared status, or UPDATE to declared_by_student)
    IF (TG_OP = 'INSERT' AND NEW.status = 'declared_by_student')
       OR (TG_OP = 'UPDATE' AND NEW.status = 'declared_by_student' AND OLD.status IS DISTINCT FROM NEW.status)
    THEN
        -- Find the commercial who referred this student
        SELECT ur.commercial_user_id INTO v_commercial_id
        FROM app.user_referrals ur
        WHERE ur.student_id = NEW.student_id
        LIMIT 1;

        IF v_commercial_id IS NOT NULL THEN
            SELECT s.full_name INTO v_student_name FROM app.students s WHERE s.id = NEW.student_id;
            SELECT p.name INTO v_program_name FROM app.programs p
                JOIN app.applications a ON a.program_id = p.id
                WHERE a.id = NEW.application_id;

            v_reason_label := CASE NEW.payment_reason
                WHEN 'application_fee' THEN 'Frais de dossier'
                WHEN 'registration_fee' THEN 'Frais d''inscription'
                WHEN 'tuition_deposit' THEN 'Acompte scolarité'
                WHEN 'td_access' THEN 'Accès TD'
                ELSE 'Paiement'
            END;

            PERFORM public.app_queue_notification_event(
                v_commercial_id,
                'commercial_prospect_payments',
                'prospect_declared_payment',
                JSONB_BUILD_OBJECT(
                    'payment_id', NEW.id,
                    'student_id', NEW.student_id,
                    'student_name', COALESCE(v_student_name, ''),
                    'program_name', COALESCE(v_program_name, ''),
                    'payment_reason', NEW.payment_reason,
                    'reason_label', v_reason_label,
                    'amount_paid', COALESCE(NEW.amount_paid, 0),
                    'currency', NEW.currency,
                    'channel', COALESCE(NEW.channel::TEXT, '')
                )
            );
        END IF;
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("1.3 Drop old commercial prospect trigger",
    "DROP TRIGGER IF EXISTS trg_commercial_prospect_payment_notify ON app.application_payments"))
STEPS.append(("1.3 Create commercial prospect trigger",
    "CREATE TRIGGER trg_commercial_prospect_payment_notify AFTER INSERT OR UPDATE ON app.application_payments FOR EACH ROW EXECUTE FUNCTION public.app_notify_commercial_prospect_payment()"))

# ============================================================
# 1.4 — Notify commercial when payment is confirmed
# ============================================================
STEPS.append(("1.4 Fn: notify_commercial_payment_confirmed", """
CREATE OR REPLACE FUNCTION public.app_notify_commercial_payment_confirmed()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE
    v_commercial_id UUID;
    v_student_name TEXT;
    v_program_name TEXT;
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.status = 'confirmed' AND OLD.status IS DISTINCT FROM NEW.status THEN
        SELECT ur.commercial_user_id INTO v_commercial_id
        FROM app.user_referrals ur
        WHERE ur.student_id = NEW.student_id
        LIMIT 1;

        IF v_commercial_id IS NOT NULL THEN
            SELECT s.full_name INTO v_student_name FROM app.students s WHERE s.id = NEW.student_id;
            SELECT p.name INTO v_program_name FROM app.programs p
                JOIN app.applications a ON a.program_id = p.id
                WHERE a.id = NEW.application_id;

            PERFORM public.app_queue_notification_event(
                v_commercial_id,
                'commercial_prospect_payments',
                'prospect_payment_confirmed',
                JSONB_BUILD_OBJECT(
                    'payment_id', NEW.id,
                    'student_id', NEW.student_id,
                    'student_name', COALESCE(v_student_name, ''),
                    'program_name', COALESCE(v_program_name, ''),
                    'payment_reason', NEW.payment_reason,
                    'amount_paid', COALESCE(NEW.amount_paid, 0),
                    'currency', NEW.currency
                )
            );
        END IF;
    END IF;
    RETURN NEW;
END; $fn$
"""))
STEPS.append(("1.4 Drop old commercial confirmed trigger",
    "DROP TRIGGER IF EXISTS trg_commercial_payment_confirmed_notify ON app.application_payments"))
STEPS.append(("1.4 Create commercial confirmed trigger",
    "CREATE TRIGGER trg_commercial_payment_confirmed_notify AFTER UPDATE ON app.application_payments FOR EACH ROW EXECUTE FUNCTION public.app_notify_commercial_payment_confirmed()"))

# ============================================================
# 1.5 — Enrich university trigger with payment_reason
# ============================================================
STEPS.append(("1.5 Fn: enriched notify_university_payment", """
CREATE OR REPLACE FUNCTION public.app_notify_university_payment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_uni_user RECORD; v_student_name TEXT; v_program_name TEXT; v_reason_label TEXT;
BEGIN
    IF (TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND NEW.status != OLD.status)) AND NEW.university_id IS NOT NULL THEN
        SELECT s.full_name INTO v_student_name FROM app.students s WHERE s.id = NEW.student_id;
        SELECT p.name INTO v_program_name FROM app.programs p
            JOIN app.applications a ON a.program_id = p.id
            WHERE a.id = NEW.application_id;

        v_reason_label := CASE NEW.payment_reason
            WHEN 'application_fee' THEN 'Frais de dossier'
            WHEN 'registration_fee' THEN 'Frais d''inscription'
            WHEN 'tuition_deposit' THEN 'Acompte scolarité'
            WHEN 'td_access' THEN 'Accès TD'
            ELSE 'Paiement'
        END;

        FOR v_uni_user IN
            SELECT u.id AS user_id FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'university'
              AND (u.raw_user_meta_data->>'university_id')::UUID = NEW.university_id
              AND u.banned_until IS NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_uni_user.user_id, 'university_payments', 'payment_update',
                JSONB_BUILD_OBJECT(
                    'payment_id', NEW.id,
                    'student_name', COALESCE(v_student_name,''),
                    'program_name', COALESCE(v_program_name,''),
                    'status', NEW.status,
                    'payment_reason', NEW.payment_reason,
                    'reason_label', v_reason_label,
                    'amount_paid', COALESCE(NEW.amount_paid,0),
                    'amount_due', NEW.amount_due,
                    'currency', NEW.currency
                ));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))
# The trigger trg_uni_payment_notify already exists and points to this function, no need to recreate

# ============================================================
# Also enrich admin trigger with more context
# ============================================================
STEPS.append(("1.5b Fn: enriched notify_admin_payment_declared", """
CREATE OR REPLACE FUNCTION public.app_notify_admin_payment_declared()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_admin RECORD; v_student_name TEXT; v_program_name TEXT; v_reason_label TEXT;
BEGIN
    IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND NEW.status != OLD.status) THEN
        SELECT s.full_name INTO v_student_name FROM app.students s WHERE s.id = NEW.student_id;
        SELECT p.name INTO v_program_name FROM app.programs p
            JOIN app.applications a ON a.program_id = p.id
            WHERE a.id = NEW.application_id;

        v_reason_label := CASE NEW.payment_reason
            WHEN 'application_fee' THEN 'Frais de dossier'
            WHEN 'registration_fee' THEN 'Frais d''inscription'
            WHEN 'tuition_deposit' THEN 'Acompte scolarité'
            WHEN 'td_access' THEN 'Accès TD'
            ELSE 'Paiement'
        END;

        FOR v_admin IN
            SELECT u.id AS user_id FROM auth.users u
            WHERE u.raw_user_meta_data->>'role' = 'admin' AND u.banned_until IS NULL
        LOOP
            PERFORM public.app_queue_notification_event(v_admin.user_id, 'admin_payments', 'payment',
                JSONB_BUILD_OBJECT(
                    'payment_id', NEW.id,
                    'student_name', COALESCE(v_student_name,''),
                    'program_name', COALESCE(v_program_name,''),
                    'status', NEW.status,
                    'payment_reason', NEW.payment_reason,
                    'reason_label', v_reason_label,
                    'amount_paid', COALESCE(NEW.amount_paid,0),
                    'amount_due', NEW.amount_due,
                    'currency', NEW.currency
                ));
        END LOOP;
    END IF;
    RETURN NEW;
END; $fn$
"""))

# ============================================================
# EXECUTION
# ============================================================
def main():
    print("=" * 60)
    print("  DEPLOYING PAYMENT CHAIN TRIGGERS")
    print("=" * 60)
    
    success = 0
    failed = 0
    
    for i, (label, ddl) in enumerate(STEPS, 1):
        print(f"\n  [{i}/{len(STEPS)}]", end=" ")
        if inject_ddl(label, ddl.strip()):
            success += 1
        else:
            failed += 1
        time.sleep(0.3)
    
    print(f"\n\n{'='*60}")
    print(f"  RESULT: {success}/{len(STEPS)} succeeded, {failed} failed")
    print(f"{'='*60}")
    
    # Verify
    print("\n  Verifying payment triggers on app.application_payments...")
    r = requests.post(RPC_URL, headers=HEADERS, json={
        "sql_query": "SELECT tgname, (SELECT proname FROM pg_proc WHERE oid = tgfoid) AS fn FROM pg_trigger WHERE NOT tgisinternal AND tgrelid = 'app.application_payments'::regclass ORDER BY tgname"
    }, timeout=30)
    triggers = r.json()
    if isinstance(triggers, list):
        print(f"  Total triggers on application_payments: {len(triggers)}")
        for t in triggers:
            print(f"    • {t.get('tgname','')} → {t.get('fn','')}")

if __name__ == "__main__":
    main()
