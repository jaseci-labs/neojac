import from jaclang.comptime {
    Kind,
    apply,
    args_type,
    fields,
    get_field,
    kind,
    members,
    only_reads,
    params,
    sendable,
    type_args,
}

import from neojac {
    def __sem(f: any) -> str;
}

import from llm.contract { ByEnd, ByError, ByEvent, ByEventKind, ByUsage }

obj:pub ByTool {
    has name: str,
        doc: str = "",
        schema: dict[str, any] = {},
        call: Callable[[dict[str, any]], any],
        alone: bool = True;
}

obj:pub ByCall {
    has name: str,
        doc: str = "",
        args: dict[str, any] = {},
        arg_docs: dict[str, str] = {},
        result_schema: dict[str, any] = {},
        decode: Callable[[any], any] | None = None;
}

obj:pub By {
    def invoke(call: ByCall) -> any abst;
}

obj:pub ByChoice {
    has name: str,
        asker: dict[str, any] = {},
        at: dict[str, any] = {},
        options: list[dict[str, any]] = [];
}

obj:pub ByChooser {
    def choose(choice: ByChoice) -> list[int] abst;
}

obj:pub ByWay {
    has of: Callable[[any], dict[str, any] | None];
}

obj:pub ByStreams {
    def stream(call: ByCall) -> Iterator[ByEvent] abst;
}

comptime NO_SCHEMA: str = "a `by` result's type has no JSON schema: no any, bytes, tuple, walker or function value";
def:pub schema[T] -> dict[str, any];
def schema_in[T](within: list[any]) -> dict[str, any];
def object_schema[T](within: list[any]) -> dict[str, any];
def:pub described(schema: dict[str, any], doc: str) -> dict[str, any];
def:pub by_tool(comptime f: any, name: str) -> ByTool;
def:pub by_method[T](comptime m: any, target: T, name: str) -> ByTool;
def:pub by_call[R](comptime f: any, name: str, b: dyn By, args: dict[str, any]) -> R;
def docs_of(comptime f: any, args: dict[str, any]) -> dict[str, str];
def:pub by_stream(
    comptime f: any, name: str, b: dyn ByStreams, args: dict[str, any]
) -> Iterator[ByEvent];
def:pub by_shown[T](x: T, name: str, means: str) -> dict[str, any];
def:pub by_way[E](name: str, means: str) -> ByWay;
def:pub by_choose[N: Node](
    chooser: dyn ByChooser,
    name: str,
    asker: dict[str, any],
    at: Node,
    at_shown: dict[str, any],
    kind: str,
    means: str,
    options: list[N],
    ways: list[ByWay],
) -> list[N];
