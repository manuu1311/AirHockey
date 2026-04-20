from http.server import SimpleHTTPRequestHandler, HTTPServer
import mimetypes

class MyHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        super().end_headers()

    def guess_type(self, path):
        if path.endswith(".wasm"):
            return "application/wasm"
        return super().guess_type(path)

if __name__ == "__main__":
    mimetypes.add_type("application/wasm", ".wasm")

    server_address = ("", 8000)
    httpd = HTTPServer(server_address, MyHandler)

    print("Serving on http://localhost:8000")
    httpd.serve_forever()