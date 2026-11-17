import tempfile
import threading
import unittest
from functools import partial
from http.server import ThreadingHTTPServer
from pathlib import Path
from urllib.request import urlopen

from scripts.serve_preview import PreviewHandler


class PreviewServerTest(unittest.TestCase):
    def test_reload_and_versioned_assets_never_clear_storage(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "index.html").write_text("<head></head><p>JotIt</p>")
            (root / "assets").mkdir()
            font = root / "assets" / "font.otf"
            font.write_bytes(b"font-version-one")
            server = ThreadingHTTPServer(
                ("127.0.0.1", 0), partial(PreviewHandler, directory=directory)
            )
            worker = threading.Thread(target=server.serve_forever, daemon=True)
            worker.start()
            base = f"http://127.0.0.1:{server.server_port}"
            try:
                with urlopen(base) as response:
                    self.assertIn(b'jotit-preview-assets', response.read())
                    self.assertIn("no-store", response.headers["Cache-Control"])
                    self.assertNotIn("Clear-Site-Data", response.headers)
                with urlopen(base + "/__jotit_preview/123/assets/font.otf") as response:
                    self.assertEqual(response.read(), b"font-version-one")
                font.write_bytes(b"font-version-two")
                with urlopen(base + "/__jotit_preview/456/assets/font.otf") as response:
                    self.assertEqual(response.read(), b"font-version-two")
            finally:
                server.shutdown()
                server.server_close()
                worker.join()


if __name__ == "__main__":
    unittest.main()
