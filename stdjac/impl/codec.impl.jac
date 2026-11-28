impl CodecError.__str__ -> str {
    return f"{self.path}: {self.detail}" if self.path != "" else self.detail;
}

impl encode[T](v: T) -> any {
    comptime if sendable(T) {
        return encode_sent[T](v);
    } else {
        comptime assert False, "the codec sends only what is sendable: no `any`, function value, "
            "Shared object or other type whose values are not their own";
        raise CodecError(detail="not sendable");
    }
}

impl encode_sent[T](v: T) -> any {
    comptime k = kind(T);
    comptime if nullable(T) {
        if v is None {
            return None;
        }
    }
    comptime if k == Kind.INT and (T == i128 or T == u128) {
        return str(v);
    } elif k == Kind.BYTES or k == Kind.BYTEARRAY {
        return v.hex();
    } elif k == Kind.INT or k == Kind.FLOAT or k == Kind.STR or k == Kind.BOOL {
        return v;
    } elif k == Kind.NONE {
        return None;
    } elif k == Kind.ENUM {
        return v.name;
    } elif k == Kind.LIST or k == Kind.SET {
        return encode_items[T](v);
    } elif k == Kind.TUPLE {
        return encode_tuple[T](v);
    } elif k == Kind.DICT {
        return encode_dict[T](v);
    } elif k == Kind.UNION {
        comptime args = type_args(T);
        comptime assert len(args) == 2
            and (
                kind(args[0]) == Kind.NONE or kind(args[1]) == Kind.NONE
            ), "the codec takes a union of one type and None";
        if v is None {
            return None;
        }
        comptime for a in args {
            comptime if kind(a) != Kind.NONE {
                return encode[a](v);
            }
        }
    } elif k == Kind.NODE or k == Kind.EDGE {
        return encode_kept[T](v);
    } elif k == Kind.OBJ or k == Kind.WALKER {
        return encode_object[T](v);
    } elif k == Kind.STRUCT {
        return encode_struct[T](v);
    } elif k == Kind.COMPLEX {
        return [v.real, v.imag];
    } elif k == Kind.ARRAY {
        return encode_array[T](v);
    } else {
        comptime assert False, "the codec has no JSON form for this type";
        raise CodecError(detail="no JSON form");
    }
}

impl decode[T](v: any) -> T {
    comptime if sendable(T) {
        return decode_sent[T](v);
    } else {
        comptime assert False, "the codec sends only what is sendable: no `any`, function value, "
            "Shared object or other type whose values are not their own";
        raise CodecError(detail="not sendable");
    }
}

impl decode_sent[T](v: any) -> T {
    comptime k = kind(T);
    comptime if nullable(T) {
        if v is None {
            return None;
        }
    }
    comptime if k == Kind.INT and (T == i128 or T == u128) {
        return decode_wide[T](v);
    } elif k == Kind.BYTES or k == Kind.BYTEARRAY {
        return decode_bytes[T](v);
    } elif k == Kind.INT {
        if isinstance(v, int) and not isinstance(v, bool) {
            return v;
        }
        raise CodecError(detail=f"expected an int, got {v!r}");
    } elif k == Kind.FLOAT {
        if isinstance(v, float) {
            return v;
        }
        if isinstance(v, int) and not isinstance(v, bool) {
            return T(float(v));
        }
        raise CodecError(detail=f"expected a float, got {v!r}");
    } elif k == Kind.STR {
        if isinstance(v, str) {
            return v;
        }
        raise CodecError(detail=f"expected a str, got {v!r}");
    } elif k == Kind.BOOL {
        if isinstance(v, bool) {
            return v;
        }
        raise CodecError(detail=f"expected a bool, got {v!r}");
    } elif k == Kind.NONE {
        if v is None {
            return None;
        }
        raise CodecError(detail=f"expected None, got {v!r}");
    } elif k == Kind.ENUM {
        if isinstance(v, str) {
            comptime for m in members(T) {
                if v == m.name {
                    return m;
                }
            }
        }
        raise CodecError(detail=f"expected a member's name, got {v!r}");
    } elif k == Kind.LIST or k == Kind.SET {
        return decode_items[T](v);
    } elif k == Kind.TUPLE {
        return decode_tuple[T](v);
    } elif k == Kind.DICT {
        return decode_dict[T](v);
    } elif k == Kind.UNION {
        comptime args = type_args(T);
        comptime assert len(args) == 2
            and (
                kind(args[0]) == Kind.NONE or kind(args[1]) == Kind.NONE
            ), "the codec takes a union of one type and None";
        if v is None {
            return None;
        }
        comptime for a in args {
            comptime if kind(a) != Kind.NONE {
                return decode[a](v);
            }
        }
    } elif k == Kind.NODE or k == Kind.EDGE {
        return decode_kept[T](v);
    } elif k == Kind.OBJ or k == Kind.WALKER {
        return decode_object[T](v);
    } elif k == Kind.STRUCT {
        return decode_struct[T](v);
    } elif k == Kind.COMPLEX {
        return decode_complex(v);
    } elif k == Kind.ARRAY {
        return decode_array[T](v);
    } else {
        comptime assert False, "the codec has no JSON form for this type";
        raise CodecError(detail="no JSON form");
    }
}

impl decode_bytes[T](v: any) -> T {
    if isinstance(v, str) {
        text: str = v;
        if len(text) % 2 == 0 and all([c in "0123456789abcdefABCDEF" for c in text]) {
            return T(bytes.fromhex(text));
        }
    }
    raise CodecError(detail=f"expected bytes in hex, got {v!r}");
}

impl decode_wide[T](v: any) -> T {
    if not isinstance(v, str) {
        raise CodecError(detail=f"expected a 128-bit int's digits, got {v!r}");
    }
    text: str = v;
    neg = text.startswith("-");
    digits = text[1:] if neg else text;
    if digits == "" or not digits.isdigit() or not digits.isascii() {
        raise CodecError(detail=f"expected a 128-bit int's digits, got {v!r}");
    }
    w = T(0);
    try {
        for ch in digits {
            w = w * T(10) + T(ord(ch) - 48) if not neg else w * T(10) - T(ord(ch) - 48);
        }
    } except OverflowError {
        raise CodecError(detail=f"expected a 128-bit int's digits, got {v!r}");
    }
    return w;
}

impl encode_items[T](v: T) -> list[any] {
    comptime E = type_args(T)[0];
    out: list[any] = [];
    for x in v {
        out.append(encode[E](x));
    }
    return out;
}

impl encode_tuple[T](v: T) -> list[any] {
    out: list[any] = [];
    comptime if variadic(T) {
        comptime E = type_args(T)[0];
        for x in v {
            out.append(encode[E](x));
        }
    } else {
        comptime for i in range(len(type_args(T))) {
            out.append(encode[type_args(T)[i]](v[i]));
        }
    }
    return out;
}

impl encode_dict[T](v: T) -> any {
    comptime K = type_args(T)[0];
    comptime V = type_args(T)[1];
    comptime if kind(K) == Kind.STR {
        d: dict[str, any] = {};
        for (key, x) in v.items() {
            d[key] = encode[V](x);
        }
        return d;
    } else {
        pairs: list[any] = [];
        for (key, x) in v.items() {
            pairs.append([encode[K](key), encode[V](x)]);
        }
        return pairs;
    }
}

impl written_as[T] -> str {
    comptime k = kind(T);
    comptime if k == Kind.LIST
        or k == Kind.SET
        or k == Kind.DICT
        or k == Kind.TUPLE
        or k == Kind.UNION
        or k == Kind.ARRAY
    {
        parts: list[str] = [];
        comptime for a in type_args(T) {
            parts.append(written_as[a]());
        }
        return k.name + "[" + ",".join(parts) + "]";
    } else {
        return k.name;
    }
}

impl shape_of[T] -> str {
    parts: list[str] = [];
    comptime for f in fields(T) {
        comptime if f.has_default {
            parts.append(f.name + "?:" + written_as[f.type]());
        } else {
            parts.append(f.name + ":" + written_as[f.type]());
        }
    }
    return ";".join(parts);
}

impl fill_object[T](into: T, v: any) {
    now = decode_object[T](v);
    comptime for f in fields(T) {
        set_field(into, f.name, get_field(now, f.name));
    }
}

impl encode_object[T](v: T) -> any {
    if v is None {
        return None;
    }
    if type(v) is not T {
        raise CodecError(
            detail=f"expected exactly the class its type names, got a {type(v).__name__}"
        );
    }
    d: dict[str, any] = {};
    comptime for f in fields(T) {
        d[f.name] = encode[f.type](get_field(v, f.name));
    }
    return d;
}

impl encode_struct[T](v: T) -> dict[str, any] {
    d: dict[str, any] = {};
    comptime for f in fields(T) {
        d[f.name] = encode[f.type](get_field(v, f.name));
    }
    return d;
}

impl encode_array[T](v: T) -> list[any] {
    comptime E = type_args(T)[0];
    out: list[any] = [];
    for i in range(len(v)) {
        out.append(encode[E](v[i]));
    }
    return out;
}

impl decode_complex(v: any) -> complex {
    if not isinstance(v, list) {
        raise CodecError(detail=f"expected a list, got {v!r}");
    }
    items: list[any] = v;
    if len(items) != 2 {
        raise CodecError(detail=f"expected 2 items, got {len(items)}");
    }
    parts: list[float] = [];
    for (i, x) in enumerate(items) {
        try {
            parts.append(decode[float](x));
        } except CodecError as e {
            raise CodecError(detail=e.detail, path=f"[{i}]{e.path}");
        }
    }
    return complex(parts[0], parts[1]);
}

impl decode_array[T](v: any) -> T {
    comptime E = type_args(T)[0];
    out = restore(T);
    if not isinstance(v, list) {
        raise CodecError(detail=f"expected a list, got {v!r}");
    }
    items: list[any] = v;
    if len(items) != len(out) {
        raise CodecError(detail=f"expected {len(out)} items, got {len(items)}");
    }
    for (i, x) in enumerate(items) {
        try {
            out[i] = decode[E](x);
        } except CodecError as e {
            raise CodecError(detail=e.detail, path=f"[{i}]{e.path}");
        }
    }
    return out;
}

impl decode_items[T](v: any) -> T {
    comptime E = type_args(T)[0];
    if not isinstance(v, list) {
        raise CodecError(detail=f"expected a list, got {v!r}");
    }
    items: list[any] = v;
    comptime if kind(T) == Kind.LIST {
        out: T = [];
        for (i, x) in enumerate(items) {
            try {
                out.append(decode[E](x));
            } except CodecError as e {
                raise CodecError(detail=e.detail, path=f"[{i}]{e.path}");
            }
        }
        return out;
    } else {
        made: T = set();
        for (i, x) in enumerate(items) {
            try {
                made.add(decode[E](x));
            } except CodecError as e {
                raise CodecError(detail=e.detail, path=f"[{i}]{e.path}");
            }
        }
        return made;
    }
}

impl decode_tuple[T](v: any) -> T {
    if not isinstance(v, list) {
        raise CodecError(detail=f"expected a list, got {v!r}");
    }
    items: list[any] = v;
    parts: list[any] = [];
    comptime if variadic(T) {
        comptime E = type_args(T)[0];
        for (i, x) in enumerate(items) {
            try {
                parts.append(decode[E](x));
            } except CodecError as e {
                raise CodecError(detail=e.detail, path=f"[{i}]{e.path}");
            }
        }
    } else {
        comptime n = len(type_args(T));
        if len(items) != n {
            raise CodecError(detail=f"expected {n} items, got {len(items)}");
        }
        comptime for i in range(n) {
            try {
                parts.append(decode[type_args(T)[i]](items[i]));
            } except CodecError as e {
                raise CodecError(detail=e.detail, path=f"[{i}]{e.path}");
            }
        }
    }
    made: any = tuple(parts);
    return made;
}

impl variadic(t: any) -> bool {
    args = type_args(t);
    if len(args) != 1 {
        return False;
    }
    e = args[0];
    return t == tuple[e, ...];
}

impl decode_dict[T](v: any) -> T {
    comptime K = type_args(T)[0];
    comptime V = type_args(T)[1];
    d: T = {};
    comptime if kind(K) == Kind.STR {
        if not isinstance(v, dict) {
            raise CodecError(detail=f"expected an object, got {v!r}");
        }
        src: dict[any, any] = v;
        for (key, x) in src.items() {
            if not isinstance(key, str) {
                raise CodecError(detail=f"expected a str key, got {key!r}");
            }
            try {
                d[key] = decode[V](x);
            } except CodecError as e {
                raise CodecError(detail=e.detail, path=f".{key}{e.path}");
            }
        }
    } else {
        if not isinstance(v, list) {
            raise CodecError(detail=f"expected a list of [key, value] pairs, got {v!r}");
        }
        items: list[any] = v;
        for (i, p) in enumerate(items) {
            if not isinstance(p, list) {
                raise CodecError(detail=f"expected a [key, value] pair, got {p!r}", path=f"[{i}]");
            }
            pair: list[any] = p;
            if len(pair) != 2 {
                raise CodecError(detail=f"expected a [key, value] pair, got {p!r}", path=f"[{i}]");
            }
            try {
                d[decode[K](pair[0])] = decode[V](pair[1]);
            } except CodecError as e {
                raise CodecError(detail=e.detail, path=f"[{i}]{e.path}");
            }
        }
    }
    return d;
}

impl decode_object[T](v: any) -> T {
    if v is None {
        return None;
    }
    if not isinstance(v, dict) {
        raise CodecError(detail=f"expected an object, got {v!r}");
    }
    src: dict[str, any] = v;
    o = restore(T);
    comptime for f in fields(T) {
        comptime if f.has_default {
            if f.name in src {
                try {
                    set_field(o, f.name, decode[f.type](src[f.name]));
                } except CodecError as e {
                    raise CodecError(detail=e.detail, path=f".{f.name}{e.path}");
                }
            }
        } else {
            if f.name not in src {
                raise CodecError(detail=f"missing field '{f.name}'");
            }
            try {
                set_field(o, f.name, decode[f.type](src[f.name]));
            } except CodecError as e {
                raise CodecError(detail=e.detail, path=f".{f.name}{e.path}");
            }
        }
    }
    return o;
}

impl decode_struct[T](v: any) -> T {
    if not isinstance(v, dict) {
        raise CodecError(detail=f"expected an object, got {v!r}");
    }
    src: dict[str, any] = v;
    o = restore(T);
    comptime for f in fields(T) {
        comptime if f.has_default {
            if f.name in src {
                try {
                    set_field(o, f.name, decode[f.type](src[f.name]));
                } except CodecError as e {
                    raise CodecError(detail=e.detail, path=f".{f.name}{e.path}");
                }
            }
        } else {
            if f.name not in src {
                raise CodecError(detail=f"missing field '{f.name}'");
            }
            try {
                set_field(o, f.name, decode[f.type](src[f.name]));
            } except CodecError as e {
                raise CodecError(detail=e.detail, path=f".{f.name}{e.path}");
            }
        }
    }
    return o;
}

impl encode_kept[T](v: T) -> any {
    if v is None {
        return None;
    }
    d: dict[str, any] = encode_object[T](v);
    d["__jid"] = jid(v);
    return d;
}

impl decode_kept[T](v: any) -> T {
    o = decode_object[T](v);
    if o is None {
        return None;
    }
    src: dict[str, any] = v;
    if "__jid" in src {
        given = src["__jid"];
        if not isinstance(given, str) or not rt_jid_restore(o, given) {
            raise CodecError(detail=f"expected a jid, got {given!r}", path=".__jid");
        }
    }
    return o;
}

impl declares_reports[W] -> bool {
    comptime for f in fields(W) {
        comptime if f.name == "reports" {
            return True;
        }
    }
    return False;
}

impl each_held[T, F](v: T, found: Callable[[F], None]) {
    comptime if holds(T, F) {
        comptime k = kind(T);
        comptime if nullable(T) {
            if v is None {
                return;
            }
        }
        comptime if T == F {
            if v is not None {
                found(v);
            }
        } elif k == Kind.UNION {
            if v is None {
                return;
            }
            comptime for a in type_args(T) {
                comptime if kind(a) != Kind.NONE {
                    each_held[a, F](v, found);
                }
            }
        } elif k == Kind.LIST or k == Kind.SET {
            comptime E = type_args(T)[0];
            for x in v {
                each_held[E, F](x, found);
            }
        } elif k == Kind.ARRAY {
            comptime E = type_args(T)[0];
            for i in range(len(v)) {
                each_held[E, F](v[i], found);
            }
        } elif k == Kind.TUPLE {
            comptime if variadic(T) {
                comptime E = type_args(T)[0];
                for x in v {
                    each_held[E, F](x, found);
                }
            } else {
                comptime for i in range(len(type_args(T))) {
                    each_held[type_args(T)[i], F](v[i], found);
                }
            }
        } elif k == Kind.DICT {
            comptime K = type_args(T)[0];
            comptime V = type_args(T)[1];
            for (key, x) in v.items() {
                each_held[K, F](key, found);
                each_held[V, F](x, found);
            }
        } elif k == Kind.STRUCT {
            comptime for f in fields(T) {
                each_held[f.type, F](get_field(v, f.name), found);
            }
        } else {
            if v is None {
                return;
            }
            comptime for f in fields(T) {
                each_held[f.type, F](get_field(v, f.name), found);
            }
        }
    }
}

impl each_sent[T, F](v: T, sent: any, found: Callable[[F, dict[str, any]], None]) {
    comptime if holds(T, F) {
        comptime k = kind(T);
        comptime if nullable(T) {
            if v is None {
                return;
            }
        }
        comptime if T == F {
            if v is not None and isinstance(sent, dict) {
                was: dict[str, any] = sent;
                found(v, was);
            }
        } elif k == Kind.UNION {
            if v is None {
                return;
            }
            comptime for a in type_args(T) {
                comptime if kind(a) != Kind.NONE {
                    each_sent[a, F](v, sent, found);
                }
            }
        } elif k == Kind.LIST or k == Kind.SET {
            comptime E = type_args(T)[0];
            if isinstance(sent, list) {
                items: list[any] = sent;
                n = 0;
                for x in v {
                    each_sent[E, F](x, items[n], found);
                    n += 1;
                }
            }
        } elif k == Kind.ARRAY {
            comptime E = type_args(T)[0];
            if isinstance(sent, list) {
                items: list[any] = sent;
                for i in range(len(v)) {
                    each_sent[E, F](v[i], items[i], found);
                }
            }
        } elif k == Kind.TUPLE {
            if isinstance(sent, list) {
                items: list[any] = sent;
                comptime if variadic(T) {
                    comptime E = type_args(T)[0];
                    n = 0;
                    for x in v {
                        each_sent[E, F](x, items[n], found);
                        n += 1;
                    }
                } else {
                    comptime for i in range(len(type_args(T))) {
                        each_sent[type_args(T)[i], F](v[i], items[i], found);
                    }
                }
            }
        } elif k == Kind.DICT {
            comptime K = type_args(T)[0];
            comptime V = type_args(T)[1];
            comptime if kind(K) == Kind.STR {
                if isinstance(sent, dict) {
                    members_sent: dict[str, any] = sent;
                    for (key, x) in v.items() {
                        each_sent[V, F](x, members_sent[key], found);
                    }
                }
            } else {
                if isinstance(sent, list) {
                    pairs: list[any] = sent;
                    n = 0;
                    for (key, x) in v.items() {
                        pair: list[any] = pairs[n];
                        each_sent[K, F](key, pair[0], found);
                        each_sent[V, F](x, pair[1], found);
                        n += 1;
                    }
                }
            }
        } elif k == Kind.STRUCT {
            if isinstance(sent, dict) {
                fields_sent: dict[str, any] = sent;
                comptime for f in fields(T) {
                    each_sent[f.type, F](get_field(v, f.name), fields_sent[f.name], found);
                }
            }
        } elif v is not None and isinstance(sent, dict) {
            fields_sent: dict[str, any] = sent;
            comptime for f in fields(T) {
                each_sent[f.type, F](get_field(v, f.name), fields_sent[f.name], found);
            }
        }
    }
}
