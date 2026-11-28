impl reason(e: any) -> str {
    if isinstance(e, RemoteUnavailable) {
        return "the app could not be reached";
    }
    if isinstance(e, RemoteDecodeError) {
        return "the app gave no answer";
    }
    return e.detail;
}

impl Said(text: str, told: bool = False) -> JsxElement {
    return <p class={"said told" if told else "said"} role="alert">{text}</p>;
}

impl mailed_token -> str {
    return str(window.location.hash)[1:];
}

impl again_on_new_link {
    window.addEventListener("hashchange", lambda { window.location.reload(); });
}
