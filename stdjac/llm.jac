import json;
import time;
import from llm.contract {
    ByEnd,
    ByError,
    ByEvent,
    ByEventKind,
    ByUsage,
    Effort,
    Message,
    Model,
    ModelReply,
    ModelRequest,
    ModelTool,
    Part,
    PartKind,
    Stop,
}

enum IterationAction {
    CONTINUE = "continue",
    ABORT_WITH_SUMMARY = "abort",
}

glob _model: list[dyn Model] = [];
def model -> dyn Model;

obj IterationContext {
    has iteration: int = 0,
        usage: ByUsage = ByUsage();
}

glob _usage_hooks: list[Callable[[ByUsage], None]] = [];
def on_usage(f: Callable[[ByUsage], None]);

obj LLM(By, ByStreams, ByChooser) {
    has max_tokens: int = 4000,
        effort: Effort = Effort.DEFAULT,
        max_react_iterations: int = 8,
        max_output_retries: int = 1,
        tools: list[ByTool] = [],
        on_iteration: any = None,
        system_prompt: str = "",
        conversation: list[Message] | None = None,
        select: any = 1,
        intent: str = "",
        media: any = None;

    def invoke(call: ByCall) -> any;
    def stream(call: ByCall) -> Iterator[ByEvent];
    def choose(choice: ByChoice) -> list[int];
    def answer(call: ByCall, live: bool) -> Iterator[ByEvent];
    def run_tool(named: dict[str, ByTool], u: Part) -> Part;
    def run_tools(named: dict[str, ByTool], uses: list[Part]) -> list[Part];
}

def llm(
    max_tokens: int = 4000,
    effort: Effort = Effort.DEFAULT,
    max_output_retries: int = 1,
    tools: list[ByTool] = [],
    max_react_iterations: int = 8,
    on_iteration: any = None,
    system_prompt: str = "",
    conversation: list[Message] | None = None,
    select: any = 1,
    intent: str = "",
    media: any = None,
) -> LLM;
glob MEDIA_BEGINS: dict[str, bytes] = {
    "image/png": b"\x89PNG\r\n\x1a\n",
    "image/jpeg": b"\xff\xd8\xff",
    "image/gif": b"GIF8",
    "image/webp": b"RIFF",
    "application/pdf": b"%PDF-",
};

def media_parts(given: any) -> list[Part];
def kept_message(m: Message) -> Message;
def opens_turn(m: Message) -> bool;
def latest_turns(history: list[Message], most: int) -> list[Message];
