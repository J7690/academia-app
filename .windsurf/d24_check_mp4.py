import requests, struct

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/whiteboard-renders/renders/4e098ffa-0ad8-4522-9600-6099f4dcfd25/80818e03cc394331899349114e98d06d.mp4"
r = requests.get(url, timeout=20)
print("status:", r.status_code)
print("size:", len(r.content), "bytes")

data = r.content
print("first 16 bytes hex:", data[:16].hex())
print("ftyp box?", data[4:8] == b'ftyp')
print("first 8:", data[:8])

# Sauvegarder
with open("C:/Users/fasop/AndroidStudioProjects/academia/.windsurf/test_render.mp4", "wb") as f:
    f.write(data)
print("saved to test_render.mp4")

# Lire les atoms MP4
offset = 0
print("\n--- MP4 Atoms ---")
while offset < len(data) - 8:
    size = struct.unpack('>I', data[offset:offset+4])[0]
    name = data[offset+4:offset+8]
    try:
        print(f"  offset={offset} size={size} name={name.decode('ascii', errors='replace')}")
    except:
        print(f"  offset={offset} size={size} name=???")
    if size == 0 or size < 8:
        break
    offset += size
    if offset > 50000:
        break
