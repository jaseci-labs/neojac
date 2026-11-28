impl page -> JsxPage {
    has view: str = "",
        said: str = "",
        told: bool = False,
        asks: any = None,
        given: dict[str, str] = {},
        name: str = "",
        code: str = new(URLSearchParams, window.location.search).get("code") or "",
        ended: str = "";

    host = window.location.host;

    async def account -> any {
        try {
            return await signed_in_account();
        } except RemoteError {
            return None;
        }
    }

    async def decide(me: any) {
        name = me.name;
        said = "";
        view = "decide";
    }

    async def begin {
        me = await account();
        if me is not None {
            await decide(me);
            return;
        }
        try {
            got = await sign_in_asks();
        } except RemoteError as e {
            ended = "Signing in is not possible now: " + reason(e) + ".";
            view = "ended";
            return;
        }
        if got is None {
            now = await account();
            if now is not None {
                await decide(now);
            }
            return;
        }
        if len(got.fields) == 0 and len(got.actions) == 0 {
            if got.redirect {
                await sign_in();
                return;
            }
            ended = "This app offers no way of signing in.";
            view = "ended";
            return;
        }
        asks = got;
        given = {};
        said = "";
        told = False;
        view = "form";
        window.setTimeout(
            lambda {
                box = document.querySelector("main input");
                if box is not None {
                    box.focus();
                }
            },
            0,
        );
    }

    async def run(action: any) {
        try {
            named = [f.name for f in asks.fields];
            await sign_in_with(
                action, {need: given.get(need, "") for need in action.needs if need in named}
            );
        } except RemoteError as e {
            told = False;
            said = reason(e);
            return;
        }
        await begin();
    }

    async def press(e: any, k: int) {
        e.preventDefault();
        await run(asks.actions[k]);
    }

    async def submit(e: any) {
        e.preventDefault();
        if len(asks.actions) > 0 {
            await run(asks.actions[0]);
        }
    }

    async def forgot {
        try {
            await forgot_password(given.get(asks.forgot, ""));
        } except RemoteError as e {
            told = False;
            said = reason(e);
            return;
        }
        told = True;
        said = "If an account has that name or address, a link to set a new password was mailed to "
            "it.";
    }

    async def leave {
        try {
            await sign_out();
        } except RemoteError {}
        await begin();
    }

    async def answer(allow: bool) {
        try {
            await device_sign_in(code, allow);
        } except RemoteError as e {
            said = reason(e);
            return;
        }
        ended = "The program is signed in as " + name + ". You can close this page."
            if allow
            else "The program was turned away. You can close this page.";
        view = "ended";
    }

    async can with entry {
        document.title = "Sign in a program";
        await begin();
    }

    return <main>
        <h1>Sign in a program</h1>
        {<p>{ended}</p> if view == "ended" else None}
        {<>
            <p>
                {"Sign in to " + host + " first. You are then asked whether the program is yours."}
            </p>
            <form onSubmit={submit}>
                {[
                    <label>
                        {f.label or f.name}
                        <input
                            name={f.name}
                            type={"password" if f.secret else "text"}
                            autocapitalize="none"
                            onInput={lambda (e: any) { given = {**given, f.name: e.target.value}; }}
                        />
                    </label>
                    for f in asks.fields
                ]}
                <Said text={said} told={told} />
                <div class="row">
                    {[
                        <button
                            type={"submit" if k == 0 else "button"}
                            onClick={lambda (e: any) { press(e, k) }}
                        >{asks.actions[k].label or asks.actions[k].name}</button>
                        for k in range(len(asks.actions))
                    ]}
                </div>
                {<button
                    class="forgot"
                    type="button"
                    onClick={forgot}
                >Forgot your password?</button>
                    if asks.forgot
                    else None}
            </form>
        </>
            if view == "form"
            else None}
        {<>
            <div class="who">
                <span>{"Signed in to " + host + " as " + name}</span>
                <button type="button" onClick={leave}>Sign out</button>
            </div>
            <p>
                A program is waiting to be signed in as you. Sign it in only if you started it
                yourself, and the code it shows is the one here. If someone sent you this page, turn
                it away: whoever holds the program would be you.
            </p>
            <label>
                The code the program shows
                <input
                    class="code"
                    value={code}
                    autocomplete="off"
                    spellcheck="false"
                    onInput={lambda (e: any) { code = e.target.value; }}
                /></label>
            <Said text={said} />
            <div class="row">
                <button type="button" onClick={lambda { answer(False) }}>Turn it away</button>
                <button type="button" onClick={lambda { answer(True) }}>Sign it in</button>
            </div>
        </>
            if view == "decide"
            else None}
    </main>;
}
