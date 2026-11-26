import from common.contract { Host }

enum Effort {
    DEFAULT = "",
    LOW = "low",
    MEDIUM = "medium",
    HIGH = "high",
}

enum PartKind {
    TEXT = "text",
    TOOL_CALL = "tool_use",
    TOOL_RESULT = "tool_result",
    KEPT = "kept",
    MEDIA = "media",
}

obj Part {
    has kind: PartKind,
        text: str = "",
        id: str = "",
        name: str = "",
        input: str = "",
        failed: bool = False,
        data: bytes = b"",
        ctype: str = "";
}

obj Message {
    has role: str,
        parts: list[Part] = [];
}

obj ModelTool {
    has name: str,
        doc: str,
        schema: dict[str, any];
}

obj ModelRequest {
    has system: str,
        messages: list[Message],
        tools: list[ModelTool] = [],
        result_schema: dict[str, any] | None = None,
        max_tokens: int = 4000,
        effort: Effort = Effort.DEFAULT,
        answer_now: bool = False,
        live: bool = False;
}

enum Stop {
    END = "end",
    TOOLS = "tools",
    MAX_TOKENS = "max_tokens",
    REFUSED = "refused",
}

obj ByUsage {
    has requests: int = 0,
        input_tokens: int = 0,
        output_tokens: int = 0,
        cache_read_tokens: int = 0,
        cache_write_tokens: int = 0,
        seconds: float = 0.0,
        model: str = "",
        cost: float | None = None;
    def add(more: ByUsage);
}

enum ByEventKind {
    TEXT = "text",
    TOOL_CALL = "tool_call",
    TOOL_RESULT = "tool_result",
    USAGE = "usage",
    DONE = "done",
}

enum ByEnd {
    ANSWERED = "answered",
    STOPPED = "stopped",
    ROUNDS = "rounds",
    CUT = "cut",
}

obj ByEvent {
    has kind: ByEventKind,
        text: str = "",
        tool: str = "",
        call_id: str = "",
        args: dict[str, any] = {},
        result: str = "",
        usage: ByUsage | None = None,
        ended: ByEnd = ByEnd.ANSWERED,
        value: any = None;
}

obj ByError(Exception) {}

obj ModelReply {
    has message: Message,
        stop: Stop = Stop.END,
        usage: ByUsage = ByUsage();
}

obj Model {
    def open(host: dyn Host) abst;
    def ask(request: ModelRequest) -> Iterator[ByEvent] abst;
}
