impl page -> JsxPage {
    has password: str = "";
    has said: str = "";
    has done: bool = False;
    has box: Ref[any] = Ref(None);

    token = mailed_token();

    async def submit(e: any) {
        e.preventDefault();
        try {
            await reset_password(token, password);
        } except RemoteError as ex {
            said = reason(ex);
            return;
        }
        done = True;
    }

    can with entry {
        document.title = "Set a new password";
        again_on_new_link();
        window.setTimeout(
            lambda {
                if box.current is not None {
                    box.current.focus();
                }
            },
            0,
        );
    }

    return <main>
        <h1>Set a new password</h1>
        {<p>
            This page is opened by a link mailed to an account's address, and this address holds
            no such link.
        </p>
            if token == ""
            else None}
        {<>
            <p>
                Your password is set, and you are signed in. Every other session of the account has
                ended.
            </p>
            <a href="/">{"Go to " + window.location.host}</a>
        </>
            if done
            else None}
        {<form onSubmit={submit}>
            <label>
                A new password, of at least 8 characters
                <input
                    ref={box}
                    type="password"
                    autocomplete="new-password"
                    onInput={lambda (e: any) { password = e.target.value; }}
                /></label>
            <Said text={said} />
            <div class="row"><button type="submit">Set the password</button></div>
        </form>
            if token != "" and not done
            else None}
    </main>;
}
