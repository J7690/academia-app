// Supabase Edge Function: prep-ingest-document
// Pipeline: PDF → text extraction (OpenRouter) → chunking → embeddings → pgvector
// Triggered by admin after uploading a PDF to prep-documents bucket.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

const EMBEDDING_MODEL = 'openai/text-embedding-3-small';
const CHUNK_MAX_CHARS = 1500;

// ─── Helpers ──────────────────────────────────────────────────────────

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

async function extractTextFromPdf(
  pdfUrl: string,
): Promise<{ text: string; pageCount: number }> {
  // Use OpenRouter's pdf-text engine (FREE) via a multimodal model
  // We send the PDF URL and ask the model to extract all text
  const resp = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${OPENROUTER_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'google/gemini-2.0-flash-001',
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'file',
              file: {
                filename: 'document.pdf',
                url: pdfUrl,
              },
            },
            {
              type: 'text',
              text: `Extrais TOUT le texte de ce document PDF. Retourne le texte brut sans aucun formatage markdown, sans commentaire, sans résumé. Si c'est un QCM, conserve la numérotation des questions et les options (A, B, C, D). Si c'est un sujet d'examen, conserve les titres de sections. Retourne UNIQUEMENT le texte extrait.`,
            },
          ],
        },
      ],
      temperature: 0,
      max_tokens: 16000,
    }),
  });

  if (!resp.ok) {
    const errText = await resp.text();
    throw new Error(`OpenRouter PDF extraction failed (${resp.status}): ${errText.slice(0, 500)}`);
  }

  const data = await resp.json();
  const text = data?.choices?.[0]?.message?.content?.trim() ?? '';
  // Estimate page count from text length (~3000 chars per page)
  const pageCount = Math.max(1, Math.ceil(text.length / 3000));
  return { text, pageCount };
}

type ChunkData = {
  content: string;
  chunk_type: string;
  question_number: number | null;
  is_correction: boolean;
  concours_type?: string;
  subject_name?: string;
  year?: string;
};

function chunkText(
  fullText: string,
  metadata: { concours_type?: string; subject_name?: string; year?: string },
): ChunkData[] {
  const chunks: Array<{
    content: string;
    chunk_type: string;
    question_number: number | null;
    is_correction: boolean;
  }> = [];

  // Try to split by question numbers (1. or Q1 or Question 1 etc.)
  const questionPattern = /(?:^|\n)\s*(?:Q(?:uestion)?\s*)?(\d{1,3})\s*[.):\-–]/gm;
  const matches = [...fullText.matchAll(questionPattern)];

  if (matches.length >= 3) {
    // Document has numbered questions — chunk by question
    for (let i = 0; i < matches.length; i++) {
      const start = matches[i].index!;
      const end = i + 1 < matches.length ? matches[i + 1].index! : fullText.length;
      const questionText = fullText.slice(start, end).trim();
      if (questionText.length < 10) continue;

      const qNum = parseInt(matches[i][1], 10);
      const isCorrection =
        /corrig[eé]|correction|r[eé]ponse\s*(correcte|juste)/i.test(questionText);

      chunks.push({
        content: questionText.slice(0, CHUNK_MAX_CHARS),
        chunk_type: isCorrection ? 'correction' : 'question',
        question_number: qNum,
        is_correction: isCorrection,
      });
    }
  }

  if (chunks.length === 0) {
    // Fallback: split by paragraphs / fixed size
    const paragraphs = fullText.split(/\n{2,}/);
    let currentChunk = '';
    let chunkIdx = 0;

    for (const para of paragraphs) {
      const trimmed = para.trim();
      if (!trimmed) continue;

      if (currentChunk.length + trimmed.length + 2 > CHUNK_MAX_CHARS) {
        if (currentChunk.length > 30) {
          chunks.push({
            content: currentChunk.trim(),
            chunk_type: 'content',
            question_number: null,
            is_correction: false,
          });
          chunkIdx++;
        }
        currentChunk = trimmed;
      } else {
        currentChunk += (currentChunk ? '\n\n' : '') + trimmed;
      }
    }

    if (currentChunk.length > 30) {
      chunks.push({
        content: currentChunk.trim(),
        chunk_type: 'content',
        question_number: null,
        is_correction: false,
      });
    }
  }

  // Add metadata to each chunk
  return chunks.map((c) => ({
    ...c,
    ...metadata,
  }));
}

async function generateEmbeddings(texts: string[]): Promise<number[][]> {
  if (texts.length === 0) return [];

  const resp = await fetch('https://openrouter.ai/api/v1/embeddings', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${OPENROUTER_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: EMBEDDING_MODEL,
      input: texts,
    }),
  });

  if (!resp.ok) {
    const errText = await resp.text();
    throw new Error(`Embeddings failed (${resp.status}): ${errText.slice(0, 500)}`);
  }

  const data = await resp.json();
  const embeddings: number[][] = [];
  if (Array.isArray(data?.data)) {
    // Sort by index to ensure order
    const sorted = [...data.data].sort((a: any, b: any) => a.index - b.index);
    for (const item of sorted) {
      if (Array.isArray(item?.embedding)) {
        embeddings.push(item.embedding);
      }
    }
  }
  return embeddings;
}

// ─── Main handler ─────────────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  try {
    const authHeader = req.headers.get('authorization') ?? '';
    const jwt = authHeader.replace(/^Bearer\s+/i, '').trim();

    const supabaseService = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    // Verify the caller is authenticated
    const supabaseUser = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });

    const { data: userData, error: userError } = await supabaseUser.auth.getUser(jwt);
    if (userError || !userData?.user) {
      return jsonResponse({ error: 'not_authenticated' }, 401);
    }

    const body = await req.json();
    const documentId = (body.document_id ?? '').toString().trim();

    if (!documentId) {
      return jsonResponse({ error: 'document_id required' }, 400);
    }

    // 1. Get the source document
    const { data: docData, error: docError } = await supabaseService.rpc(
      'app_admin_prep_list_source_documents',
      { p_subject_id: null, p_status: null },
    );

    let doc: Record<string, any> | null = null;
    if (docData && typeof docData === 'object') {
      const docMap = docData as Record<string, any>;
      const docs = docMap.documents;
      if (Array.isArray(docs)) {
        doc = docs.find((d: any) => d.id === documentId) ?? null;
      }
    }

    if (!doc) {
      return jsonResponse({ error: 'document_not_found' }, 404);
    }

    const bucket = doc.storage_bucket || 'prep-documents';
    const path = doc.storage_path || '';

    if (!path) {
      return jsonResponse({ error: 'no_storage_path' }, 400);
    }

    // 2. Get a signed URL for the PDF
    const { data: signedData, error: signedError } = await supabaseService.storage
      .from(bucket)
      .createSignedUrl(path, 3600);

    if (signedError || !signedData?.signedUrl) {
      return jsonResponse(
        { error: 'storage_url_failed', detail: signedError?.message ?? 'no signed url' },
        500,
      );
    }

    const pdfUrl = signedData.signedUrl;

    // 3. Update status to 'extracting'
    await supabaseService.rpc('app_admin_prep_set_source_document_status', {
      p_document_id: documentId,
      p_status: 'extracting',
    });

    // 4. Extract text from PDF via OpenRouter
    const { text: extractedText, pageCount } = await extractTextFromPdf(pdfUrl);

    if (!extractedText || extractedText.length < 50) {
      await supabaseService.rpc('app_admin_prep_set_source_document_status', {
        p_document_id: documentId,
        p_status: 'error',
      });
      return jsonResponse({ error: 'extraction_empty', length: extractedText.length }, 500);
    }

    // 5. Save extracted text
    await supabaseService.rpc('app_admin_prep_update_source_document_text', {
      p_document_id: documentId,
      p_extracted_text: extractedText.slice(0, 100000),
    });

    // 6. Chunk the text
    const chunks = chunkText(extractedText, {
      concours_type: doc.concours_type ?? undefined,
      subject_name: doc.subject_name ?? undefined,
      year: doc.year?.toString() ?? undefined,
    });

    if (chunks.length === 0) {
      await supabaseService.rpc('app_admin_prep_set_source_document_status', {
        p_document_id: documentId,
        p_status: 'error',
      });
      return jsonResponse({ error: 'no_chunks_generated' }, 500);
    }

    // 7. Generate embeddings (batch, max 20 at a time)
    const BATCH_SIZE = 20;
    const allEmbeddings: number[][] = [];

    for (let i = 0; i < chunks.length; i += BATCH_SIZE) {
      const batch = chunks.slice(i, i + BATCH_SIZE);
      const texts = batch.map((c) => c.content);
      const embeddings = await generateEmbeddings(texts);
      allEmbeddings.push(...embeddings);
    }

    // 8. Delete existing chunks for this document (re-ingestion)
    await supabaseService.rpc('admin_execute_sql', {
      p_sql: `DELETE FROM app.prep_doc_chunks WHERE source_document_id = '${documentId}'`,
    });

    // 9. Insert chunks with embeddings
    let insertedCount = 0;
    for (let i = 0; i < chunks.length; i++) {
      const chunk = chunks[i];
      const embedding = i < allEmbeddings.length ? allEmbeddings[i] : null;
      const tokenCount = Math.ceil(chunk.content.length / 4);

      const embeddingStr = embedding ? `'[${embedding.join(',')}]'` : 'NULL';

      const insertSql = `
        INSERT INTO app.prep_doc_chunks (
          source_document_id, chunk_index, content, metadata,
          embedding, chunk_type, concours_type, subject_name, year,
          question_number, is_correction, token_count
        ) VALUES (
          '${documentId}', ${i}, 
          ${escapeSql(chunk.content)},
          '${JSON.stringify({ source: 'pdf_extraction' })}'::jsonb,
          ${embeddingStr}::vector,
          '${chunk.chunk_type}', 
          ${chunk.concours_type ? `'${chunk.concours_type}'` : 'NULL'},
          ${chunk.subject_name ? `'${chunk.subject_name}'` : 'NULL'},
          ${chunk.year ? `'${chunk.year}'` : 'NULL'},
          ${chunk.question_number ?? 'NULL'},
          ${chunk.is_correction},
          ${tokenCount}
        )
      `;

      try {
        await supabaseService.rpc('admin_execute_sql', { p_sql: insertSql.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim() });
        insertedCount++;
      } catch (e) {
        console.error(`Failed to insert chunk ${i}:`, e);
      }
    }

    // 10. Update document: status = 'indexed', page_count
    await supabaseService.rpc('admin_execute_sql', {
      p_sql: `UPDATE app.prep_source_documents SET status = 'indexed', page_count = ${pageCount}, updated_at = now() WHERE id = '${documentId}'`,
    });

    return jsonResponse({
      success: true,
      document_id: documentId,
      extracted_length: extractedText.length,
      page_count: pageCount,
      chunks_count: chunks.length,
      embeddings_count: allEmbeddings.length,
      inserted_count: insertedCount,
    });
  } catch (err: any) {
    console.error('prep-ingest-document error:', err);
    return jsonResponse(
      { error: 'internal_error', message: err?.message?.slice(0, 500) ?? 'unknown' },
      500,
    );
  }
});

function escapeSql(text: string): string {
  // Use dollar-quoting to safely handle any text content
  return `$txt$${text.replace(/\$txt\$/g, '$$txt$$')}$txt$`;
}
