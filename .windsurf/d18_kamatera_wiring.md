# D.18 – PHASE 4: KAMATERA WIRING

**Date**: 2026-06-26
**Mission**: D.18

---

## 1. WORKER PYTHON RÉELLEMENT LANCÉ

### Fichier

`academia_bobodo_backend/whiteboard_render_worker.py`

### Point d'entrée

```python
@academia_bobodo_backend/whiteboard_render_worker.py:169-173
if __name__ == "__main__":
    if not WORKER_LOOP:
        asyncio.run(run_once())
    else:
        asyncio.run(_loop())
```

### Configuration

```python
@academia_bobodo_backend/whiteboard_render_worker.py:29-36
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")
WHITEBOARD_BUCKET = "whiteboard-renders"
WHITEBOARD_TABLE = "whiteboard_renders"
WORKER_LOOP = (os.getenv("WORKER_LOOP") or "").strip().lower() in {"1", "true", "yes"}
WORKER_INTERVAL_SECONDS = float((os.getenv("WORKER_INTERVAL_SECONDS") or "2").strip() or "2")
WORKER_MAX_JOBS = int((os.getenv("WORKER_MAX_JOBS") or "1").strip() or "1")
```

---

## 2. RPC CONSOMMÉE: `whiteboard_fetch_queued_jobs`

### Fichier

`academia_bobodo_backend/whiteboard_render_worker.py:65-71`

### Code

```python
async def _fetch_queued_jobs(limit: int = 5) -> List[Dict[str, Any]]:
    rpc_url = f"{SUPABASE_URL.rstrip('/')}/rest/v1/rpc/whiteboard_fetch_queued_jobs"
    async with httpx.AsyncClient(timeout=SUPABASE_HTTP_TIMEOUT) as client:
        resp = await client.post(rpc_url, headers=_supabase_headers(), json={"p_limit": limit})
    resp.raise_for_status()
    return resp.json()
```

### SQL de la RPC

`change_20260623_whiteboard_worker_rpcs.sql:6-24`

```sql
CREATE OR REPLACE FUNCTION public.whiteboard_fetch_queued_jobs(p_limit integer DEFAULT 5)
RETURNS TABLE (
    id uuid,
    storyboard jsonb,
    created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT wr.id, wp.storyboard_json as storyboard, wr.created_at
    FROM app.whiteboard_renders wr
    JOIN app.whiteboard_projects wp ON wr.project_id = wp.id
    WHERE wr.status = 'queued'
    ORDER BY wr.created_at ASC
    LIMIT p_limit;
END;
$$;
```

---

## 3. RPC APPELÉES: `whiteboard_mark_processing`, `whiteboard_mark_done`, `whiteboard_mark_failed`

### 3.1 `whiteboard_mark_processing`

**Fichier**: `whiteboard_render_worker.py:74-80`

```python
async def _mark_job_processing(job_id: str) -> None:
    rpc_url = f"{SUPABASE_URL.rstrip('/')}/rest/v1/rpc/whiteboard_mark_processing"
    async with httpx.AsyncClient(timeout=SUPABASE_HTTP_TIMEOUT) as client:
        resp = await client.post(rpc_url, headers=_supabase_headers(), json={"p_job_id": job_id})
    resp.raise_for_status()
```

**SQL**: `change_20260623_whiteboard_worker_rpcs.sql:27-38`

```sql
CREATE OR REPLACE FUNCTION public.whiteboard_mark_processing(p_job_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE app.whiteboard_renders
    SET status = 'processing',
        started_at = now()
    WHERE id = p_job_id;
END;
$$;
```

### 3.2 `whiteboard_mark_done`

**Fichier**: `whiteboard_render_worker.py:82-92`

```python
async def _mark_job_done(job_id: str, video_url: str, duration_ms: int) -> None:
    rpc_url = f"{SUPABASE_URL.rstrip('/')}/rest/v1/rpc/whiteboard_mark_done"
    async with httpx.AsyncClient(timeout=SUPABASE_HTTP_TIMEOUT) as client:
        resp = await client.post(rpc_url, headers=_supabase_headers(), json={
            "p_job_id": job_id,
            "p_video_url": video_url,
            "p_duration_ms": duration_ms
        })
    resp.raise_for_status()
```

**SQL**: `change_20260623_whiteboard_worker_rpcs.sql:41-54`

```sql
CREATE OR REPLACE FUNCTION public.whiteboard_mark_done(p_job_id uuid, p_video_url text, p_duration_ms integer)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE app.whiteboard_renders
    SET status = 'done',
        video_url = p_video_url,
        duration_ms = p_duration_ms,
        completed_at = now()
    WHERE id = p_job_id;
END;
$$;
```

### 3.3 `whiteboard_mark_failed`

**Fichier**: `whiteboard_render_worker.py:94-102`

```python
async def _mark_job_failed(job_id: str, error_message: str) -> None:
    rpc_url = f"{SUPABASE_URL.rstrip('/')}/rest/v1/rpc/whiteboard_mark_failed"
    async with httpx.AsyncClient(timeout=SUPABASE_HTTP_TIMEOUT) as client:
        resp = await client.post(rpc_url, headers=_supabase_headers(), json={
            "p_job_id": job_id,
            "p_error_message": error_message
        })
    resp.raise_for_status()
```

**SQL**: `change_20260623_whiteboard_worker_rpcs.sql:57-69`

```sql
CREATE OR REPLACE FUNCTION public.whiteboard_mark_failed(p_job_id uuid, p_error_message text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE app.whiteboard_renders
    SET status = 'failed',
        error_message = p_error_message,
        completed_at = now()
    WHERE id = p_job_id;
END;
$$;
```

---

## 4. BUCKET RECEVANT LES MP4

### Nom du bucket

`whiteboard-renders`

### Preuve

```python
@academia_bobodo_backend/whiteboard_render_worker.py:31
WHITEBOARD_BUCKET = "whiteboard-renders"
```

```python
@academia_bobodo_backend/whiteboard_upload_renderer.py:20
WHITEBOARD_BUCKET = "whiteboard-renders"
```

### Object key

```python
@academia_bobodo_backend/whiteboard_upload_renderer.py:55
object_key = f"renders/{render_id}/{uuid.uuid4().hex}.mp4"
```

---

## 5. URL RENVOYÉE À FLUTTER

### Construction de l'URL

```python
@academia_bobodo_backend/whiteboard_upload_renderer.py:74
public_url = f"{SUPABASE_URL}/storage/v1/object/public/{WHITEBOARD_BUCKET}/{object_key}"
```

### Exemple

```
https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/whiteboard-renders/renders/<render_id>/<uuid>.mp4
```

### Utilisation dans Flutter

```dart
@academia_app/lib/features/challenge/smart_whiteboard/providers/smart_whiteboard_provider.dart:484
_renderVideoUrl = render['video_url'] as String?;
```

---

## 6. LIEN AVEC KAMATERA

### Question

Le worker Smart Whiteboard appelle-t-il directement Kamatera ?

### Réponse

**Non**. Le worker `whiteboard_render_worker.py` ne contient aucune URL Kamatera. Il:
1. Génère des PNGs localement (`whiteboard_png_renderer.py`)
2. Assemble les PNGs en MP4 localement (`whiteboard_ffmpeg_assembler.py`)
3. Upload le MP4 vers Supabase Storage (`whiteboard_upload_renderer.py`)

### Conclusion

- Le worker Smart Whiteboard n'utilise pas Kamatera.
- Kamatera est utilisé par d'autres Edge Functions (`compress-video`, `transcode-multi-resolution`) mais pas par le pipeline Smart Whiteboard.
