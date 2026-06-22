import requests

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/video_renditions"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Accept": "application/json",
    "Accept-Profile": "app",
    "Content-Profile": "app"
}

print("=== QUERY VIDEO_RENDITIONS VIA REST ===\n")

# Query video_renditions
params = {
    "select": "*",
    "limit": "10",
    "order": "created_at.desc"
}

resp = requests.get(url, headers=headers, params=params, timeout=30)
print(f'Status: {resp.status_code}')
print(f'Response: {resp.text[:1000]}')
print()

# Try video_assets
url2 = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/video_assets"
resp2 = requests.get(url2, headers=headers, params={"limit": "5"}, timeout=30)
print(f'video_assets Status: {resp2.status_code}')
print(f'video_assets Response: {resp2.text[:1000]}')
print()

# Try video_processing_jobs
url3 = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/video_processing_jobs"
resp3 = requests.get(url3, headers=headers, params={"limit": "5"}, timeout=30)
print(f'video_processing_jobs Status: {resp3.status_code}')
print(f'video_processing_jobs Response: {resp3.text[:1000]}')
print()
