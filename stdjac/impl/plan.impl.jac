impl plan -> AppPlan {
    if len(_plan) == 0 {
        text = __app_plan();
        _plan.append(arranged(decode[AppPlan](json.loads(text))) if text != "" else AppPlan());
    }
    return _plan[0];
}

impl app_data(p: AppPlan) -> str {
    return os.environ.get(env_name(p.app, "DATA"), p.data_dir);
}

impl data_dir -> str {
    p = plan();
    d = app_data(p);
    return os.path.join(d, p.spaces[0]) if p.carried else d;
}

impl upgraded(what: str) {
    _upgraded.append(what);
}

impl upgrades_made -> list[str] {
    return _upgraded;
}

impl ProgramHost.data_dir -> str {
    return data_dir();
}

impl ProgramHost.upgraded(what: str) {
    upgraded(what);
}

impl ProgramHost.secret(s: Secret) -> str {
    return os.environ.get(s.variable, "");
}

impl host -> ProgramHost {
    return ProgramHost();
}

impl arrangement_file(p: AppPlan) -> str {
    return os.path.join(app_data(p), "arrangement");
}

impl arranged(first: AppPlan) -> AppPlan {
    if len(first.others) == 0 {
        return first;
    }
    held = [first] + first.others;
    want: str = os.environ.get(env_name(first.app, "ARRANGEMENT"), "");
    if want == "" {
        try {
            with open(arrangement_file(first)) as f {
                want = f.read().strip();
            }
        } except OSError {
            want = "";
        }
    }
    picked = first;
    chosen = False;
    for p in held {
        if p.arrangement == want {
            picked = p;
            chosen = True;
        }
    }
    picked.arrangements = [p.arrangement for p in held];
    picked.chosen = chosen;
    return picked;
}

impl keep_arrangement(name: str) {
    p = plan();
    if name not in p.arrangements {
        raise ValueError(
            f"{p.app} has no arrangement '{name}': it may be {', '.join(p.arrangements)}"
        );
    }
    os.makedirs(app_data(p), exist_ok=True);
    with open(arrangement_file(p), "w") as f {
        f.write(name + "\n");
    }
}

impl env_name(app: str, what: str) -> str {
    out = "";
    for ch in ("JAC_" + app + "_" + what).upper() {
        out += ch if ch.isalnum() else "_";
    }
    return out;
}

impl remote_url(space: str) -> str {
    return os.environ.get(env_name("REMOTE", space), plan().remotes.get(space, ""));
}

impl space_code(space: str) -> str {
    code = "";
    for h in plan().hosted {
        if h.space == space {
            code = h.code;
        }
    }
    return os.environ.get(
        env_name(space, "CODE"), os.path.join(os.path.dirname(sys.executable), code)
    );
}
