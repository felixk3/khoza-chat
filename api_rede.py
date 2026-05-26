from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse
import json
import base64

app = FastAPI()

class ConnectionManager:

    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):

        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def send_personal_message(self, data: dict, websocket: WebSocket):
        await websocket.send_text(json.dumps(data))

    async def broadcast(self, data: dict):

        for connection in self.active_connections:
            await connection.send_text(json.dumps(data))


manager = ConnectionManager()


@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: int):

    await manager.connect(websocket)

    try:

        while True:

            data = await websocket.receive_text()

            data_json = json.loads(data)

            # ============================================
            # TEXTO
            # ============================================

            if data_json["type"] == "text":

                response = {
                    "type": "text",
                    "sender": f"Client #{client_id}",
                    "message": data_json["message"]
                }

            # ============================================
            # LOCALIZAÇÃO
            # ============================================

            elif data_json["type"] == "location":

                response = {
                    "type": "location",
                    "sender": f"Client #{client_id}",
                    "lat": data_json["lat"],
                    "lng": data_json["lng"]
                }

            # ============================================
            # FICHEIROS
            # ============================================

            else:

                file_type = data_json["type"]

                # image/png -> image
                # video/mp4 -> video
                # audio/mp3 -> audio

                main_type = file_type.split("/")[0]

                response = {
                    "type": main_type,
                    "sender": f"Client #{client_id}",
                    "file": data_json["file"]
                }

            await manager.broadcast(response)

    except WebSocketDisconnect:

        manager.disconnect(websocket)

        await manager.broadcast({
            "type": "text",
            "sender": "SYSTEM",
            "message": f"Client #{client_id} saiu do chat"
        })

#--host 0.0.0.0 --port 8000 --reload
