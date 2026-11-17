import argparse
import re
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


class PreviewHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if urlsplit(self.path).path in ("/", "/index.html"):
            source = (Path(self.directory) / "index.html").read_bytes()
            source = source.replace(
                b"<head>",
                b'<head><meta name="jotit-preview-assets" content="1">',
                1,
            )
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(source)))
            self.end_headers()
            self.wfile.write(source)
            return
        super().do_GET()

    def translate_path(self, path):
        path = re.sub(r"^/__jotit_preview/\d+/", "/", path)
        return super().translate_path(path)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, max-age=0, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=7357)
    arguments = parser.parse_args()
    directory = Path(__file__).resolve().parents[1] / "build" / "web"
    if not (directory / "index.html").is_file():
        parser.error("Build the web preview before starting the server.")
    handler = partial(PreviewHandler, directory=str(directory))
    with ThreadingHTTPServer(("127.0.0.1", arguments.port), handler) as server:
        print(f"JotIt preview: http://127.0.0.1:{arguments.port}/", flush=True)
        server.serve_forever()


if __name__ == "__main__":
    main()
