impl page(way: str) -> JsxPage {
    has failed: str = "";

    async can with entry {
        document.title = "Signing in";
        try {
            await finish_sign_in();
        } except RemoteError as e {
            failed = reason(e);
        }
    }

    return <main>
        {<p>{"Signing in did not work: " + failed + ". "}<a href="/">Go back</a></p>
            if failed != ""
            else None}
    </main>;
}
