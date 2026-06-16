"""
Bobodo Vocal - Bobodo Client v3
Calls Supabase Edge Function bobodo-chat with real session management.
"""

import logging
import httpx
from typing import Optional

logger = logging.getLogger(__name__)

# Default student_id for vocal pilot (service account)
VOCAL_PILOT_STUDENT_ID = "6745c7ad-732b-47d0-b5b8-06d6dcf286ff"


class BobodoClient:
    """Client for Bobodo Edge Function with session management"""

    def __init__(self, settings):
        self.supabase_url = settings.supabase_url
        self.service_role_key = settings.supabase_service_role_key
        self.edge_function_url = f"{self.supabase_url}/functions/v1/bobodo-chat"
        self.rest_url = f"{self.supabase_url}/rest/v1"
        self.client = httpx.AsyncClient(timeout=30.0)
        self.bobodo_sessions = {}  # ws_session_id -> bobodo_session_id
        logger.info(f"[BOBODO_CLIENT] Initialized (Edge Function mode)")

    async def _get_or_create_bobodo_session(self, ws_session_id: str) -> Optional[str]:
        """Get existing or create new Bobodo session for this WS session"""
        if ws_session_id in self.bobodo_sessions:
            return self.bobodo_sessions[ws_session_id]

        # Create a new Bobodo session via REST API
        try:
            headers = {
                "apikey": self.service_role_key,
                "Authorization": f"Bearer {self.service_role_key}",
                "Content-Type": "application/json",
                "Prefer": "return=representation",
                "Accept-Profile": "app",
                "Content-Profile": "app",
            }

            payload = {
                "student_id": VOCAL_PILOT_STUDENT_ID,
                "title": f"Conversation vocale",
            }

            response = await self.client.post(
                f"{self.rest_url}/bobodo_sessions",
                json=payload,
                headers=headers,
            )

            if response.status_code in (200, 201):
                data = response.json()
                if isinstance(data, list) and data:
                    bobodo_session_id = data[0]["id"]
                elif isinstance(data, dict):
                    bobodo_session_id = data["id"]
                else:
                    logger.error(f"[BOBODO_CLIENT] Unexpected response: {data}")
                    return None

                self.bobodo_sessions[ws_session_id] = bobodo_session_id
                logger.info(f"[BOBODO_CLIENT] Created Bobodo session {bobodo_session_id} for WS {ws_session_id}")
                return bobodo_session_id
            else:
                logger.error(f"[BOBODO_CLIENT] Create session failed {response.status_code}: {response.text[:200]}")
                return None

        except Exception as e:
            logger.error(f"[BOBODO_CLIENT] Create session error: {e}")
            return None

    async def send_message(self, session_id: str, message: str) -> Optional[str]:
        """
        Send message to Bobodo Edge Function.

        Args:
            session_id: WebSocket session ID
            message: User message (transcription)

        Returns:
            Bobodo response text or None
        """
        try:
            # Get or create real Bobodo session
            bobodo_session_id = await self._get_or_create_bobodo_session(session_id)
            if not bobodo_session_id:
                logger.error("[BOBODO_CLIENT] No Bobodo session available")
                return None

            headers = {
                "apikey": self.service_role_key,
                "Authorization": f"Bearer {self.service_role_key}",
                "Content-Type": "application/json",
            }

            payload = {
                "session_id": bobodo_session_id,
                "message": message,
            }

            logger.info(f"[BOBODO_CLIENT] Sending to Edge Function: '{message[:50]}'")
            response = await self.client.post(
                self.edge_function_url,
                json=payload,
                headers=headers,
            )

            if response.status_code != 200:
                logger.error(f"[BOBODO_CLIENT] Edge Function error {response.status_code}: {response.text[:200]}")
                return None

            data = response.json()
            reply = data.get("reply")

            if not reply:
                logger.error(f"[BOBODO_CLIENT] No reply in response: {data}")
                return None

            logger.info(f"[BOBODO_CLIENT] Response: '{reply[:80]}'")
            return reply

        except httpx.TimeoutException:
            logger.error("[BOBODO_CLIENT] Request timeout")
            return None
        except Exception as e:
            logger.error(f"[BOBODO_CLIENT] Error: {e}")
            return None

    def destroy_session(self, session_id: str):
        """Remove session mapping"""
        if session_id in self.bobodo_sessions:
            del self.bobodo_sessions[session_id]
            logger.info(f"[BOBODO_CLIENT] Session {session_id} mapping cleared")

    async def close(self):
        """Close HTTP client"""
        await self.client.aclose()
