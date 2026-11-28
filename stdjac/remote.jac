import json;
import os;
import from jaclang.comptime { apply, args_type, fields, holds, params }
import from store.contract { StoreConflict }
import from transport.contract { Request, Response, Transport }

obj:pub RemoteError(Exception) {
    has space: str = "",
        endpoint: str = "",
        detail: str = "";

    def __str__ -> str;
}

obj:pub RemoteUnavailable(RemoteError) {}

obj:pub RemoteTimeout(RemoteError) {}

obj:pub RemoteRejected(RemoteError) {}

obj:pub RemoteDecodeError(RemoteError) {}

obj:pub RemoteFailed(RemoteError) {}

enum:pub Access {
    PUB,
    PROT,
    INTERNAL,
}

obj:pub Endpoint {
    has space: str,
        module: str,
        name: str,
        access: Access,
        is_walker: bool,
        run: Callable[[dict[str, any]], any],
        items: Callable[[dict[str, any]], Iterator[any]] | None = None;

    def path -> str;
}

def:pub endpoint_path(space: str, module: str, name: str, spawns: bool) -> str;

glob _endpoints: dict[str, Endpoint] = {};

glob _in_process: dict[str, Callable[[str, bytes, str, bool], tuple[int, bytes]]] = {};

glob _transport: list[dyn Transport] = [];

def:pub transport -> dyn Transport;
def:pub on_loop(work: Callable[[], None]);
def:pub loop_serving -> bool;
def serve_endpoint(e: Endpoint);
def call_endpoint(space: str, module: str, name: str, spawns: bool, args: dict[str, any]) -> any;
def stream_endpoint(space: str, module: str, name: str, args: dict[str, any]) -> Iterator[any];
def reply_data(space: str, endpoint: str, text: str) -> any;
def reply_error(space: str, endpoint: str, reply: dict[str, any]) -> RemoteError;
def:pub carry_in_process(space: str, port: Callable[[str, bytes, str, bool], tuple[int, bytes]]);
def held_through(port: Callable[[str, bytes, str, bool], tuple[int, bytes]]) -> list[str] | None;

glob _open_streams: dict[str, Iterator[bytes]] = {},
     _opened: list[int] = [0];
def:pub open_stream(events: Iterator[bytes]) -> tuple[int, bytes];
def:pub pull_stream(rest: str) -> tuple[int, bytes];
def stream_opened(raw: bytes) -> str;
def carried_items(space: str, endpoint: str, path: str, body: bytes) -> Iterator[any];
def:pub carry_stream(
    space: str, path: str, body: bytes, caller: str, trusted: bool
) -> tuple[int, bytes, Iterator[bytes] | None];
def carried_events(space: str, id: str, caller: str, trusted: bool) -> Iterator[bytes];
def:pub carried(space: str) -> bool;
def crossing_request(space: str, path: str, endpoint: str, body: bytes) -> tuple[str, Request];

glob CALL_SECONDS: float = 30.0,
     STREAM_SECONDS: float = 60.0;
def carried_reply(space: str, path: str, endpoint: str, body: bytes) -> str;
def carried_stream(space: str, path: str, endpoint: str, body: bytes) -> Iterator[any];
def:pub forward_remote(
    url: str, path: str, body: bytes, authorization: str, method: str
) -> tuple[int, bytes, Iterator[bytes] | None];
def:pub forward_file(url: str, r: Request) -> Response;
def:pub sent[T](v: T) -> any;
def:pub refused(module: str, name: str, caller: str, trusted: bool) -> tuple[int, bytes] | None;
def refuse_unknown[T](given: dict[str, any]);
def:pub serve_def(comptime f: any, space: str, module: str, name: str, access: Access) -> bool;
def:pub serve_proc(comptime f: any, space: str, module: str, name: str, access: Access) -> bool;
def:pub serve_async_def(
    comptime f: any, space: str, module: str, name: str, access: Access
) -> bool;
def:pub serve_async_proc(
    comptime f: any, space: str, module: str, name: str, access: Access
) -> bool;
def:pub serve_stream(comptime f: any, space: str, module: str, name: str, access: Access) -> bool;
def:pub serve_async_stream(
    comptime f: any, space: str, module: str, name: str, access: Access
) -> bool;
def not_one_reply(name: str) -> any;
def sent_items[T](items: Iterator[T]) -> Iterator[any];
def sent_async_items[T](items: AsyncIterator[T]) -> Iterator[any];
def:pub serve_walker[W](space: str, module: str, name: str, access: Access) -> bool;
def:pub drive[R](c: Coroutine[any, any, R]) -> R;
def:pub settle(v: any);
def:pub json_values(v: any) -> any;
def admit(path: str, body: bytes, caller: str, trusted: bool) -> tuple[Endpoint
    | None, dict[str, any], tuple[int, bytes]];
def:pub answer(path: str, body: bytes, caller: str, trusted: bool) -> tuple[int, bytes];
def:pub answer_stream(
    path: str, body: bytes, caller: str, trusted: bool
) -> tuple[int, bytes, Iterator[bytes] | None];
def events_of(e: Endpoint, items: Iterator[any], f: Flight) -> Iterator[bytes];
def:pub raised_at(x: BaseException) -> str;

def error_event(kind: str, detail: str) -> bytes;
def:pub run_endpoint(e: Endpoint, given: dict[str, any], caller: str) -> tuple[int, bytes];
def:pub endpoint_named(module: str, name: str) -> Endpoint | None;

def reply_fail(status: int, kind: str, detail: str) -> tuple[int, bytes];
def take[R](space: str, endpoint: str, data: any) -> R;
def:pub call_def[R](space: str, module: str, name: str, args: dict[str, any]) -> R;
def:pub call_proc(space: str, module: str, name: str, args: dict[str, any]);
async def:pub call_async_def[R](space: str, module: str, name: str, args: dict[str, any]) -> R;
async def:pub call_async_proc(space: str, module: str, name: str, args: dict[str, any]);
def:pub call_stream[T](space: str, module: str, name: str, args: dict[str, any]) -> Iterator[T];
async def:pub call_async_stream[T](
    space: str, module: str, name: str, args: dict[str, any]
) -> AsyncIterator[T];
def:pub spawn_walker[W](space: str, module: str, name: str, args: dict[str, any]) -> W;
