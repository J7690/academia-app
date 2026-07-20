// =============================================================================
// facebook.ts — Logique Meta Graph API pour Academia (Deno / Edge Functions).
// Sans dépendance externe : fetch natif. Partagé par facebook-connector et
// academia-mcp. Toute la logique métier Facebook vit ici, et nulle part ailleurs.
// =============================================================================

export interface FacebookConfig {
  graphVersion: string;
  pageId: string;
  token: string;
  verifyToken: string;
  baseUrl: string;
}

export function getFacebookConfig(): FacebookConfig {
  const graphVersion = Deno.env.get("FACEBOOK_GRAPH_VERSION") ?? "v20.0";
  const pageId = Deno.env.get("FACEBOOK_PAGE_ID") ?? "";
  const token = Deno.env.get("FACEBOOK_PAGE_ACCESS_TOKEN") ?? "";
  const missing: string[] = [];
  if (!pageId) missing.push("FACEBOOK_PAGE_ID");
  if (!token) missing.push("FACEBOOK_PAGE_ACCESS_TOKEN");
  if (missing.length) {
    throw new Error(`Configuration Facebook incomplète: ${missing.join(", ")}`);
  }
  return {
    graphVersion,
    pageId,
    token,
    verifyToken: Deno.env.get("FACEBOOK_VERIFY_TOKEN") ?? "",
    baseUrl: `https://graph.facebook.com/${graphVersion}`,
  };
}

async function graph<T = unknown>(
  path: string,
  init: { method?: string; params?: Record<string, string>; body?: unknown } = {},
): Promise<T> {
  const cfg = getFacebookConfig();
  const url = new URL(`${cfg.baseUrl}/${path}`);
  url.searchParams.set("access_token", cfg.token);
  for (const [k, v] of Object.entries(init.params ?? {})) url.searchParams.set(k, v);

  const res = await fetch(url.toString(), {
    method: init.method ?? "GET",
    headers: init.body ? { "Content-Type": "application/json" } : undefined,
    body: init.body ? JSON.stringify(init.body) : undefined,
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = json?.error?.message ?? `Graph API error ${res.status}`;
    throw new Error(`[Facebook] ${msg}`);
  }
  return json as T;
}

export const facebook = {
  publishPost(p: { message: string; link?: string; published?: boolean }) {
    const params: Record<string, string> = { message: p.message };
    if (p.link) params.link = p.link;
    if (p.published === false) params.published = "false";
    return graph(`${getFacebookConfig().pageId}/feed`, { method: "POST", params });
  },

  deletePost(postId: string) {
    return graph(`${postId}`, { method: "DELETE" });
  },

  listPosts(limit = 25) {
    return graph(`${getFacebookConfig().pageId}/posts`, {
      params: { fields: "id,message,created_time,permalink_url,full_picture", limit: String(limit) },
    });
  },

  publishPhoto(p: { imageUrl: string; caption?: string }) {
    const params: Record<string, string> = { url: p.imageUrl };
    if (p.caption) params.caption = p.caption;
    return graph(`${getFacebookConfig().pageId}/photos`, { method: "POST", params });
  },

  publishVideo(p: { videoUrl: string; title?: string; description?: string }) {
    const params: Record<string, string> = { file_url: p.videoUrl };
    if (p.title) params.title = p.title;
    if (p.description) params.description = p.description;
    return graph(`${getFacebookConfig().pageId}/videos`, { method: "POST", params });
  },

  getComments(objectId: string, limit = 50) {
    return graph(`${objectId}/comments`, {
      params: { fields: "id,message,created_time,from,like_count", limit: String(limit) },
    });
  },

  replyComment(p: { commentId: string; message: string }) {
    return graph(`${p.commentId}/comments`, { method: "POST", params: { message: p.message } });
  },

  listConversations(limit = 25) {
    return graph(`${getFacebookConfig().pageId}/conversations`, {
      params: { fields: "id,snippet,updated_time,participants", limit: String(limit) },
    });
  },

  getMessages(conversationId: string, limit = 50) {
    return graph(`${conversationId}`, {
      params: { fields: `messages.limit(${limit}){id,message,created_time,from}` },
    });
  },

  sendMessage(p: { recipientId: string; message: string }) {
    return graph(`${getFacebookConfig().pageId}/messages`, {
      method: "POST",
      body: {
        recipient: { id: p.recipientId },
        messaging_type: "RESPONSE",
        message: { text: p.message },
      },
    });
  },

  getPageInsights(p: { metrics: string[]; period?: string }) {
    return graph(`${getFacebookConfig().pageId}/insights`, {
      params: { metric: p.metrics.join(","), period: p.period ?? "week" },
    });
  },

  getEvents(limit = 25) {
    return graph(`${getFacebookConfig().pageId}/events`, {
      params: { fields: "id,name,description,start_time,end_time,place", limit: String(limit) },
    });
  },
};

export type FacebookApi = typeof facebook;
