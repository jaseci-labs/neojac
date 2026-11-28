import os;
import urllib.parse;
import from transport.contract { Response }

import from neojac {
    def __app_pages -> dict[str, str];
}

glob CONTENT_TYPES: dict[str, str] = {
         ".html": "text/html; charset=utf-8",
         ".js": "text/javascript; charset=utf-8",
         ".mjs": "text/javascript; charset=utf-8",
         ".css": "text/css; charset=utf-8",
         ".json": "application/json",
         ".svg": "image/svg+xml",
         ".png": "image/png",
         ".jpg": "image/jpeg",
         ".jpeg": "image/jpeg",
         ".gif": "image/gif",
         ".webp": "image/webp",
         ".ico": "image/x-icon",
         ".woff": "font/woff",
         ".woff2": "font/woff2",
         ".ttf": "font/ttf",
         ".txt": "text/plain; charset=utf-8",
         ".wasm": "application/wasm",
         ".map": "application/json",
         ".md": "text/markdown; charset=utf-8",
     },
     HELD_PAGES: dict[str, bytes] = {
         place: text.encode("utf-8")
         for (place, text) in __app_pages().items()
     };

def:pub static_file(
    top: str, path: str, headers: dict[str, str] = {}, routes: list[str] = []
) -> Response;
def held_file(
    space: str, path: str, headers: dict[str, str] = {}, routes: list[str] = []
) -> Response;
def page_answer(
    rel: str,
    found: bytes | None,
    document: bytes | None,
    path: str,
    headers: dict[str, str],
    routes: list[str],
) -> Response;
def routed(path: str, routes: list[str]) -> bool;
