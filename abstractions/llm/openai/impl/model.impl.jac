impl api_messages(m: Message, pdf_part: str) -> list[dict[str, any]] {
    out: list[dict[str, any]] = [];
    text = "";
    calls: list[any] = [];
    media: list[any] = [];
    kept: dict[str, any] = {};
    for p in m.parts {
        if p.kind == PartKind.TEXT {
            text += p.text;
        } elif p.kind == PartKind.TOOL_CALL {
            calls.append({
                "id": p.id,
                "type": "function",
                "function": {"name": p.name, "arguments": p.input if p.input != "" else "{}"},
            });
        } elif p.kind == PartKind.TOOL_RESULT {
            out.append({"role": "tool", "tool_call_id": p.id, "content": p.text});
        } elif p.kind == PartKind.KEPT {
            kept[p.id] = json.loads(p.text);
        } elif p.kind == PartKind.MEDIA {
            url = "data:" + p.ctype + ";base64," + base64.b64encode(p.data).decode("ascii");
            if p.ctype == "application/pdf" and pdf_part == "file" {
                media.append({"type": "file", "file": {"filename": "file.pdf", "file_data": url}});
            } else {
                media.append({"type": "image_url", "image_url": {"url": url}});
            }
        }
    }
    for c in calls {
        if c["id"] in kept {
            c["extra_content"] = kept[c["id"]];
        }
    }
    if m.role == "assistant" {
        said: dict[str, any] = {"role": "assistant", "content": text};
        if len(calls) > 0 {
            said["tool_calls"] = calls;
        }
        out.append(said);
    } elif len(media) > 0 {
        content: list[any] = [{"type": "text", "text": text}];
        content.extend(media);
        out.append({"role": m.role, "content": content});
    } elif text != "" {
        out.append({"role": m.role, "content": text});
    }
    return out;
}

impl reply_message(m: dict[str, any]) -> Message {
    out = Message(role="assistant");
    content: any = m.get("content", None);
    if isinstance(content, str) and content != "" {
        out.parts.append(Part(kind=PartKind.TEXT, text=content));
    }
    calls: any = m.get("tool_calls", None) or [];
    for c in calls {
        made: dict[str, any] = c.get("function", {}) or {};
        out.parts.append(
            Part(
                kind=PartKind.TOOL_CALL,
                id=str(c.get("id", "")),
                name=str(made.get("name", "")),
                input=str(made.get("arguments", "") or ""),
            ),
        );
        if c.get("extra_content", None) {
            out.parts.append(
                Part(
                    kind=PartKind.KEPT, id=str(c.get("id", "")), text=json.dumps(c["extra_content"])
                ),
            );
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
        out["required"] = list(props.keys());
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

impl stop_of(reason: str, refused: bool) -> Stop {
    if refused or reason == "content_filter" {
        return Stop.REFUSED;
    } elif reason == "length" {
        return Stop.MAX_TOKENS;
    } elif reason == "tool_calls" {
        return Stop.TOOLS;
    }
    return Stop.END;
}

impl usage_of(reply: dict[str, any], model: str) -> ByUsage {
    used: dict[str, any] = reply.get("usage", {}) or {};
    details: dict[str, any] = used.get("prompt_tokens_details", {}) or {};
    cached = int(details.get("cached_tokens", 0) or 0);
    return ByUsage(
        input_tokens=int(used.get("prompt_tokens", 0) or 0) - cached,
        output_tokens=int(used.get("completion_tokens", 0) or 0),
        cache_read_tokens=cached,
        model=str(reply.get("model", model) or model),
    );
}

impl cost_of(used: ByUsage, rates: dict[str, list[float]], asked: str) -> float | None {
    named = used.model if used.model in rates else asked;
    if named not in rates {
        return None;
    }
    rate = rates[named];
    return (
        used.input_tokens * rate[0]
        + used.output_tokens * rate[1]
        + used.cache_read_tokens * rate[2]
        + used.cache_write_tokens * rate[3]
    )
        / 1000000.0;
}

impl OpenAI.postinit {
    self.given_key = "";
}

impl OpenAI.open(host: dyn Host) {
    self.given_key = host.secret(self.key);
    if self.pdf_part != "file" and self.pdf_part != "image_url" {
        raise ByError(
            "[llm.openai] pdf_part is 'file' or 'image_url', not '" + self.pdf_part + "'"
        );
    }
    for (model, rate) in self.rates.items() {
        if len(rate) != 4 {
            raise ByError(
                "[llm.openai] rates: '"
                    + model
                    + "' is given "
                    + str(len(rate))
                    + " numbers, and a rate is four: dollars per million tokens of input, of output, read from the cache and written to it",
            );
        }
    }
}

impl OpenAI.post(body: dict[str, any]) -> any {
    data = json.dumps(body).encode("utf-8");
    headers: dict[str, str] = {"content-type": "application/json", "user-agent": "neojac"};
    if self.given_key != "" {
        headers["authorization"] = "Bearer " + self.given_key;
    }
    attempt = 0;
    while True {
        req = urllib.request.Request(
            self.address.rstrip("/") + "/chat/completions",
            data=data,
            headers=headers,
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

impl OpenAI.read_events(r: any) -> Iterator[ByEvent] {
    model = "";
    text = "";
    refusal = "";
    reason = "";
    calls: list[dict[str, any]] = [];
    at: dict[int, int] = {};
    used: dict[str, any] = {};
    forever {
        line: bytes = r.readline();
        if len(line) == 0 {
            break;
        }
        got = line.decode("utf-8").strip();
        if not got.startswith("data:") {
            continue;
        }
        data = got[5:len(got)].strip();
        if data == "[DONE]" {
            break;
        }
        chunk: dict[str, any] = json.loads(data);
        if "error" in chunk {
            failed: any = chunk["error"];
            said: any = failed.get("message", failed) if isinstance(failed, dict) else failed;
            raise ByError("the model's API failed: " + str(said));
        }
        if chunk.get("model", "") {
            model = str(chunk["model"]);
        }
        if chunk.get("usage", None) {
            used = dict(chunk["usage"]);
        }
        choices: list[any] = chunk.get("choices", None) or [];
        for choice in choices {
            delta: dict[str, any] = choice.get("delta", {}) or {};
            piece: any = delta.get("content", None);
            if isinstance(piece, str) and piece != "" {
                text += piece;
                yield ByEvent(kind=ByEventKind.TEXT, text=piece);
            }
            if isinstance(delta.get("refusal", None), str) {
                refusal += str(delta["refusal"]);
            }
            given: list[any] = delta.get("tool_calls", None) or [];
            for c in given {
                index = int(c.get("index", len(at)));
                if index not in at {
                    at[index] = len(calls);
                    calls.append({
                        "id": "",
                        "type": "function",
                        "function": {"name": "", "arguments": ""},
                    });
                }
                held: dict[str, any] = calls[at[index]];
                if c.get("id", "") {
                    held["id"] = str(c["id"]);
                }
                if c.get("extra_content", None) {
                    held["extra_content"] = c["extra_content"];
                }
                made: dict[str, any] = c.get("function", {}) or {};
                if made.get("name", "") {
                    held["function"]["name"] = str(made["name"]);
                }
                held["function"]["arguments"] = held["function"]["arguments"]
                    + str(made.get("arguments", "") or "");
            }
            if choice.get("finish_reason", None) {
                reason = str(choice["finish_reason"]);
            }
        }
    }
    message: dict[str, any] = {"role": "assistant", "content": text};
    if refusal != "" {
        message["refusal"] = refusal;
    }
    if len(calls) > 0 {
        message["tool_calls"] = calls;
    }
    yield ByEvent(
        kind=ByEventKind.DONE,
        value={
            "model": model,
            "choices": [{"message": message, "finish_reason": reason}],
            "usage": used,
        },
    );
}

impl OpenAI.ask(request: ModelRequest) -> Iterator[ByEvent] {
    system = request.system;
    wrapped = strict_result(request.result_schema) if request.result_schema is not None else None;
    if wrapped is None and not request.live {
        system += " Reply with only a JSON value, with no other text.";
    }
    messages: list[dict[str, any]] = [{"role": "system", "content": system}];
    for m in request.messages {
        messages.extend(api_messages(m, self.pdf_part));
    }
    body: dict[str, any] = {
        "model": self.model,
        "messages": messages,
        "max_completion_tokens": request.max_tokens,
    };
    if request.effort != Effort.DEFAULT {
        body["reasoning_effort"] = request.effort.value;
    }
    if wrapped is not None {
        body["response_format"] = {
            "type": "json_schema",
            "json_schema": {"name": "result", "strict": True, "schema": wrapped},
        };
    }
    if len(request.tools) > 0 {
        body["tools"] = [
            {
                "type": "function",
                "function": {"name": t.name, "description": t.doc, "parameters": t.schema},
            }
            for t in request.tools
        ];
        if request.answer_now {
            body["tool_choice"] = "none";
        }
    }
    reply: dict[str, any] = {};
    if request.live {
        body["stream"] = True;
        body["stream_options"] = {"include_usage": True};
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
    choices: list[any] = reply.get("choices", None) or [];
    if len(choices) == 0 {
        raise ByError("the model's API gave no choice: " + json.dumps(reply));
    }
    choice: dict[str, any] = choices[0];
    message: dict[str, any] = choice.get("message", {}) or {};
    said = reply_message(message);
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
    stop = stop_of(str(choice.get("finish_reason", "") or ""), bool(message.get("refusal", None)));
    used = usage_of(reply, self.model);
    used.cost = cost_of(used, self.rates, self.model);
    yield ByEvent(kind=ByEventKind.DONE, value=ModelReply(message=said, stop=stop, usage=used));
}
