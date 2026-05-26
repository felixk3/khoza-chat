from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse
import json
import base64

app = FastAPI()

html = """
<!DOCTYPE html>
<html>
<head>
    <title>Chat WebSocket</title>
</head>
<body>

    <h1>WebSocket Chat</h1>
    <h3>Your ID: <span id="ws-id"></span></h3>

    <form onsubmit="sendMessage(event)">

        <input
            type="text"
            id="messageText"
            placeholder="Digite uma mensagem"
            autocomplete="off"
        />

        <br><br>

        <!-- imagem/video/audio -->
        <input type="file" id="fileInput" />

        <br><br>

        <!-- localização -->
        <button type="button" onclick="sendLocation()">
            Enviar Localização
        </button>

        <br><br>

        <button type="submit">Enviar</button>

    </form>

    <hr>

    <ul id="messages"></ul>

<script>

    const client_id = Date.now()

    document.querySelector("#ws-id").textContent = client_id

    const ws = new WebSocket(`ws://localhost:8000/ws/${client_id}`)

    ws.onmessage = function(event) {

        const data = JSON.parse(event.data)

        const messages = document.getElementById("messages")

        const item = document.createElement("li")

        // ============================================
        // TEXTO
        // ============================================

        if (data.type === "text") {

            item.innerHTML = `<b>${data.sender}</b>: ${data.message}`

        }

        // ============================================
        // IMAGEM
        // ============================================

        else if (data.type === "image") {

            item.innerHTML = `
                <b>${data.sender}</b><br>
                <img src="${data.file}" width="250"/>
            `

        }

        // ============================================
        // VIDEO
        // ============================================

        else if (data.type === "video") {

            item.innerHTML = `
                <b>${data.sender}</b><br>
                <video width="300" controls>
                    <source src="${data.file}">
                </video>
            `

        }

        // ============================================
        // AUDIO
        // ============================================

        else if (data.type === "audio") {

            item.innerHTML = `
                <b>${data.sender}</b><br>
                <audio controls>
                    <source src="${data.file}">
                </audio>
            `

        }

        // ============================================
        // LOCALIZAÇÃO / MAPA
        // ============================================

        else if (data.type === "location") {

            item.innerHTML = `
                <b>${data.sender}</b><br>

                Latitude: ${data.lat}<br>
                Longitude: ${data.lng}<br>

                <a target="_blank"
                   href="https://www.google.com/maps?q=${data.lat},${data.lng}">
                    Abrir no mapa
                </a>
            `

        }

        messages.appendChild(item)
    }

    // ============================================
    // ENVIAR TEXTO OU FICHEIRO
    // ============================================

    async function sendMessage(event) {

        event.preventDefault()

        const input = document.getElementById("messageText")
        const fileInput = document.getElementById("fileInput")

        // ============================================
        // ENVIAR TEXTO
        // ============================================

        if (input.value.trim() !== "") {

            ws.send(JSON.stringify({
                type: "text",
                message: input.value
            }))

            input.value = ""
        }

        // ============================================
        // ENVIAR FICHEIRO
        // ============================================

        const file = fileInput.files[0]

        if (file) {

            const reader = new FileReader()

            reader.onload = function() {

                ws.send(JSON.stringify({
                    type: file.type,
                    file: reader.result
                }))
            }

            reader.readAsDataURL(file)

            fileInput.value = ""
        }
    }

    // ============================================
    // ENVIAR LOCALIZAÇÃO
    // ============================================

    function sendLocation() {

        navigator.geolocation.getCurrentPosition((position) => {

            ws.send(JSON.stringify({
                type: "location",
                lat: position.coords.latitude,
                lng: position.coords.longitude
            }))
        })
    }

</script>

</body>
</html>
"""


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


@app.get("/")
async def get():
    return HTMLResponse(html)


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