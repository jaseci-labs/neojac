import from jaclang.comptime { note, noted }
import from limits.contract { Limits }

glob _limits: list[dyn Limits] = [];
def:pub consume_limit(scope: str, actor: str, limit: int, seconds: int) -> int;
comptime def limit(f: Callable, uses: int, per: float);

glob _limited: dict[str, tuple[int, int]] = {},
     _limits_read: list[bool] = [];
def:pub limited(module: str, name: str, caller: str, client: str) -> int;
def counted(what: str, module: str, name: str, caller: str, client: str) -> int;
def:pub limited_files(module: str, name: str, caller: str, client: str) -> int;
