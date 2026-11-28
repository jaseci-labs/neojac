import json;
import time;
import urllib.request;
import from urllib.error { HTTPError }
import from common.contract { Host, Secret }
import from llm.contract {
    ByError,
    ByEvent,
    ByEventKind,
    ByUsage,
    Effort,
    Message,
    Model,
    ModelReply,
    ModelRequest,
    Part,
    PartKind,
    Stop,
}

def api_messages(m: Message) -> list[dict[str, any]];
def reply_message(m: dict[str, any]) -> Message;
def strict_schema(schema: dict[str, any]) -> dict[str, any] | None;
def strict_result(schema: dict[str, any]) -> dict[str, any] | None;
def stop_of(reason: str, refused: bool) -> Stop;
def usage_of(reply: dict[str, any], model: str) -> ByUsage;
def cost_of(used: ByUsage, rates: dict[str, list[float]], asked: str) -> float | None;

obj OpenAI(Model) {
    has key: Secret = Secret(variable="OPENAI_API_KEY"),
        model: str = "gpt-5-mini",
        address: str = "https://api.openai.com/v1",
        timeout: int = 60,
        retries: int = 0,
        rates: dict[str, list[float]] = {};

    has given_key: str postinit;

    def postinit;
    def open(host: dyn Host);
    def post(body: dict[str, any]) -> any;
    def read_events(r: any) -> Iterator[ByEvent];

    def ask(request: ModelRequest) -> Iterator[ByEvent];
}
