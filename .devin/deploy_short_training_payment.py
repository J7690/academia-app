#!/usr/bin/env python3
"""Créer la RPC de paiement pour formations courtes + colonne payment_status."""
import requests
import time
from supabase_auto_manager import SupabaseAutoManager

def deploy(m, name, sql):
    print(f"📦 {name}...")
    try:
        r = requests.post(f"{m.url}/rest/v1/rpc/execute_ddl",
            headers=m.headers, json={"ddl_query": sql}, timeout=30)
        if r.status_code == 200:
            print(f"   ✅ OK")
            return True
        else:
            print(f"   ❌ {r.text[:200]}")
            return False
    except Exception as e:
        print(f"   ❌ {str(e)[:100]}")
        return False

def main():
    m = SupabaseAutoManager()
    print("\n🚀 DÉPLOIEMENT — Paiement formations courtes\n")

    # 1. Ajouter colonnes payment_status et payment_id à short_training_registrations
    deploy(m, "Colonne payment_status",
        "ALTER TABLE app.short_training_registrations "
        "ADD COLUMN IF NOT EXISTS payment_status text DEFAULT 'pending'")
    
    deploy(m, "Colonne payment_id",
        "ALTER TABLE app.short_training_registrations "
        "ADD COLUMN IF NOT EXISTS payment_id uuid")
    
    deploy(m, "Colonne amount_due",
        "ALTER TABLE app.short_training_registrations "
        "ADD COLUMN IF NOT EXISTS amount_due numeric DEFAULT 0")
    time.sleep(0.2)

    # 2. RPC: créer un paiement pour une inscription formation courte
    deploy(m, "RPC app_student_create_short_training_payment", """
CREATE OR REPLACE FUNCTION public.app_student_create_short_training_payment(
    p_registration_id uuid DEFAULT NULL,
    p_amount numeric DEFAULT 0,
    p_payment_method text DEFAULT 'mobile_money'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_uid uuid;
    v_reg app.short_training_registrations%ROWTYPE;
    v_payment_id uuid;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
    END IF;

    -- Vérifier que l'inscription appartient à l'étudiant
    SELECT * INTO v_reg
    FROM app.short_training_registrations
    WHERE id = p_registration_id AND user_id = v_uid;
    
    IF v_reg.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'registration_not_found');
    END IF;

    -- Créer le paiement dans application_payments
    INSERT INTO app.application_payments (
        user_id, payment_type, reference_id,
        amount, currency, payment_method, status
    ) VALUES (
        v_uid, 'short_training', p_registration_id,
        p_amount, 'XOF', p_payment_method, 'pending'
    ) RETURNING id INTO v_payment_id;

    -- Mettre à jour l'inscription
    UPDATE app.short_training_registrations
    SET payment_id = v_payment_id,
        payment_status = 'pending',
        amount_due = p_amount,
        updated_at = now()
    WHERE id = p_registration_id;

    RETURN jsonb_build_object(
        'success', true,
        'payment_id', v_payment_id,
        'registration_id', p_registration_id,
        'amount', p_amount
    );
END;
$$
    """)
    time.sleep(0.2)

    # 3. RPC: confirmer le paiement (appelé après LigdiCash success)
    deploy(m, "RPC app_confirm_short_training_payment", """
CREATE OR REPLACE FUNCTION public.app_confirm_short_training_payment(
    p_payment_id uuid DEFAULT NULL,
    p_receipt_number text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_uid uuid;
    v_payment app.application_payments%ROWTYPE;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
    END IF;

    SELECT * INTO v_payment
    FROM app.application_payments
    WHERE id = p_payment_id AND user_id = v_uid;
    
    IF v_payment.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'payment_not_found');
    END IF;

    -- Marquer le paiement comme confirmé
    UPDATE app.application_payments
    SET status = 'confirmed',
        updated_at = now()
    WHERE id = p_payment_id;

    -- Mettre à jour l'inscription
    UPDATE app.short_training_registrations
    SET payment_status = 'confirmed',
        status = 'confirmed',
        updated_at = now()
    WHERE payment_id = p_payment_id;

    RETURN jsonb_build_object(
        'success', true,
        'payment_id', p_payment_id,
        'status', 'confirmed'
    );
END;
$$
    """)
    time.sleep(0.2)

    # 4. Permissions
    for rpc in ['app_student_create_short_training_payment', 'app_confirm_short_training_payment']:
        deploy(m, f"GRANT {rpc}", f"GRANT EXECUTE ON FUNCTION public.{rpc} TO authenticated")

    # 5. NOTIFY
    deploy(m, "NOTIFY pgrst", "NOTIFY pgrst, 'reload schema'")
    time.sleep(2)

    # 6. Test
    print("\n🔍 Test API...")
    for rpc in ['app_student_create_short_training_payment', 'app_confirm_short_training_payment']:
        try:
            resp = requests.post(f"{m.url}/rest/v1/rpc/{rpc}",
                headers=m.headers, json={}, timeout=10)
            icon = "✅" if resp.status_code in [200, 400] else "❌"
            print(f"  {icon} {rpc} → {resp.status_code}")
        except:
            print(f"  ❌ {rpc} → ERREUR")

    print("\n✅ Déploiement terminé.\n")

if __name__ == "__main__":
    main()
