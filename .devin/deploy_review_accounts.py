#!/usr/bin/env python3
"""Create Google Play review accounts for all 6 roles in Academia."""
import requests, json

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

PASSWORD = "AcademiaReview2026!"

ACCOUNTS = [
    {"email": "student.review@academia.test", "role": "student", "full_name": "Etudiant Review"},
    {"email": "instructor.review@academia.test", "role": "instructor", "full_name": "Enseignant Review"},
    {"email": "university.review@academia.test", "role": "university", "full_name": "Universite Review"},
    {"email": "admin.review@academia.test", "role": "admin", "full_name": "Admin Review"},
    {"email": "commercial.review@academia.test", "role": "commercial", "full_name": "Commercial Review"},
    {"email": "merchant.review@academia.test", "role": "merchant", "full_name": "Marchand Review"},
]

def create_account(email, role, full_name):
    """Create a user via Supabase Admin Auth API."""
    payload = {
        "email": email,
        "password": PASSWORD,
        "email_confirm": True,
        "user_metadata": {
            "role": role,
            "full_name": full_name,
        }
    }
    r = requests.post(
        f"{URL}/auth/v1/admin/users",
        headers=H,
        json=payload,
        timeout=30
    )
    if r.status_code in (200, 201):
        user_id = r.json().get("id", "?")
        print(f"  [OK] {email} ({role}) -> {user_id}")
        return user_id
    elif r.status_code == 422 and "already been registered" in r.text:
        print(f"  [SKIP] {email} ({role}) -> already exists")
        return None
    else:
        print(f"  [FAIL] {email} ({role}) -> {r.status_code}: {r.text[:200]}")
        return None

print("Creating Google Play review accounts...\n")
for acc in ACCOUNTS:
    create_account(acc["email"], acc["role"], acc["full_name"])

print("\nDone! All accounts use password:", PASSWORD)
