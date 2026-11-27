import json;
import urllib.parse;
import from jaclang.comptime { Kind, apply, args_type, kind, note, noted, params, returns }
import from markup { Markup }

enum HTTPMethod {
    GET = "GET",
    POST = "POST",
}

comptime def restspec(
    f: Callable,
    method: HTTPMethod,
    path: str,
    produces: str | None = None,
    envelope: bool | None = None,
    headers: dict[str, str] | None = None,
);

obj:pub RestRoute {
    has method: HTTPMethod,
        path: str,
        produces: str,
        envelope: bool,
        headers: dict[str, str] | None,
        markup: bool,
        module: str,
        name: str,
        takes: list[str],
        texts: list[str],
        run: Callable[[dict[str, any]], any];
}

glob _routes: list[RestRoute] = [],
     _routes_read: list[bool] = [];
def:pub routes -> list[RestRoute];
def:pub route_of(method: str, path: str) -> RestRoute | None;
def:pub route_answer(
    r: RestRoute, query: str, body: bytes, caller: str, trusted: bool
) -> tuple[int, str, bytes, dict[str, str]];
def route_args(r: RestRoute, query: str, body: bytes) -> tuple[dict[str, any], str];
def route_run(
    r: RestRoute, e: Endpoint | None, given: dict[str, any], caller: str, trusted: bool
) -> tuple[int, bytes];
