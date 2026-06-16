#!/usr/bin/env python3
"""Test simple array query"""
import requests, json
url='https://thevdfcwlcqzdoybfvgs.supabase.co'
key='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM'
h={'apikey':key,'Authorization':f'Bearer {key}','Content-Type':'application/json'}

# Test 1: simple select
sql1 = "SELECT 'test' as val"
r = requests.post(f'{url}/rest/v1/rpc/admin_execute_sql', headers=h, json={'p_sql': sql1}, timeout=15)
print("Test 1:", r.json())

# Test 2: check one RPC
sql2 = "SELECT routine_name, routine_schema FROM information_schema.routines WHERE routine_schema='public' AND routine_name='app_track_navigation_event'"
r2 = requests.post(f'{url}/rest/v1/rpc/admin_execute_sql', headers=h, json={'p_sql': sql2}, timeout=15)
print("Test 2:", r2.json())

# Test 3: small array
sql3 = "SELECT unnest(ARRAY['app_track_navigation_event','app_check_account_status']) as name"
r3 = requests.post(f'{url}/rest/v1/rpc/admin_execute_sql', headers=h, json={'p_sql': sql3}, timeout=15)
print("Test 3:", r3.json())
