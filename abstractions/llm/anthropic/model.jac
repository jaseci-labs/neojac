import base64;
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

glob FALLBACK_BETA: str = "server-side-fallback-2026-07-01";
def api_message(m: Message) -> dict[str, any];
def reply_message(m: dict[str, any]) -> Message;
def strict_schema(schema: dict[str, any]) -> dict[str, any] | None;
def strict_result(schema: dict[str, any]) -> dict[str, any] | None;
def usage_of(reply: dict[str, any], model: str) -> ByUsage;
def cost_of(used: ByUsage, rates: dict[str, list[float]]) -> float | None;

obj Anthropic(Model) {
    has key: Secret = Secret(variable="ANTHROPIC_API_KEY"),
        model: str = "claude-sonnet-5-5",
        address: str = "https://api.anthropic.com",
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
