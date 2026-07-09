import requests, struct

url = "https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/whiteboard-renders/renders/486a54f6-0d70-4f56-8e45-7eae4537567e/f78f38d29ac7493b9f68b3fdbaba4925.mp4"
r = requests.get(url, timeout=20)
print("status:", r.status_code)
print("size:", len(r.content), "bytes")
data = r.content

# Atoms MP4
offset = 0
print("\n--- Atoms ---")
while offset < len(data) - 8:
    sz = struct.unpack('>I', data[offset:offset+4])[0]
    nm = data[offset+4:offset+8].decode('ascii', errors='?')
    print(f"  {nm}: {sz} bytes at offset {offset}")
    if sz == 0 or sz < 8:
        break
    offset += sz
    if offset > len(data):
        break

# Chercher les infos de durée dans moov/mvhd
moov_start = data.find(b'moov')
if moov_start >= 0:
    mvhd_start = data.find(b'mvhd', moov_start)
    if mvhd_start >= 0:
        # mvhd version 0: timescale à offset+12, duration à offset+16
        ts_offset = mvhd_start - 4 + 12 + 4
        timescale = struct.unpack('>I', data[ts_offset:ts_offset+4])[0]
        duration = struct.unpack('>I', data[ts_offset+4:ts_offset+8])[0]
        print(f"\n  mvhd timescale={timescale} duration={duration}")
        if timescale > 0:
            print(f"  durée = {duration/timescale:.2f}s")

with open("C:/Users/fasop/AndroidStudioProjects/academia/.windsurf/test_486a.mp4", "wb") as f:
    f.write(data)
print("\nfichier sauvegardé")
