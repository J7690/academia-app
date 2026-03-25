// Supabase Edge Function: td-ingest-document
// Pipeline: PDF (cours/sujets universitaires BF) → text extraction → chunking → embeddings → td_doc_chunks
// SEPARATE from prep-ingest-document (which targets prep_doc_chunks for concours)

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const EMBEDDING_MODEL = 'openai/text-embedding-3-small';
const CHUNK_MAX_CHARS = 1500;

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), { status, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } });
}

function escapeSql(text: string): string {
  return `$txt$${text.replace(/\$txt\$/g, '$$txt$$')}$txt$`;
}

async function extractTextFromPdf(pdfUrl: string): Promise<{ text: string; pageCount: number }> {
  const resp = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${OPENROUTER_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: 'google/gemini-2.0-flash-001',
      messages: [{
        role: 'user',
        content: [
          { type: 'file', file: { filename: 'document.pdf', url: pdfUrl } },
          { type: 'text', text: `Extrais TOUT le texte de ce document PDF universitaire. Retourne le texte brut sans formatage markdown. Conserve la structure (titres, sections, questions numérotées, formules). Retourne UNIQUEMENT le texte extrait.` },
        ],
      }],
      temperature: 0, max_tokens: 16000,
    }),
  });
  if (!resp.ok) throw new Error(`PDF extraction failed: ${resp.status}`);
  const data = await resp.json();
  const text = data?.choices?.[0]?.message?.content?.trim() ?? '';
  return { text, pageCount: Math.max(1, Math.ceil(text.length / 3000)) };
}

function chunkText(fullText: string, metadata: { subject?: string; university?: string; study_year?: string }): Array<{ content: string; chunk_type: string; subject?: string; university?: string; study_year?: string }> {
  const chunks: Array<{ content: string; chunk_type: string }> = [];
  const paragraphs = fullText.split(/\n{2,}/);
  let current = '';
  for (const para of paragraphs) {
    const trimmed = para.trim();
    if (!trimmed) continue;
    if (current.length + trimmed.length + 2 > CHUNK_MAX_CHARS) {
      if (current.length > 30) chunks.push({ content: current.trim(), chunk_type: 'content' });
      current = trimmed;
    } else {
      current += (current ? '\n\n' : '') + trimmed;
    }
  }
  if (current.length > 30) chunks.push({ content: current.trim(), chunk_type: 'content' });
  return chunks.map(c => ({ ...c, ...metadata }));
}

async function generateEmbeddings(texts: string[]): Promise<number[][]> {
  if (!texts.length) return [];
  const resp = await fetch('https://openrouter.ai/api/v1/embeddings', {
    method: 'POST',
    headers: { Authorization: `Bearer ${OPENROUTER_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: EMBEDDING_MODEL, input: texts }),
  });
  if (!resp.ok) throw new Error(`Embeddings failed: ${resp.status}`);
  const data = await resp.json();
  return (data?.data ?? []).sort((a: any, b: any) => a.index - b.index).map((item: any) => item.embedding ?? []);
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS_HEADERS });
  if (req.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405);

  try {
    const authHeader = req.headers.get('authorization') ?? '';
    const jwt = authHeader.replace(/^Bearer\s+/i, '').trim();
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    const { data: userData } = await createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false }, global: { headers: { Authorization: `Bearer ${jwt}` } },
    }).auth.getUser(jwt);
    if (!userData?.user) return jsonResponse({ error: 'not_authenticated' }, 401);

    const body = await req.json();
    const documentId = (body.document_id ?? '').toString().trim();
    if (!documentId) return jsonResponse({ error: 'document_id required' }, 400);

    // Get document from td_source_documents (SEPARATE table)
    const { data: docData } = await supabase.rpc('admin_execute_sql', {
      p_sql: `SELECT * FROM app.td_source_documents WHERE id = '${documentId}' LIMIT 1`,
    });
    const dd = docData as Record<string, unknown> | null;
    if (!dd?.ok || !Array.isArray(dd.rows) || !dd.rows.length) return jsonResponse({ error: 'document_not_found' }, 404);

    const doc = dd.rows[0] as Record<string, unknown>;
    const bucket = (doc.storage_bucket || 'prep-documents') as string;
    const path = (doc.storage_path || '') as string;
    if (!path) return jsonResponse({ error: 'no_storage_path' }, 400);

    // Signed URL
    const { data: signedData, error: signedError } = await supabase.storage.from(bucket).createSignedUrl(path, 3600);
    if (signedError || !signedData?.signedUrl) return jsonResponse({ error: 'storage_url_failed' }, 500);

    // Update status
    await supabase.rpc('admin_execute_sql', { p_sql: `UPDATE app.td_source_documents SET status = 'extracting', updated_at = now() WHERE id = '${documentId}'` });

    // Extract text
    const { text, pageCount } = await extractTextFromPdf(signedData.signedUrl);
    if (!text || text.length < 50) {
      await supabase.rpc('admin_execute_sql', { p_sql: `UPDATE app.td_source_documents SET status = 'error', updated_at = now() WHERE id = '${documentId}'` });
      return jsonResponse({ error: 'extraction_empty' }, 500);
    }

    // Save extracted text
    await supabase.rpc('admin_execute_sql', { p_sql: `UPDATE app.td_source_documents SET extracted_text = ${escapeSql(text.slice(0, 100000))}, updated_at = now() WHERE id = '${documentId}'` });

    // Chunk
    const chunks = chunkText(text, {
      subject: (doc.subject as string) ?? undefined,
      university: (doc.university as string) ?? undefined,
      study_year: (doc.study_year as string) ?? undefined,
    });
    if (!chunks.length) {
      await supabase.rpc('admin_execute_sql', { p_sql: `UPDATE app.td_source_documents SET status = 'error', updated_at = now() WHERE id = '${documentId}'` });
      return jsonResponse({ error: 'no_chunks' }, 500);
    }

    // Embeddings (batch 20)
    const allEmbeddings: number[][] = [];
    for (let i = 0; i < chunks.length; i += 20) {
      const batch = chunks.slice(i, i + 20).map(c => c.content);
      allEmbeddings.push(...await generateEmbeddings(batch));
    }

    // Delete old chunks + insert new into td_doc_chunks (SEPARATE)
    await supabase.rpc('admin_execute_sql', { p_sql: `DELETE FROM app.td_doc_chunks WHERE source_document_id = '${documentId}'` });

    let insertedCount = 0;
    for (let i = 0; i < chunks.length; i++) {
      const chunk = chunks[i];
      const emb = i < allEmbeddings.length ? allEmbeddings[i] : null;
      const embStr = emb ? `'[${emb.join(',')}]'` : 'NULL';
      const insertSql = `INSERT INTO app.td_doc_chunks (source_document_id, chunk_index, content, metadata, embedding, chunk_type, subject, university, study_year, token_count) VALUES ('${documentId}', ${i}, ${escapeSql(chunk.content)}, '{"source":"pdf"}'::jsonb, ${embStr}::vector, '${chunk.chunk_type}', ${chunk.subject ? `'${chunk.subject.replace(/'/g, "''")}'` : 'NULL'}, ${chunk.university ? `'${chunk.university.replace(/'/g, "''")}'` : 'NULL'}, ${chunk.study_year ? `'${chunk.study_year.replace(/'/g, "''")}'` : 'NULL'}, ${Math.ceil(chunk.content.length / 4)})`;
      try {
        await supabase.rpc('admin_execute_sql', { p_sql: insertSql.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim() });
        insertedCount++;
      } catch {}
    }

    // Update status to indexed
    await supabase.rpc('admin_execute_sql', { p_sql: `UPDATE app.td_source_documents SET status = 'indexed', page_count = ${pageCount}, updated_at = now() WHERE id = '${documentId}'` });

    return jsonResponse({ success: true, document_id: documentId, extracted_length: text.length, page_count: pageCount, chunks_count: chunks.length, inserted_count: insertedCount });
  } catch (err: any) {
    console.error('td-ingest-document error:', err);
    return jsonResponse({ error: 'internal_error', message: err?.message?.slice(0, 500) }, 500);
  }
});
