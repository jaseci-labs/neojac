impl page -> JsxPage {
    has said: str = "";
    has checked: bool = False;

    token = mailed_token();

    async def submit(e: any) {
        e.preventDefault();
        try {
            await check_address(token);
        } except RemoteError as ex {
            said = reason(ex);
            return;
        }
        checked = True;
    }

    can with entry {
        document.title = "Check your address";
        again_on_new_link();
    }

    return <main>
        <h1>Check your address</h1>
        {<p>
            This page is opened by a link mailed to an account's address, and this address holds
            no such link.
        </p>
            if token == ""
            else None}
        {<p>Your address is checked. You can close this page.</p> if checked else None}
        {<>
            <p>
                {"This checks that the address this link was mailed to is yours, for an account at "
                    + window.location.host
                    + ". If you made no account there, close this page."}
            </p>
            <form onSubmit={submit}>
                <Said text={said} />
                <div class="row"><button type="submit">Check my address</button></div>
            </form>
        </>
            if token != "" and not checked
            else None}
    </main>;
}
