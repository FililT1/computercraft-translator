import json
from http.server import BaseHTTPRequestHandler, HTTPServer
import asyncio
from deep_translator import GoogleTranslator
from transliterate import translit

class TranslationServer(BaseHTTPRequestHandler):
    async def translate_text(self, text, source, target):
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, GoogleTranslator(source=source, target=target).translate, text)

    def do_POST(self):
        if self.path == "/translate":
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            request_data = json.loads(post_data.decode('utf-8'))

            text = request_data.get("text", "")
            source = request_data.get("source", "auto")
            target = request_data.get("target", "en")

            try:
                if source == "ru" and target == "en":
                    text = translit(text, 'ru')

                translated_text = asyncio.run(self.translate_text(text, source, target))
                
                response = {"translated_text": translated_text}

                print(f"SOURCE {source}")

                if source == "en" and target == "ru" or source == "auto" and target == "ru":
                    translit_text = translit(translated_text, 'ru', reversed=True)
                    response["translated_text"] = translit_text

            except Exception as e:
                response = {"error": str(e)}

            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response, ensure_ascii=False).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == "__main__":
    server_address = ('', 5002)
    httpd = HTTPServer(server_address, TranslationServer)
    print("Сервер запущен на порту 5002")
    httpd.serve_forever()
