impl schema[T] -> dict[str, any] {
    comptime if sendable(T) {
        return schema_in[T]([]);
    } else {
        comptime assert False, NO_SCHEMA;
        return {};
    }
}

impl schema_in[T](within: list[any]) -> dict[str, any] {
    comptime k = kind(T);
    comptime if k == Kind.INT {
        return {"type": "integer"};
    } elif k == Kind.FLOAT {
        return {"type": "number"};
    } elif k == Kind.STR {
        return {"type": "string"};
    } elif k == Kind.BOOL {
        return {"type": "boolean"};
    } elif k == Kind.NONE {
        return {"type": "null"};
    } elif k == Kind.ENUM {
        names: list[str] = [];
        meant: list[str] = [];
        comptime for m in members(T) {
            names.append(m.name);
            comptime if m.doc != "" {
                meant.append(m.name + ": " + m.doc);
            }
        }
        return described({"enum": names}, "; ".join(meant));
    } elif k == Kind.LIST or k == Kind.SET {
        comptime E = type_args(T)[0];
        return {"type": "array", "items": schema_in[E](within)};
    } elif k == Kind.DICT {
        comptime assert kind(type_args(T)[0]) == Kind.STR, "a `by` result's dict keys are str";
        comptime V = type_args(T)[1];
        return {"type": "object", "additionalProperties": schema_in[V](within)};
    } elif k == Kind.UNION {
        comptime args = type_args(T);
        comptime assert len(args) == 2
            and (
                kind(args[0]) == Kind.NONE or kind(args[1]) == Kind.NONE
            ), "a `by` result's union is of one type and None";
        options: list[any] = [];
        comptime for a in args {
            options.append(schema_in[a](within));
        }
        return {"anyOf": options};
    } elif k == Kind.OBJ or k == Kind.NODE or k == Kind.STRUCT {
        for c in within {
            if c is T {
                return {"type": "object"};
            }
        }
        return object_schema[T](within + [T]);
    } else {
        comptime assert False, NO_SCHEMA;
        return {};
    }
}

impl object_schema[T](within: list[any]) -> dict[str, any] {
    props: dict[str, any] = {};
    required: list[str] = [];
    comptime for f in fields(T) {
        props[f.name] = described(schema_in[f.type](within), f.doc);
        comptime if not f.has_default {
            required.append(f.name);
        }
    }
    return {"type": "object", "properties": props, "required": required};
}

impl described(schema: dict[str, any], doc: str) -> dict[str, any] {
    if doc == "" {
        return schema;
    }
    out: dict[str, any] = dict(schema);
    out["description"] = doc + " (" + str(schema["description"]) + ")"
        if "description" in schema
        else doc;
    return out;
}

impl by_tool(comptime f: any, name: str) -> ByTool {
    props: dict[str, any] = {};
    required: list[str] = [];
    comptime for p in params(f) {
        props[p.name] = described(schema[p.type](), p.doc);
        comptime if not p.has_default {
            required.append(p.name);
        }
    }
    return ByTool(
        name=name,
        doc=__sem(f),
        schema={"type": "object", "properties": props, "required": required},
        call=lambda (given: dict[str, any]) -> any {
            a = decode[args_type(f)](given);
            return encode(apply(f, a));
        },
        alone=not only_reads(f),
    );
}

impl by_method[T](comptime m: any, target: T, name: str) -> ByTool {
    props: dict[str, any] = {};
    required: list[str] = [];
    comptime for p in params(m) {
        props[p.name] = described(schema[p.type](), p.doc);
        comptime if not p.has_default {
            required.append(p.name);
        }
    }
    return ByTool(
        name=name,
        doc=__sem(m),
        schema={"type": "object", "properties": props, "required": required},
        call=lambda (given: dict[str, any]) -> any {
            a = decode[args_type(m)](given);
            return encode(apply(m, a, target));
        },
        alone=not only_reads(m),
    );
}

impl by_call[R](comptime f: any, name: str, b: dyn By, args: dict[str, any]) -> R {
    arg_docs = docs_of(f, args);
    comptime if sendable(R) {
        out = b.invoke(
            ByCall(
                name=name,
                doc=__sem(f),
                args=args,
                arg_docs=arg_docs,
                result_schema=schema[R](),
                decode=lambda (v: any) -> any { return decode[R](v); },
            ),
        );
        return out;
    } else {
        comptime assert False, NO_SCHEMA;
        raise ByError();
    }
}

impl docs_of(comptime f: any, args: dict[str, any]) -> dict[str, str] {
    arg_docs: dict[str, str] = {};
    comptime for p in params(f) {
        if p.doc != "" and p.name in args {
            arg_docs[p.name] = p.doc;
        }
    }
    return arg_docs;
}

impl by_stream(
    comptime f: any, name: str, b: dyn ByStreams, args: dict[str, any]
) -> Iterator[ByEvent] {
    return b.stream(ByCall(name=name, doc=__sem(f), args=args, arg_docs=docs_of(f, args)));
}

impl by_shown[T](x: T, name: str, means: str) -> dict[str, any] {
    held: dict[str, any] = {};
    docs: dict[str, str] = {};
    comptime for f in fields(T) {
        comptime if sendable(f.type) {
            held[f.name] = encode(get_field(x, f.name));
            if f.doc != "" {
                docs[f.name] = f.doc;
            }
        }
    }
    out: dict[str, any] = {"type": name, "fields": held};
    if means != "" {
        out["means"] = means;
    }
    if len(docs) > 0 {
        out["field_docs"] = docs;
    }
    return out;
}

impl by_way[E](name: str, means: str) -> ByWay {
    return ByWay(
        of=lambda (e: any) -> dict[str, any] | None {
            try {
                way: E = e;
                return by_shown(way, name, means);
            } except TypeError {
                return None;
            }
        },
    );
}

impl by_choose[N: Node](
    chooser: dyn ByChooser,
    name: str,
    asker: dict[str, any],
    at: Node,
    at_shown: dict[str, any],
    kind: str,
    means: str,
    options: list[N],
    ways: list[ByWay],
) -> list[N] {
    if len(options) == 0 {
        return [];
    }
    leaving = [edge at -->];
    shown: list[dict[str, any]] = [];
    for (i, n) in enumerate(options) {
        via: list[dict[str, any]] = [];
        there: Node = n;
        for e in leaving {
            if rt_edge_dst(e) is there {
                for w in ways {
                    said = w.of(e);
                    if said is not None {
                        via.append(said);
                        break;
                    }
                }
            }
        }
        shown.append({"option": i, "node": by_shown(n, kind, means), "edges": via});
    }
    picked = chooser.choose(ByChoice(name=name, asker=asker, at=at_shown, options=shown));
    taken: list[N] = [];
    for i in picked {
        if 0 <= i and i < len(options) and options[i] not in taken {
            taken.append(options[i]);
        }
    }
    return taken;
}
