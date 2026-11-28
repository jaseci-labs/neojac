impl bound(abstraction: str, offers: Callable[[], Offers] | None = None) -> any {
    if abstraction in _made {
        return _made[abstraction];
    }
    if offers is None {
        raise RuntimeError(f"this program was built with no plugin for `{abstraction}`");
    }
    o = offers();
    want = o.named;
    for name in o.variables {
        picked = os.environ.get(name, "");
        if picked == "" {
            continue;
        }
        if picked not in o.listed {
            sys.stderr.write(
                f"{name}={picked}: this program was not built with a plugin '{picked}' for "
                f"`{abstraction}`, only with: {', '.join(o.listed)}\n",
            );
            sys.exit(1);
        }
        want = picked;
        break;
    }
    made = o.makers[o.listed.index(want)]();
    _made[abstraction] = made;
    return made;
}

impl settle[T](x: T, variables: list[str]) -> T {
    comptime for f in fields(T) {
        comptime if not f.postinit {
            got = given(variables, f.name);
            if got is not None {
                comptime if f.type == Secret {
                    set_field(x, f.name, Secret(variable=got[0]));
                } elif kind(f.type) == Kind.STR {
                    set_field(x, f.name, got[1]);
                } else {
                    try {
                        set_field(x, f.name, decode[f.type](json.loads(got[1])));
                    } except Exception as e {
                        unfit(got, f.name, e);
                    }
                }
            }
        }
    }
    return x;
}

impl give_settings[S](settings: S, plugin: S) {
    comptime for f in fields(S) {
        comptime if not f.postinit {
            set_field(plugin, f.name, get_field(settings, f.name));
        }
    }
}

impl given(variables: list[str], field: str) -> tuple[str, str] | None {
    for prefix in variables {
        name = prefix + "_" + field.upper();
        raw = os.environ.get(name, None);
        if raw is not None {
            return (name, raw);
        }
    }
    return None;
}

impl unfit(got: tuple[str, str], field: str, why: Exception) {
    sys.stderr.write(f"{got[0]}={got[1]}: not a value of the setting `{field}`: {why}\n");
    sys.exit(1);
}
