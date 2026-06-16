import asyncio
import websockets
import json
import base64
import logging
from tts_service import generate_tts

# Configuration logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('voice_server')

# Gestion interruption
interrupt_flag = False

async def handle_websocket(websocket):
    """
    Handler WebSocket pour communication vocale.
    """
    global interrupt_flag
    
    try:
        logger.info("Client connecté")
        
        async for message in websocket:
            data = json.loads(message)
            message_type = data.get('type')
            
            if message_type == 'text':
                # Génération TTS
                text = data.get('text', '')
                logger.info(f"Message reçu: {text[:50]}...")
                
                try:
                    # Vérification interruption
                    if interrupt_flag:
                        logger.info("Interruption détectée, annulation génération")
                        interrupt_flag = False
                        error_response = {
                            'type': 'interrupted',
                            'message': 'Generation interrupted'
                        }
                        await websocket.send(json.dumps(error_response))
                        continue
                    
                    audio_bytes = generate_tts(text)
                    
                    # Encodage base64
                    audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
                    
                    # Envoi audio
                    response = {
                        'type': 'audio_response',
                        'audio': audio_base64
                    }
                    await websocket.send(json.dumps(response))
                    logger.info("Audio envoyé")
                    
                except Exception as e:
                    logger.error(f"Erreur génération TTS: {e}")
                    error_response = {
                        'type': 'error',
                        'message': str(e)
                    }
                    await websocket.send(json.dumps(error_response))
                    
            elif message_type == 'interrupt':
                # Interruption (barge-in)
                logger.info("Interruption reçue")
                interrupt_flag = True
                
            elif message_type == 'ping':
                # Ping/pong pour keep-alive
                await websocket.send(json.dumps({'type': 'pong'}))
                
    except Exception as e:
        logger.error(f"Erreur WebSocket: {e}")
    finally:
        logger.info("Client déconnecté")

async def main():
    """
    Point d'entrée serveur WebSocket.
    """
    server = await websockets.serve(handle_websocket, "0.0.0.0", 8000)
    logger.info("Serveur WebSocket démarré sur ws://0.0.0.0:8000")
    await server.wait_closed()

if __name__ == "__main__":
    asyncio.run(main())
