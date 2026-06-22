"""
Bobodo Vocal - Bobodo Client
HTTP client for communicating with Supabase Edge Function bobodo-chat
"""

import logging
import httpx
from typing import Optional


logger = logging.getLogger(__name__)


class BobodoClient:
    """HTTP client for Bobodo Edge Function"""
    
    def __init__(self, settings):
        """
        Initialize Bobodo client
        
        Args:
            settings: Application settings
        """
        self.supabase_url = settings.supabase_url
        self.service_role_key = settings.supabase_service_role_key
        self.openrouter_api_key = settings.openrouter_api_key
        
        # Edge Function URL
        self.edge_function_url = f"{self.supabase_url}/functions/v1/bobodo-chat"
        
        # HTTP client
        self.client = httpx.AsyncClient(timeout=30.0)
        
    async def send_message(self, session_id: str, message: str) -> Optional[str]:
        """
        Send message to Bobodo Edge Function
        
        Args:
            session_id: Bobodo session ID
            message: User message
            
        Returns:
            Bobodo response or None if failed
        """
        try:
            # Prepare request
            payload = {
                "session_id": session_id,
                "message": message
            }
            
            headers = {
                "apikey": self.service_role_key,
                "Authorization": f"Bearer {self.service_role_key}",
                "Content-Type": "application/json"
            }
            
            # Send request
            logger.info(f"Sending message to Bobodo: {message}")
            response = await self.client.post(
                self.edge_function_url,
                json=payload,
                headers=headers
            )
            
            # Check response
            if response.status_code != 200:
                logger.error(f"Bobodo request failed: {response.status_code}")
                logger.error(f"Response: {response.text}")
                return None
                
            # Parse response
            data = response.json()
            reply = data.get("reply")
            
            if not reply:
                logger.error("No reply in Bobodo response")
                return None
                
            logger.info(f"Bobodo response: {reply}")
            
            return reply
            
        except httpx.TimeoutException:
            logger.error("Bobodo request timeout")
            return None
        except Exception as e:
            logger.error(f"Bobodo request failed: {e}")
            return None
            
    async def close(self):
        """Close HTTP client"""
        await self.client.aclose()

