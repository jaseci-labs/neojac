import from "@jac/runtime/core" { post, post_stream, decode_failed, file_from, file_send }
import from jaclang.comptime { holds }

glob _leaving: list[tuple[File, dict[str, any]]] = [];
def:pub sent[T](v: T) -> any;
def carries(v: any, was: dict[str, any]) -> bool;
async def leave(space: str, module: str, name: str, args: dict[str, any]);
def take[R](space: str, endpoint: str, data: any) -> R;
async def:pub call_async_def[R](space: str, module: str, name: str, args: dict[str, any]) -> R;
async def:pub call_async_proc(space: str, module: str, name: str, args: dict[str, any]);
async def:pub call_async_stream[T](
    space: str, module: str, name: str, args: dict[str, any]
) -> AsyncIterator[T];
async def:pub spawn_walker[W](space: str, module: str, name: str, args: dict[str, any]) -> W;
