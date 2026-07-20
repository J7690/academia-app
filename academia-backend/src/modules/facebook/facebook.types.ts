/** Types de données retournés par le module Facebook (sous-ensemble utile). */

export interface FacebookPost {
  id: string;
  message?: string;
  created_time?: string;
  permalink_url?: string;
  full_picture?: string;
}

export interface FacebookComment {
  id: string;
  message?: string;
  created_time?: string;
  from?: { id: string; name?: string };
  like_count?: number;
}

export interface MessengerParticipant {
  id: string;
  name?: string;
  email?: string;
}

export interface MessengerMessage {
  id: string;
  message?: string;
  created_time?: string;
  from?: MessengerParticipant;
}

export interface MessengerConversation {
  id: string;
  snippet?: string;
  updated_time?: string;
  participants?: MessengerParticipant[];
}

export interface InsightMetric {
  name: string;
  period?: string;
  values: Array<{ value: unknown; end_time?: string }>;
  title?: string;
  description?: string;
}

export interface PublishResult {
  id: string;
  post_id?: string;
}
