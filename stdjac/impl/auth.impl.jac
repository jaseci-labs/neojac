impl AuthProgram.windowed -> bool {
    return plan().window is not None;
}

impl AuthProgram.consume_limit(scope: str, actor: str, limit: int, seconds: int) -> int {
    return consume_limit(scope, actor, limit, seconds);
}

impl AuthProgram.sends_mail -> bool {
    return mailer().sends();
}

impl AuthProgram.send_mail(to: str, subject: str, text: str) {
    try {
        mailer().send(to, subject, text);
    } except MailNotSent as e {
        sys.stderr.write(f"mail to an account's address was not sent: {e}\n");
    }
}

impl open_auth {
    a: dyn Auth = bound("auth");
    a.open(AuthProgram());
    _auth.append(a);
}

impl address_checked -> bool {
    who = current_caller();
    if who == "" or len(_auth) == 0 {
        return False;
    }
    return _auth[0].checked(who) or not _auth[0].mails();
}

impl auth_caller(headers: dict[str, str]) -> str {
    if len(_auth) == 0 {
        return "";
    }
    who = _auth[0].caller(headers);
    return who if who is not None else "";
}

impl deployment_signed(r: Request) -> bool {
    key = os.environ.get("JAC_DEPLOY_KEY", "");
    given = r.headers.get("x-jac-key", "");
    return key != "" and hmac.compare_digest(given.encode("utf-8"), key.encode("utf-8"));
}

impl asked(a: SignIn) -> dict[str, any] {
    s = a.session;
    return {
        "fields": [
            {"name": f.name, "label": f.label, "secret": f.secret, "choices": f.choices}
            for f in a.fields
        ],
        "actions": [
            {
                "name": x.name,
                "label": x.label,
                "needs": x.needs,
                "redirect": x.redirect,
                "keeps": x.keeps,
            }
            for x in a.actions
        ],
        "redirect": a.redirect,
        "session": signed(s) if s is not None else None,
        "forgot": a.forgot,
    };
}

impl signed(s: Session) -> dict[str, any] {
    return {"user": s.user, "token": s.token, "name": s.name};
}

impl auth_route(r: Request) -> Response | None {
    action = r.path.removeprefix("/__jac/auth").lstrip("/");
    if r.method == "GET" and action not in ["", "me", "logout"] {
        return None;
    }
    if len(_auth) == 0 {
        return json_fail(500, "failed", "no accounts");
    }
    a = _auth[0];
    if r.method == "GET" and action == "" {
        return json_ok(asked(a.asks(r.headers)));
    }
    if action == "me" {
        who = a.caller(r.headers);
        if who is None {
            return json_fail(401, "rejected", "not signed in");
        }
        return json_ok({"user": who, "checked": a.checked(who), "mails": a.mails()});
    }
    if action == "logout" {
        a.leave(r.headers);
        return json_ok(None);
    }
    b: any = None;
    try {
        b = json.loads(r.body.decode("utf-8"));
    } except ValueError {
        b = None;
    }
    if not isinstance(b, dict) {
        return json_fail(400, "rejected", "the request is not a JSON object");
    }
    sent: dict[str, any] = b;
    given: dict[str, str] = {str(k): str(v) for (k, v) in sent.items()};
    try {
        if action == "device" {
            d = a.device(r.client);
            return json_ok({
                "code": d.code,
                "secret": d.secret,
                "page": "/__jac/auth/device?code=" + d.code,
                "lasts": d.lasts,
                "every": d.every,
            });
        }
        if action == "device/allow" or action == "device/refuse" {
            a.device_answer(r.headers, given.get("code", ""), action == "device/allow");
            return json_ok(None);
        }
        if action == "device/session" {
            s = a.device_session(given.get("secret", ""));
            return json_ok(signed(s) if s is not None else None);
        }
        if action == "check/mail" {
            a.mail_check(r.headers, given.get("address", ""));
            return json_ok(None);
        }
        if action == "check" {
            a.check(given.get("token", ""), r.client);
            return json_ok(None);
        }
        if action == "forgot" {
            a.forgot(given.get("name", ""), r.client);
            return json_ok(None);
        }
        if action == "reset" {
            return json_ok(
                signed(a.reset(given.get("token", ""), given.get("password", ""), r.client))
            );
        }
        return json_ok(signed(a.answer(action, given, r.client)));
    } except Rejected as no {
        failed = json_fail(429 if no.retry_after > 0 else 400, "rejected", no.detail);
        if no.retry_after > 0 {
            failed.headers = {"Retry-After": str(no.retry_after)};
        }
        return failed;
    }
}
