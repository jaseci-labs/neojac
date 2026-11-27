impl api_message(m: Message) -> dict[str, any] {
    content: list[any] = [];
    for p in m.parts {
        if p.kind == PartKind.TEXT {
            content.append({"type": "text", "text": p.text});
        } elif p.kind == PartKind.TOOL_CALL {
            content.append({
                "type": "tool_use",
                "id": p.id,
                "name": p.name,
                "input": json.loads(p.input) if p.input != "" else {},
            });
        } elif p.kind == PartKind.KEPT {
            content.append(json.loads(p.text));
        } elif p.kind == PartKind.MEDIA {
            content.append({
                "type": "document" if p.ctype == "application/pdf" else "image",
                "source": {
                    "type": "base64",
                    "media_type": p.ctype,
                    "data": base64.b64encode(p.data).decode("ascii"),
                },
            });
        } else {
            result: dict[str, any] = {
                "type": "tool_result",
                "tool_use_id": p.id,
                "content": p.text,
            };
            if p.failed {
                result["is_error"] = True;
            }
            content.append(result);
        }
    }
    return {"role": m.role, "content": content};
}

impl reply_message(m: dict[str, any]) -> Message {
    out = Message(role="assistant");
    content: any = m.get("content", []);
    if isinstance(content, str) {
        out.parts.append(Part(kind=PartKind.TEXT, text=content));
        return out;
    }
    blocks: list[any] = content;
    for b in blocks {
        kind = str(b.get("type", ""));
        if kind == "text" {
            out.parts.append(Part(kind=PartKind.TEXT, text=str(b["text"])));
        } elif kind == "tool_use" {
            out.parts.append(
                Part(
                    kind=PartKind.TOOL_CALL,
                    id=str(b["id"]),
                    name=str(b["name"]),
                    input=json.dumps(b.get("input", {})),
                ),
            );
        } else {
            out.parts.append(Part(kind=PartKind.KEPT, text=json.dumps(b)));
        }
    }
    return out;
}

impl strict_schema(schema: dict[str, any]) -> dict[str, any] | None {
    if len(schema) == 0 or (len(schema) == 1 and "description" in schema) {
        return None;
    }
    out: dict[str, any] = dict(schema);
    if schema.get("type", "") == "object" {
        if "properties" not in schema {
            return None;
        }
        props: dict[str, any] = schema["properties"];
        strict_props: dict[str, any] = {};
        for k in props.keys() {
            p = strict_schema(props[k]);
            if p is None {
                return None;
            }
            strict_props[k] = p;
        }
        out["properties"] = strict_props;
        out["additionalProperties"] = False;
    }
    if schema.get("type", "") == "array" {
        items = strict_schema(schema["items"]);
        if items is None {
            return None;
        }
        out["items"] = items;
    }
    return out;
}

impl strict_result(schema: dict[str, any]) -> dict[str, any] | None {
    s = strict_schema(schema);
    if s is None {
        return None;
    }
    return {
        "type": "object",
        "properties": {"result": s},
        "required": ["result"],
        "additionalProperties": False,
    };
}

impl usage_of(reply: dict[str, any], model: str) -> ByUsage {
    used: dict[str, any] = reply.get("usage", {}) or {};
    return ByUsage(
        input_tokens=int(used.get("input_tokens", 0) or 0),
        output_tokens=int(used.get("output_tokens", 0) or 0),
        cache_read_tokens=int(used.get("cache_read_input_tokens", 0) or 0),
        cache_write_tokens=int(used.get("cache_creation_input_tokens", 0) or 0),
        model=str(reply.get("model", model)),
    );
}

impl cost_of(used: ByUsage, rates: dict[str, list[float]]) -> float | None {
    if used.model not in rates {
        return None;
    }
    rate = rates[used.model];
    return (
        used.input_tokens * rate[0]
        + used.output_tokens * rate[1]
        + used.cache_read_tokens * rate[2]
        + used.cache_write_tokens * rate[3]
    )
        / 1000000.0;
}

impl Anthropic.postinit {
    self.given_key = "";
}

impl Anthropic.open(host: dyn Host) {
    self.given_key = host.secret(self.key);
    for (model, rate) in self.rates.items() {
        if len(rate) != 4 {
            raise ByError(
                "[llm.anthropic] rates: '"
                    + model
                    + "' is given "
                    + str(len(rate))
                    + " numbers, and a rate is four: dollars per million tokens of input, of output, read from the cache and written to it",
            );
        }
    }
}

impl Anthropic.post(body: dict[str, any]) -> any {
    if self.given_key == "" {
        raise ByError(self.key.variable + " isn't set");
    }
    data = json.dumps(body).encode("utf-8");
    attempt = 0;
    while True {
        req = urllib.request.Request(
            self.address.rstrip("/") + "/v1/messages",
            data=data,
            headers={
                "content-type": "application/json",
                "x-api-key": self.given_key,
                "anthropic-version": "2026-10-21",
                "anthropic-beta": FALLBACK_BETA,
            },
            method="POST",
        );
        try {
            return urllib.request.urlopen(req, timeout=float(self.timeout));
        } except HTTPError as e {
            if not (e.code == 408 or e.code == 409 or e.code == 429 or e.code >= 500)
                or attempt >= self.retries
            {
                raise ByError(
                    "the model's API answered " + str(e.code) + ": " + e.read().decode("utf-8")
                );
            }
        } except OSError as e {
            if attempt >= self.retries {
                raise ByError("the model's API can't be reached: " + str(e));
            }
        }
        attempt += 1;
        time.sleep(float(2 ** attempt));
    }
}

impl Anthropic.read_events(r: any) -> Iterator[ByEvent] {
    message: dict[str, any] = {};
    blocks: list[any] = [];
    inputs: dict[int, str] = {};
    used: dict[str, any] = {};
    forever {
        line: bytes = r.readline();
        if len(line) == 0 {
            break;
        }
        text = line.decode("utf-8").strip();
        if not text.startswith("data: ") {
            continue;
        }
        event: dict[str, any] = json.loads(text[6:len(text)]);
        kind = str(event.get("type", ""));
        if kind == "message_start" {
            message = dict(event["message"]);
            used = dict(message.get("usage", {}) or {});
        } elif kind == "content_block_start" {
            block: dict[str, any] = dict(event["content_block"]);
            while len(blocks) <= int(event["index"]) {
                blocks.append({});
            }
            blocks[int(event["index"])] = block;
            if block.get("type", "") == "tool_use" {
                inputs[int(event["index"])] = "";
            } elif block.get("type", "") == "thinking" and "thinking" not in block {
                block["thinking"] = "";
            }
        } elif kind == "content_block_delta" {
            at = int(event["index"]);
            delta: dict[str, any] = event["delta"];
            held: dict[str, any] = blocks[at];
            if delta.get("type", "") == "text_delta" {
                piece = str(delta["text"]);
                held["text"] = str(held.get("text", "")) + piece;
                yield ByEvent(kind=ByEventKind.TEXT, text=piece);
            } elif delta.get("type", "") == "input_json_delta" {
                inputs[at] = inputs[at] + str(delta["partial_json"]);
            } elif delta.get("type", "") == "thinking_delta" {
                held["thinking"] = str(held.get("thinking", "")) + str(delta["thinking"]);
            } elif delta.get("type", "") == "signature_delta" {
                held["signature"] = str(held.get("signature", "")) + str(delta["signature"]);
            }
        } elif kind == "content_block_stop" {
            at = int(event["index"]);
            if at in inputs {
                made: dict[str, any] = blocks[at];
                made["input"] = json.loads(inputs[at]) if inputs[at] != "" else {};
            }
        } elif kind == "message_delta" {
            change: dict[str, any] = event.get("delta", {}) or {};
            for (k, v) in change.items() {
                message[k] = v;
            }
            more: dict[str, any] = event.get("usage", {}) or {};
            for (k, v) in more.items() {
                used[k] = v;
            }
        } elif kind == "error" {
            failed: dict[str, any] = event.get("error", {}) or {};
            raise ByError("the model's API failed: " + str(failed.get("message", failed)));
        } elif kind == "message_stop" {
            break;
        }
    }
    message["content"] = blocks;
    message["usage"] = used;
    yield ByEvent(kind=ByEventKind.DONE, value=message);
}

impl Anthropic.ask(request: ModelRequest) -> Iterator[ByEvent] {
    system = request.system;
    wrapped = strict_result(request.result_schema) if request.result_schema is not None else None;
    if wrapped is None and not request.live {
        system += " Reply with only a JSON value, with no other text.";
    }
    body: dict[str, any] = {
        "model": self.model,
        "max_tokens": request.max_tokens,
        "system": [{"type": "text", "text": system, "cache_control": {"type": "ephemeral"}}],
        "messages": [api_message(m) for m in request.messages],
        "fallbacks": "default",
    };
    output: dict[str, any] = {};
    if request.effort != Effort.DEFAULT {
        output["effort"] = request.effort.value;
    }
    if wrapped is not None {
        output["format"] = {"type": "json_schema", "schema": wrapped};
    }
    if len(output) > 0 {
        body["output_config"] = output;
    }
    if len(request.tools) > 0 {
        body["tools"] = [
            {"name": t.name, "description": t.doc, "input_schema": t.schema}
            for t in request.tools
        ];
        if request.answer_now {
            body["tool_choice"] = {"type": "none"};
        }
    }
    reply: dict[str, any] = {};
    if request.live {
        body["stream"] = True;
        with self.post(body) as r {
            for event in self.read_events(r) {
                if event.kind == ByEventKind.DONE {
                    reply = event.value;
                } else {
                    yield event;
                }
            }
        }
    } else {
        with self.post(body) as r {
            reply = json.loads(r.read().decode("utf-8"));
        }
    }
    said = reply_message(reply);
    if wrapped is not None {
        for p in said.parts {
            if p.kind == PartKind.TEXT and p.text.strip().startswith("{") {
                try {
                    holder: dict[str, any] = json.loads(p.text);
                    if "result" in holder {
                        p.text = json.dumps(holder["result"]);
                    }
                } except ValueError {}
            }
        }
    }
    reason = str(reply.get("stop_reason", ""));
    stop = Stop.END;
    if reason == "refusal" {
        stop = Stop.REFUSED;
    } elif reason == "max_tokens" {
        stop = Stop.MAX_TOKENS;
    } elif reason == "tool_use" {
        stop = Stop.TOOLS;
    }
    used = usage_of(reply, self.model);
    used.cost = cost_of(used, self.rates);
    yield ByEvent(kind=ByEventKind.DONE, value=ModelReply(message=said, stop=stop, usage=used));
}
