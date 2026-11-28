import json;
import from jaclang.comptime { apply, args_type, note, noted, params, restore, returns }
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
        run: Callable[[], any];
}

glob _routes: list[RestRoute] = [],
     _routes_read: list[bool] = [];
def:pub routes -> list[RestRoute];
def:pub route_of(method: str, path: str) -> RestRoute | None;
def:pub route_answer(
    r: RestRoute, caller: str, trusted: bool
) -> tuple[int, str, bytes, dict[str, str]];
