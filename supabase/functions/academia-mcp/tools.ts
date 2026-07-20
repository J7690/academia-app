// =============================================================================
// tools.ts — Définition unique des 10 outils Facebook (nom, description, schéma
// JSON d'entrée, handler). Partagé par facebook-connector (REST) et academia-mcp
// (MCP HTTP) : une seule source de vérité, zéro duplication.
// =============================================================================
import { facebook } from "./facebook.ts";

export interface ToolDef {
  name: string;
  description: string;
  inputSchema: Record<string, unknown>; // JSON Schema
  handler: (args: Record<string, unknown>) => Promise<unknown>;
}

const str = (desc?: string) => ({ type: "string", ...(desc ? { description: desc } : {}) });
const int = (def?: number) => ({ type: "integer", ...(def !== undefined ? { default: def } : {}) });

export const tools: ToolDef[] = [
  {
    name: "facebook_publish_post",
    description: "Publier une publication texte (avec lien optionnel) sur la Page Facebook.",
    inputSchema: {
      type: "object",
      properties: { message: str("Texte de la publication"), link: str("URL optionnelle") },
      required: ["message"],
    },
    handler: (a) => facebook.publishPost(a as { message: string; link?: string }),
  },
  {
    name: "facebook_delete_post",
    description: "Supprimer une publication à partir de son identifiant.",
    inputSchema: { type: "object", properties: { postId: str() }, required: ["postId"] },
    handler: (a) => facebook.deletePost(String(a.postId)),
  },
  {
    name: "facebook_list_posts",
    description: "Lister les dernières publications de la Page.",
    inputSchema: { type: "object", properties: { limit: int(25) } },
    handler: (a) => facebook.listPosts(Number(a.limit ?? 25)),
  },
  {
    name: "facebook_get_comments",
    description: "Lire les commentaires d'une publication (ou les réponses d'un commentaire).",
    inputSchema: {
      type: "object",
      properties: { objectId: str("ID du post ou du commentaire"), limit: int(50) },
      required: ["objectId"],
    },
    handler: (a) => facebook.getComments(String(a.objectId), Number(a.limit ?? 50)),
  },
  {
    name: "facebook_reply_comment",
    description: "Répondre à un commentaire.",
    inputSchema: {
      type: "object",
      properties: { commentId: str(), message: str() },
      required: ["commentId", "message"],
    },
    handler: (a) => facebook.replyComment(a as { commentId: string; message: string }),
  },
  {
    name: "facebook_get_messages",
    description: "Lire l'historique des messages d'une conversation Messenger.",
    inputSchema: {
      type: "object",
      properties: { conversationId: str(), limit: int(50) },
      required: ["conversationId"],
    },
    handler: (a) => facebook.getMessages(String(a.conversationId), Number(a.limit ?? 50)),
  },
  {
    name: "facebook_send_message",
    description: "Envoyer un message Messenger à un utilisateur (PSID).",
    inputSchema: {
      type: "object",
      properties: { recipientId: str("PSID du destinataire"), message: str() },
      required: ["recipientId", "message"],
    },
    handler: (a) => facebook.sendMessage(a as { recipientId: string; message: string }),
  },
  {
    name: "facebook_get_page_insights",
    description: "Récupérer les statistiques (insights) de la Page pour une période.",
    inputSchema: {
      type: "object",
      properties: {
        metrics: { type: "array", items: { type: "string" }, default: ["page_impressions", "page_engaged_users"] },
        period: { type: "string", enum: ["day", "week", "days_28"], default: "week" },
      },
    },
    handler: (a) =>
      facebook.getPageInsights({
        metrics: (a.metrics as string[]) ?? ["page_impressions", "page_engaged_users"],
        period: (a.period as string) ?? "week",
      }),
  },
  {
    name: "facebook_publish_photo",
    description: "Publier une image sur la Page à partir d'une URL.",
    inputSchema: {
      type: "object",
      properties: { imageUrl: str("URL de l'image"), caption: str() },
      required: ["imageUrl"],
    },
    handler: (a) => facebook.publishPhoto(a as { imageUrl: string; caption?: string }),
  },
  {
    name: "facebook_publish_video",
    description: "Publier une vidéo sur la Page à partir d'une URL.",
    inputSchema: {
      type: "object",
      properties: { videoUrl: str("URL de la vidéo"), title: str(), description: str() },
      required: ["videoUrl"],
    },
    handler: (a) => facebook.publishVideo(a as { videoUrl: string; title?: string; description?: string }),
  },
];

export const toolMap: Record<string, ToolDef> = Object.fromEntries(tools.map((t) => [t.name, t]));
