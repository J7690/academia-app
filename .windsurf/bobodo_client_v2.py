"""
Bobodo Vocal - Bobodo Client v2
Direct OpenRouter call — bypasses Edge Function for voice pilot.
Keeps conversation history in-memory per session.
"""

import logging
import httpx
from typing import Optional

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """Tu es Bobodo, l'assistant intelligent de la plateforme Academia.
Tu es chaleureux, bienveillant et tu parles en français simple.
Tu aides les étudiants avec leurs questions sur l'orientation, les études, les concours et la plateforme Academia.
Tu donnes des réponses courtes et claires (2-4 phrases max), adaptées à la conversation vocale.
Si tu ne sais pas, dis-le honnêtement.
Ne mentionne jamais que tu es une IA ou un modèle de langage."""


class BobodoClient:
    """Direct OpenRouter client for voice interactions"""

    def __init__(self, settings):
        self.openrouter_api_key = settings.openrouter_api_key
        self.openrouter_model = settings.openrouter_model
        self.client = httpx.AsyncClient(timeout=30.0)
        self.conversations = {}  # session_id -> list of messages
        logger.info(f"[BOBODO_CLIENT] Initialized with model {self.openrouter_model}")

    async def send_message(self, session_id: str, message: str) -> Optional[str]:
        """
        Send message to OpenRouter directly.

        Args:
            session_id: Session ID for conversation tracking
            message: User message (transcription)

        Returns:
            Bobodo response text or None
        """
        try:
            if not self.openrouter_api_key or not self.openrouter_model:
                logger.error("[BOBODO_CLIENT] Missing API key or model")
                return None

            # Get or create conversation history
            if session_id not in self.conversations:
                self.conversations[session_id] = []

            history = self.conversations[session_id]
            history.append({"role": "user", "content": message})

            # Build messages array
            messages = [{"role": "system", "content": SYSTEM_PROMPT}]
            # Keep last 10 messages (5 exchanges)
            messages.extend(history[-10:])

            payload = {
                "model": self.openrouter_model,
                "messages": messages,
                "temperature": 0.3,
                "max_tokens": 200,
            }

            headers = {
                "Authorization": f"Bearer {self.openrouter_api_key}",
                "Content-Type": "application/json",
            }

            logger.info(f"[BOBODO_CLIENT] Sending to OpenRouter: '{message[:50]}'")
            response = await self.client.post(
                "https://openrouter.ai/api/v1/chat/completions",
                json=payload,
                headers=headers,
            )

            if response.status_code != 200:
                logger.error(f"[BOBODO_CLIENT] OpenRouter error {response.status_code}: {response.text[:200]}")
                return None

            data = response.json()
            choices = data.get("choices", [])
            if not choices:
                logger.error("[BOBODO_CLIENT] No choices in response")
                return None

            reply = choices[0].get("message", {}).get("content", "").strip()
            if not reply:
                logger.error("[BOBODO_CLIENT] Empty reply")
                return None

            # Store assistant reply in history
            history.append({"role": "assistant", "content": reply})

            logger.info(f"[BOBODO_CLIENT] Response: '{reply[:80]}'")
            return reply

        except httpx.TimeoutException:
            logger.error("[BOBODO_CLIENT] Request timeout")
            return None
        except Exception as e:
            logger.error(f"[BOBODO_CLIENT] Error: {e}")
            return None

    def destroy_session(self, session_id: str):
        """Remove conversation history for a session"""
        if session_id in self.conversations:
            del self.conversations[session_id]
            logger.info(f"[BOBODO_CLIENT] Session {session_id} conversation cleared")

    async def close(self):
        """Close HTTP client"""
        await self.client.aclose()
