impl model -> dyn Model {
    if len(_model) == 0 {
        m: dyn Model = bound("llm");
        m.open(host());
        _model.append(m);
    }
    return _model[0];
}

impl on_usage(f: Callable[[ByUsage], None]) {
    _usage_hooks.append(f);
}

impl llm(
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
) -> LLM {
    return LLM(
        max_tokens=max_tokens,
        effort=effort,
        max_react_iterations=max_react_iterations,
        max_output_retries=max_output_retries,
        tools=tools,
        on_iteration=on_iteration,
        system_prompt=system_prompt,
        conversation=conversation,
        select=select,
        intent=intent,
        media=media,
    );
}

impl media_parts(given: any) -> list[Part] {
    out: list[Part] = [];
    if given is None {
        return out;
    }
    for v in (given if isinstance(given, list) else [given]) {
        ctype = "";
        data = b"";
        if isinstance(v, bytes) {
            data = v;
            for (t, head) in MEDIA_BEGINS.items() {
                if data.startswith(head) {
                    ctype = t;
                }
            }
        } elif hasattr(v, "ctype") and hasattr(v, "read") {
            data = v.read();
            ctype = str(v.ctype);
        }
        if ctype not in MEDIA_BEGINS {
            raise ByError(
                "media is a File or bytes of a PNG, JPEG, GIF or WebP image or a PDF, and this is "
                    + (ctype if ctype != "" else type(v).__name__),
            );
        }
        out.append(Part(kind=PartKind.MEDIA, data=data, ctype=ctype));
    }
    return out;
}

impl kept_message(m: Message) -> Message {
    return Message(role=m.role, parts=[p for p in m.parts if p.kind != PartKind.KEPT]);
}

impl opens_turn(m: Message) -> bool {
    return m.role == "user" and not any([p.kind == PartKind.TOOL_RESULT for p in m.parts]);
}

impl latest_turns(history: list[Message], most: int) -> list[Message] {
    cut = len(history);
    used = 0;
    for i in range(len(history) - 1, -1, -1) {
        m = history[i];
        used += sum([len(p.text) + len(p.input) + len(p.name) for p in m.parts]);
        if not opens_turn(m) {
            continue;
        }
        if used > most and cut < len(history) {
            break;
        }
        cut = i;
    }
    return history[cut:];
}

impl LLM.answer(call: ByCall, live: bool) -> Iterator[ByEvent] {
    system = call.doc;
    for k in call.arg_docs.keys() {
        system += "\n" + k + ": " + call.arg_docs[k];
    }
    if self.system_prompt != "" {
        system = self.system_prompt + "\n\n" + system;
    }
    system += "\n\nThe user message holds the arguments, as JSON.";
    kept = self.conversation;
    before: list[Message] = list(kept) if kept is not None else [];
    turn: list[Message] = [
        Message(
            role="user",
            parts=[Part(kind=PartKind.TEXT, text=json.dumps(call.args))] + media_parts(self.media),
        ),
    ];
    tools: list[ModelTool] = [];
    named: dict[str, ByTool] = {};
    for t in self.tools {
        named[t.name] = t;
        tools.append(ModelTool(name=t.name, doc=t.doc, schema=t.schema));
    }
    asked = model();
    total = ByUsage();
    whole = "";
    tries = 0;
    steps = 0;
    finish = False;
    ended = ByEnd.ANSWERED;
    while True {
        began = time.time();
        got: ModelReply | None = None;
        for event in asked.ask(
            ModelRequest(
                system=system,
                messages=before + turn,
                tools=tools,
                result_schema=None if live else call.result_schema,
                max_tokens=self.max_tokens,
                effort=self.effort,
                answer_now=finish,
                live=live,
            ),
        ) {
            if event.kind == ByEventKind.DONE {
                got = event.value;
            } elif live {
                yield event;
            }
        }
        if got is None {
            raise ByError(call.name + ": the model gave no reply");
        }
        reply: ModelReply = got;
        used = reply.usage;
        used.requests = 1;
        used.seconds = time.time() - began;
        total.add(used);
        for hook in _usage_hooks {
            hook(used);
        }
        yield ByEvent(kind=ByEventKind.USAGE, usage=used);
        if reply.stop == Stop.REFUSED {
            raise ByError(call.name + ": the model declined this request");
        }
        said = reply.message;
        text = "".join([p.text for p in said.parts if p.kind == PartKind.TEXT]);
        whole += text;
        uses = [p for p in said.parts if p.kind == PartKind.TOOL_CALL];
        if len(uses) > 0 {
            for u in uses {
                given: any = json.loads(u.input) if u.input != "" else {};
                yield ByEvent(
                    kind=ByEventKind.TOOL_CALL,
                    tool=u.name,
                    call_id=u.id,
                    args=given if isinstance(given, dict) else {},
                );
            }
            results = self.run_tools(named, uses);
            for (u, r) in zip(uses, results) {
                yield ByEvent(
                    kind=ByEventKind.TOOL_RESULT, tool=u.name, call_id=u.id, result=r.text
                );
            }
            turn.append(said);
            turn.append(Message(role="user", parts=results));
            steps += 1;
            if steps >= self.max_react_iterations {
                finish = True;
                ended = ByEnd.ROUNDS;
            } elif self.on_iteration is not None {
                check: Callable[[IterationContext], IterationAction] = self.on_iteration;
                if check(IterationContext(iteration=steps, usage=total))
                    == IterationAction.ABORT_WITH_SUMMARY
                {
                    finish = True;
                    ended = ByEnd.STOPPED;
                }
            }
            continue;
        }
        text = text.strip();
        if live {
            turn.append(said);
            if kept is not None {
                kept.extend([kept_message(m) for m in turn]);
            }
            if reply.stop == Stop.MAX_TOKENS {
                ended = ByEnd.CUT;
            }
            yield ByEvent(kind=ByEventKind.DONE, text=whole, ended=ended);
            return;
        }
        if text.startswith("```") {
            text = text.strip("`").removeprefix("json").strip();
        }
        try {
            if reply.stop == Stop.MAX_TOKENS {
                raise ValueError("the reply ran past max_tokens");
            }
            value: any = json.loads(text);
            result: any = call.decode(value) if call.decode is not None else value;
            turn.append(said);
            if kept is not None {
                kept.extend([kept_message(m) for m in turn]);
            }
            yield ByEvent(kind=ByEventKind.DONE, text=text, ended=ended, value=result);
            return;
        } except Exception as e {
            tries += 1;
            if tries > self.max_output_retries {
                raise ByError(
                    call.name
                        + ": the model's reply doesn't fit its result ("
                        + str(e)
                        + "): "
                        + text[:300],
                );
            }
            turn.append(said);
            turn.append(
                Message(
                    role="user",
                    parts=[
                        Part(
                            kind=PartKind.TEXT,
                            text="That didn't fit: " + str(e) + ". Reply with only the JSON.",
                        ),
                    ],
                ),
            );
        }
    }
}

impl LLM.invoke(call: ByCall) -> any {
    for event in self.answer(call, False) {
        if event.kind == ByEventKind.DONE {
            return event.value;
        }
    }
    raise ByError(call.name + ": the model gave no answer");
}

impl LLM.stream(call: ByCall) -> Iterator[ByEvent] {
    return self.answer(call, True);
}

impl LLM.choose(choice: ByChoice) -> list[int] {
    least = 1;
    most = 1;
    if isinstance(self.select, int) {
        count: int = self.select;
        least = count;
        most = count;
    } elif isinstance(self.select, tuple) {
        bounds: tuple[int, int] = self.select;
        (least, most) = bounds;
    } else {
        raise ByError(
            choice.name + ": select is a number of ways, or a (least, most) pair of them"
        );
    }
    many = len(choice.options);
    most = min(most, many);
    least = min(least, most);
    if many == 0 or most <= 0 {
        return [];
    }
    said = "Choose which of the options a walker moves to next, by their numbers."
        + f" Choose at least {least} and at most {most} of them, the most useful first.";
    if self.intent != "" {
        said += "\nWhat the choice is for: " + self.intent;
    }
    picked: list[int] = self.invoke(
        ByCall(
            name=choice.name,
            doc=said,
            args={"walker": choice.asker, "at": choice.at, "options": choice.options},
            arg_docs={
                "walker": "The walker's own state.",
                "at": "The node the walker is at.",
                "options": "Where it may go: each option's number, the node there, and the edges that lead to it, each with what its type means.",
            },
            result_schema={"type": "array", "items": {"type": "integer"}},
            decode=None,
        ),
    );
    out: list[int] = [];
    for i in picked {
        if isinstance(i, int) and 0 <= i and i < many and i not in out and len(out) < most {
            out.append(i);
        }
    }
    return out;
}

impl LLM.run_tools(named: dict[str, ByTool], uses: list[Part]) -> list[Part] {
    out: list[Part] = [];
    k = 0;
    while k < len(uses) {
        j = k;
        while j < len(uses) and uses[j].name in named and not named[uses[j].name].alone {
            j += 1;
        }
        if j - k >= 2 {
            tasks = [flow self.run_tool(named, u) for u in uses[k:j]];
            out.extend([wait t for t in tasks]);
        } else {
            j = k + 1;
            out.append(self.run_tool(named, uses[k]));
        }
        k = j;
    }
    return out;
}

impl LLM.run_tool(named: dict[str, ByTool], u: Part) -> Part {
    out = Part(kind=PartKind.TOOL_RESULT, id=u.id);
    if u.name not in named {
        out.text = "no such tool";
        out.failed = True;
        return out;
    }
    try {
        given: any = json.loads(u.input) if u.input != "" else {};
        r = named[u.name].call(given);
        out.text = r if isinstance(r, str) else json.dumps(r);
    } except Exception as e {
        out.text = "the tool failed: " + str(e);
        out.failed = True;
    }
    return out;
}
