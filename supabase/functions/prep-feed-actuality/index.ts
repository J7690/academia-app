// Supabase Edge Function: prep-feed-actuality
// Scrapes RSS feeds from Burkina Faso state media (Lefaso.net, Sidwaya, RTB)
// Injects articles as prep_doc_chunks for RAG consumption by the AI.
// 0 token consumed — pure fetch + SQL insertion.
// Designed to be called by a cron job (daily) or manually by admin.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
import { DOMParser } from 'https://deno.land/x/deno_dom@v0.1.47/deno-dom-wasm.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization,apikey,content-type,accept',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
};

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

// ─── RSS Parser ────────────────────────────────────────────────────────
type RssArticle = {
  title: string;
  link: string;
  description: string;
  content: string;
  pubDate: string | null;
  categories: string[];
};

function parseRss(xmlText: string): RssArticle[] {
  const articles: RssArticle[] = [];

  try {
    const doc = new DOMParser().parseFromString(xmlText, 'text/html');
    if (!doc) return articles;

    // Manual XML parsing since DOMParser may not handle RSS well
    // Use regex-based extraction for reliability
    const itemRegex = /<item[^>]*>([\s\S]*?)<\/item>/gi;
    let match;

    while ((match = itemRegex.exec(xmlText)) !== null) {
      const itemXml = match[1];

      const title = extractTag(itemXml, 'title');
      const link = extractTag(itemXml, 'link') || extractTag(itemXml, 'guid');
      const description = stripHtml(extractTag(itemXml, 'description'));
      const contentEncoded = stripHtml(
        extractTag(itemXml, 'content:encoded') || extractTag(itemXml, 'content')
      );
      const pubDate = extractTag(itemXml, 'pubDate') || extractTag(itemXml, 'dc:date');

      // Extract categories
      const categories: string[] = [];
      const catRegex = /<category[^>]*>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?<\/category>/gi;
      let catMatch;
      while ((catMatch = catRegex.exec(itemXml)) !== null) {
        const cat = catMatch[1].trim();
        if (cat) categories.push(cat);
      }

      if (title && link) {
        articles.push({
          title: stripCdata(title).trim(),
          link: stripCdata(link).trim(),
          description: description.slice(0, 2000),
          content: (contentEncoded || description).slice(0, 8000),
          pubDate,
          categories,
        });
      }
    }
  } catch (e) {
    console.error('RSS parse error:', e);
  }

  return articles;
}

function extractTag(xml: string, tag: string): string {
  // Handle CDATA sections
  const regex = new RegExp(
    `<${tag}[^>]*>(?:<!\\[CDATA\\[)?([\\s\\S]*?)(?:\\]\\]>)?<\\/${tag}>`,
    'i'
  );
  const m = xml.match(regex);
  return m ? m[1].trim() : '';
}

function stripCdata(text: string): string {
  return text.replace(/<!\[CDATA\[/g, '').replace(/\]\]>/g, '').trim();
}

function stripHtml(html: string): string {
  if (!html) return '';
  return html
    .replace(/<[^>]*>/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#039;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/&#8230;/g, '…')
    .replace(/&#233;/g, 'é')
    .replace(/&#224;/g, 'à')
    .replace(/&#232;/g, 'è')
    .replace(/&#234;/g, 'ê')
    .replace(/&#226;/g, 'â')
    .replace(/&#244;/g, 'ô')
    .replace(/&#251;/g, 'û')
    .replace(/&#239;/g, 'ï')
    .replace(/&#231;/g, 'ç')
    .replace(/&#160;/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

// ─── Category filter ───────────────────────────────────────────────────
// Relevant categories for concours preparation
const RELEVANT_CATEGORIES = new Set([
  'politique', 'economie', 'économie', 'société', 'societe',
  'education', 'éducation', 'sante', 'santé', 'droit', 'justice',
  'actualites', 'actualités', 'flash', 'la une site', 'la une',
  'infos', 'info', 'burkina faso', 'international',
  'agriculture', 'environnement', 'culture', 'sport',
  'sécurité', 'securite', 'défense', 'defense',
]);

function isRelevantArticle(
  article: RssArticle,
  sourceCategories: string[],
): boolean {
  // If source has no category filter, accept all
  if (!sourceCategories || sourceCategories.length === 0) return true;

  // If article has no categories, accept it (better to include than exclude)
  if (!article.categories || article.categories.length === 0) return true;

  // Check if any article category matches relevant categories
  for (const cat of article.categories) {
    if (RELEVANT_CATEGORIES.has(cat.toLowerCase().trim())) {
      return true;
    }
  }

  // Also check source-defined categories
  for (const cat of article.categories) {
    for (const srcCat of sourceCategories) {
      if (cat.toLowerCase().includes(srcCat.toLowerCase()) ||
          srcCat.toLowerCase().includes(cat.toLowerCase())) {
        return true;
      }
    }
  }

  return false;
}

// ─── Main handler ──────────────────────────────────────────────────────
serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  try {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return jsonResponse({ error: 'Supabase non configuré' }, 500);
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    // Resolve subject_id for "Actualités du Burkina Faso"
    const { data: subjectData } = await supabase.rpc('admin_execute_sql', {
      p_sql: `SELECT id FROM app.prep_subjects WHERE slug = 'actualites_bf' OR LOWER(title) LIKE '%actualit%burkina%' LIMIT 1`,
    });
    const subjectId = (subjectData as any)?.rows?.[0]?.id ?? null;

    // Get active sources
    const { data: sourcesData } = await supabase.rpc('admin_execute_sql', {
      p_sql: `SELECT id, slug, name, feed_url, categories_filter FROM app.prep_news_sources WHERE is_active = true ORDER BY name`,
    });

    const sources = (sourcesData as any)?.rows ?? [];
    if (sources.length === 0) {
      return jsonResponse({ success: true, message: 'Aucune source active', fetched: 0, injected: 0 });
    }

    let totalFetched = 0;
    let totalInjected = 0;
    let totalSkipped = 0;
    const sourceResults: Array<{ source: string; fetched: number; injected: number; skipped: number; error?: string }> = [];

    for (const source of sources) {
      let fetched = 0;
      let injected = 0;
      let skipped = 0;

      try {
        // Fetch RSS feed
        const feedResp = await fetch(source.feed_url, {
          headers: { 'User-Agent': 'Academia-BF/1.0 (Prep Concours Feed Reader)' },
        });

        if (!feedResp.ok) {
          sourceResults.push({ source: source.slug, fetched: 0, injected: 0, skipped: 0, error: `HTTP ${feedResp.status}` });
          continue;
        }

        const xmlText = await feedResp.text();
        const articles = parseRss(xmlText);
        fetched = articles.length;

        const catFilter = source.categories_filter ?? [];

        for (const article of articles) {
          // Skip irrelevant articles
          if (!isRelevantArticle(article, catFilter)) {
            skipped++;
            continue;
          }

          // Skip if content too short
          const content = article.content || article.description;
          if (!content || content.length < 50) {
            skipped++;
            continue;
          }

          // Check if already exists (dedup by URL)
          const escapedUrl = article.link.replace(/'/g, "''");
          const { data: existsData } = await supabase.rpc('admin_execute_sql', {
            p_sql: `SELECT 1 FROM app.prep_news_articles WHERE article_url = '${escapedUrl}' LIMIT 1`,
          });
          const exists = ((existsData as any)?.rows?.length ?? 0) > 0;
          if (exists) {
            skipped++;
            continue;
          }

          // Parse publication date
          let pubDateStr = 'NULL';
          if (article.pubDate) {
            try {
              const d = new Date(article.pubDate);
              if (!isNaN(d.getTime())) {
                pubDateStr = `'${d.toISOString()}'`;
              }
            } catch { /* ignore */ }
          }

          // Escape content for SQL
          const esc = (s: string) => `$txt$${s.replace(/\$txt\$/g, '$$txt$$')}$txt$`;

          // Generate UUID first (admin_execute_sql doesn't return RETURNING rows)
          const { data: uuidData } = await supabase.rpc('admin_execute_sql', {
            p_sql: `SELECT gen_random_uuid() AS id`,
          });
          const docId = (uuidData as any)?.rows?.[0]?.id;
          if (!docId) {
            console.error(`Failed to generate UUID for: ${article.title.slice(0, 50)}`);
            continue;
          }

          // Create a source document for this article
          const docSql = `
            INSERT INTO app.prep_source_documents (
              id, subject_id, doc_type, source_type, extracted_text,
              concours_type, subject_name, status, original_filename
            ) VALUES (
              '${docId}',
              ${subjectId ? `'${subjectId}'` : 'NULL'},
              'actualite',
              'rss_feed',
              ${esc(content.slice(0, 50000))},
              'TOUS',
              'Actualités du Burkina Faso',
              'indexed',
              ${esc(article.title.slice(0, 200))}
            )
          `.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();

          const { data: docResult } = await supabase.rpc('admin_execute_sql', { p_sql: docSql });
          if (!(docResult as any)?.ok) {
            console.error(`Failed to insert doc for: ${article.title.slice(0, 50)}`, (docResult as any)?.error);
            continue;
          }

          // Create chunk (no source attribution — discret)
          const chunkContent = `${article.title}\n\n${content}`;
          const chunkSql = `
            INSERT INTO app.prep_doc_chunks (
              source_document_id, chunk_index, content,
              chunk_type, concours_type, subject_name,
              token_count, metadata
            ) VALUES (
              '${docId}', 0,
              ${esc(chunkContent.slice(0, 4000))},
              'actualite', 'TOUS', 'Actualités du Burkina Faso',
              ${Math.ceil(chunkContent.length / 4)},
              '${JSON.stringify({
                source: source.slug,
                url: article.link,
                published_at: article.pubDate,
                categories: article.categories,
              }).replace(/'/g, "''")}'::jsonb
            )
          `.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();

          await supabase.rpc('admin_execute_sql', { p_sql: chunkSql });

          // Track article
          const articleSql = `
            INSERT INTO app.prep_news_articles (
              source_id, article_url, title, summary, content,
              categories, published_at, is_injected, injected_at,
              source_document_id, content_length
            ) VALUES (
              '${source.id}',
              ${esc(article.link)},
              ${esc(article.title)},
              ${esc((article.description || '').slice(0, 500))},
              ${esc(content.slice(0, 10000))},
              ARRAY[${article.categories.map(c => `'${c.replace(/'/g, "''")}'`).join(',')}]::text[],
              ${pubDateStr},
              true, now(),
              '${docId}',
              ${content.length}
            ) ON CONFLICT (article_url) DO NOTHING
          `.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();

          await supabase.rpc('admin_execute_sql', { p_sql: articleSql });
          injected++;

          // ─── Score article relevance for concours ───────────────
          try {
            const catArray = article.categories.map(c => `'${c.replace(/'/g, "''")}'`).join(',');
            const scoreSql = `
              SELECT public.app_prep_score_article_relevance(
                ${esc(article.title)},
                ${esc(content.slice(0, 5000))},
                ARRAY[${catArray}]::text[]
              ) AS result
            `.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();

            const { data: scoreData } = await supabase.rpc('admin_execute_sql', { p_sql: scoreSql });
            const scoreRow = (scoreData as any)?.rows?.[0];
            if (scoreRow?.result) {
              const scoreResult = typeof scoreRow.result === 'string' ? JSON.parse(scoreRow.result) : scoreRow.result;
              const relevanceScore = scoreResult.score ?? 0;
              const isRelevant = scoreResult.is_relevant ?? false;
              const matchedSubjects = scoreResult.matched_subjects ?? [];
              const matchedKeywords = scoreResult.matched_keywords ?? [];
              const reason = scoreResult.reason ?? '';

              // Update article with score
              const updateScoreSql = `
                UPDATE app.prep_news_articles SET
                  relevance_score = ${relevanceScore},
                  is_concours_relevant = ${isRelevant},
                  scoring_reason = ${esc(reason.slice(0, 500))},
                  matched_subjects = ARRAY[${matchedSubjects.map((s: string) => `'${s.replace(/'/g, "''")}'`).join(',')}]::text[],
                  matched_keywords = ARRAY[${matchedKeywords.slice(0, 10).map((k: string) => `'${k.replace(/'/g, "''")}'`).join(',')}]::text[],
                  scored_at = now()
                WHERE article_url = ${esc(article.link)}
              `.replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();
              await supabase.rpc('admin_execute_sql', { p_sql: updateScoreSql });

              // If relevant, get article ID and notify opted-in students
              if (isRelevant && relevanceScore >= 0.4) {
                const { data: artIdData } = await supabase.rpc('admin_execute_sql', {
                  p_sql: `SELECT id FROM app.prep_news_articles WHERE article_url = ${esc(article.link)} LIMIT 1`,
                });
                const articleId = (artIdData as any)?.rows?.[0]?.id;
                if (articleId) {
                  const subjectsArr = matchedSubjects.map((s: string) => `'${s.replace(/'/g, "''")}'`).join(',');
                  await supabase.rpc('admin_execute_sql', {
                    p_sql: `SELECT public.app_prep_notify_relevant_article('${articleId}', ${esc(article.title.slice(0, 150))}, ${relevanceScore}, ARRAY[${subjectsArr}]::text[])`,
                  });
                }
              }
            }
          } catch (scoreErr) {
            console.error('Scoring error (non-blocking):', scoreErr);
          }
        }

        // Update source last_fetched_at and count
        await supabase.rpc('admin_execute_sql', {
          p_sql: `UPDATE app.prep_news_sources SET last_fetched_at = now(), articles_count = (SELECT count(*) FROM app.prep_news_articles WHERE source_id = '${source.id}'), updated_at = now() WHERE id = '${source.id}'`,
        });

      } catch (srcErr: any) {
        sourceResults.push({ source: source.slug, fetched, injected, skipped, error: srcErr?.message?.slice(0, 200) });
        continue;
      }

      totalFetched += fetched;
      totalInjected += injected;
      totalSkipped += skipped;
      sourceResults.push({ source: source.slug, fetched, injected, skipped });
    }

    // Count how many articles were scored as relevant
    let totalRelevant = 0;
    try {
      const { data: relData } = await supabase.rpc('admin_execute_sql', {
        p_sql: `SELECT count(*)::int AS n FROM app.prep_news_articles WHERE is_concours_relevant = true`,
      });
      totalRelevant = (relData as any)?.rows?.[0]?.n ?? 0;
    } catch { /* ignore */ }

    return jsonResponse({
      success: true,
      total_fetched: totalFetched,
      total_injected: totalInjected,
      total_skipped: totalSkipped,
      total_relevant: totalRelevant,
      sources: sourceResults,
    });
  } catch (err: any) {
    console.error('prep-feed-actuality error:', err);
    return jsonResponse(
      { error: 'internal_error', message: err?.message?.slice(0, 500) ?? 'unknown' },
      500,
    );
  }
});
