impl AccountsAuth.postinit {
    self.book = None;
    self.host = None;
    self.data_dir = "";
    self.windowed = False;
    self.github_client = "";
    self.github_client_secret = "";
    self.google_client = "";
    self.google_client_secret = "";
    self.sending = False;
}

impl AccountsAuth.open(host: dyn AuthHost) {
    self.host = host;
    self.data_dir = host.data_dir();
    self.windowed = host.windowed();
    self.github_client = host.secret(self.github_id);
    self.github_client_secret = host.secret(self.github_secret);
    self.google_client = host.secret(self.google_id);
    self.google_client_secret = host.secret(self.google_secret);
    self.sending = host.sends_mail();
    self.book = self.open_book(host);
}

impl AccountsAuth.kept -> dyn Book {
    book = self.book;
    if book is None {
        raise RuntimeError("accounts was asked before it was opened");
    }
    return book;
}

impl AccountsAuth.tried(scope: str, actor: str, limit: int, seconds: int) -> int {
    host = self.host;
    if host is None {
        raise RuntimeError("accounts was asked before it was opened");
    }
    return host.consume_limit(scope, actor, limit, seconds);
}

impl AccountsAuth.local -> bool {
    return self.local_users and self.windowed;
}

impl AccountsAuth.local_file -> str {
    return os.path.join(self.data_dir, "local-user");
}

impl AccountsAuth.local_now -> str {
    try {
        with open(self.local_file()) as f {
            name = f.read().strip();
            return name if name in self.externals("local") else "";
        }
    } except OSError {
        return "";
    }
}

impl AccountsAuth.caller(headers: dict[str, str]) -> str | None {
    credential = bearer_token(headers);
    if credential == "" {
        return None;
    }
    key = token_key(credential);
    held = self.kept().session(key);
    if held is None {
        return None;
    }
    (user, expires) = held;
    if expires <= time.time() {
        self.kept().end(key);
        return None;
    }
    return user;
}

impl AccountsAuth.asks(headers: dict[str, str]) -> SignIn {
    if self.local() {
        now = self.local_now();
        if now != "" {
            return SignIn(session=self.external("local", now, now));
        }
        return SignIn(
            fields=[SignInField(name="name", label="Your name", choices=self.externals("local"))],
            actions=[SignInAction(name="local", label="Continue", needs=["name"])],
        );
    }
    actions = [SignInAction(name="login", label="Sign in", needs=["username", "password"])];
    if self.registration {
        actions.append(
            SignInAction(
                name="register", label="Create account", needs=["username", "email", "password"]
            ),
        );
    }
    if self.github_offered() {
        actions.append(self.github_action());
    }
    if self.google_offered() {
        actions.append(self.google_action());
    }
    return SignIn(
        fields=[
            SignInField(name="username", label="Username"),
            SignInField(
                name="email", label="Email" if self.needs_address() else "Email (optional)"
            ),
            SignInField(name="password", label="Password", secret=True),
        ],
        actions=actions,
        forgot="username" if self.mails() else "",
    );
}

impl AccountsAuth.needs_address -> bool {
    return self.email_required or self.mails();
}

impl AccountsAuth.github_offered -> bool {
    return self.github_client != "" and self.github_client_secret != "";
}

impl AccountsAuth.github_back -> str {
    return self.origin.rstrip("/") + "/__jac/auth/github" if self.origin != "" else "";
}

impl AccountsAuth.google_offered -> bool {
    return self.google_client != "" and self.google_client_secret != "" and self.origin != "";
}

impl AccountsAuth.google_back -> str {
    return self.origin.rstrip("/") + "/__jac/auth/google";
}

impl AccountsAuth.away_mark(way: str, expires: int, verifier: str) -> str {
    said = (way + "." + str(expires) + "." + verifier).encode("utf-8");
    return hmac.new(self.kept().away_key(), said, hashlib.sha256).hexdigest();
}

impl AccountsAuth.away(way: str, label: str, place: str, query: dict[str, str]) -> SignInAction {
    verifier = secrets.token_urlsafe(48);
    expires = int(time.time()) + AWAY_SECONDS;
    query["state"] = str(expires) + "." + self.away_mark(way, expires, verifier);
    query["code_challenge"] = base64.urlsafe_b64encode(
        hashlib.sha256(verifier.encode("ascii")).digest()
    ).decode("ascii").rstrip("=");
    query["code_challenge_method"] = "S256";
    return SignInAction(
        name=way, label=label, redirect=place + "?" + urlencode(query), keeps={"verifier": verifier}
    );
}

impl AccountsAuth.came_back(way: str, service: str, given: dict[str, str]) -> str {
    if given.get("error", "") != "" {
        raise Rejected(detail=f"signing in through {service} was turned away there");
    }
    verifier = given.get("verifier", "");
    (expires_said, dot, mark) = given.get("state", "").partition(".");
    if dot == ""
        or not expires_said.isdigit()
        or verifier == ""
        or not hmac.compare_digest(mark, self.away_mark(way, int(expires_said), verifier))
    {
        raise Rejected(detail="this sign-in was not begun here: try again");
    }
    if int(expires_said) < time.time() {
        raise Rejected(detail="this sign-in took too long: try again");
    }
    return verifier;
}

impl AccountsAuth.github_action -> SignInAction {
    query: dict[str, str] = {"client_id": self.github_client};
    back = self.github_back();
    if back != "" {
        query["redirect_uri"] = back;
    }
    return self.away(
        "github", "Continue with GitHub", self.github.rstrip("/") + "/login/oauth/authorize", query
    );
}

impl AccountsAuth.github_answer(given: dict[str, str]) -> Session {
    verifier = self.came_back("github", "GitHub", given);
    exchange: dict[str, str] = {
        "client_id": self.github_client,
        "client_secret": self.github_client_secret,
        "code": given.get("code", ""),
        "code_verifier": verifier,
    };
    back = self.github_back();
    if back != "" {
        exchange["redirect_uri"] = back;
    }
    try {
        got = asked_json(
            self.github.rstrip("/") + "/login/oauth/access_token",
            {"Accept": "application/json"},
            urlencode(exchange).encode("utf-8"),
        );
        access = str(got.get("access_token", ""));
        if access == "" {
            raise Rejected(detail="GitHub did not accept the sign-in");
        }
        me = asked_json(
            self.github_api.rstrip("/") + "/user",
            {
                "Authorization": "Bearer " + access,
                "Accept": "application/vnd.github+json",
                "User-Agent": "neojac-accounts",
            },
        );
    } except OSError {
        raise Rejected(detail="GitHub could not be reached: try again");
    } except ValueError {
        raise Rejected(detail="GitHub's answer could not be read: try again");
    }
    if "id" not in me {
        raise Rejected(detail="GitHub did not say who signed in");
    }
    return self.external("github", str(me["id"]), str(me.get("login", "")));
}

impl AccountsAuth.google_action -> SignInAction {
    return self.away(
        "google",
        "Continue with Google",
        self.google.rstrip("/") + "/o/oauth2/v2/auth",
        {
            "client_id": self.google_client,
            "redirect_uri": self.google_back(),
            "response_type": "code",
            "scope": "openid email",
        },
    );
}

impl AccountsAuth.google_answer(given: dict[str, str]) -> Session {
    verifier = self.came_back("google", "Google", given);
    exchange: dict[str, str] = {
        "client_id": self.google_client,
        "client_secret": self.google_client_secret,
        "code": given.get("code", ""),
        "code_verifier": verifier,
        "grant_type": "authorization_code",
        "redirect_uri": self.google_back(),
    };
    try {
        got = asked_json(
            self.google_api.rstrip("/") + "/token",
            {"Accept": "application/json"},
            urlencode(exchange).encode("utf-8"),
        );
        parts = str(got.get("id_token", "")).split(".");
        if len(parts) != 3 {
            raise Rejected(detail="Google did not accept the sign-in");
        }
        said: any = json.loads(
            base64.urlsafe_b64decode(parts[1] + "=" * (-len(parts[1]) % 4)).decode("utf-8")
        );
    } except HTTPError {
        raise Rejected(detail="Google did not accept the sign-in");
    } except OSError {
        raise Rejected(detail="Google could not be reached: try again");
    } except ValueError {
        raise Rejected(detail="Google's answer could not be read: try again");
    }
    if not isinstance(said, dict) {
        raise Rejected(detail="Google's answer could not be read: try again");
    }
    token: dict[str, any] = said;
    expires: any = token.get("exp", 0);
    if str(token.get("iss", "")) not in GOOGLE_ISSUERS
        or str(token.get("aud", "")) != self.google_client
        or not isinstance(expires, (int, float))
        or float(expires) < time.time()
    {
        raise Rejected(detail="Google's answer was not for this app: try again");
    }
    if str(token.get("sub", "")) == "" {
        raise Rejected(detail="Google did not say who signed in");
    }
    return self.external("google", str(token["sub"]), str(token.get("email", "")));
}

impl AccountsAuth.answer(action: str, given: dict[str, str], client: str) -> Session {
    name = given.get("username", "");
    retry = 0;
    if action == "local" and self.local() {
        who = given.get("name", "").strip();
        s = self.external("local", who, who);
        os.makedirs(self.data_dir, exist_ok=True);
        with open(self.local_file(), "w") as f {
            f.write(who + "\n");
        }
        return s;
    }
    if action == "login" {
        retry = self.tried("login", "client " + client, LOGIN_PER_CLIENT, LIMIT_SECONDS);
        if retry == 0 {
            retry = self.tried(
                "login",
                "user " + client + " " + name.strip().lower(),
                LOGIN_PER_USER,
                LIMIT_SECONDS,
            );
        }
    } elif action == "register" and self.registration {
        retry = self.tried("register", client, REGISTER_PER_CLIENT, LIMIT_SECONDS);
    } elif action == "register" {
        raise Rejected(detail=CLOSED);
    } elif action == "github" and self.github_offered() {
        retry = self.tried("github", client, LOGIN_PER_CLIENT, LIMIT_SECONDS);
    } elif action == "google" and self.google_offered() {
        retry = self.tried("google", client, LOGIN_PER_CLIENT, LIMIT_SECONDS);
    } else {
        raise Rejected(detail=f"no way of signing in is '{action}'");
    }
    if retry > 0 {
        raise Rejected(detail="too many attempts: try again later", retry_after=retry);
    }
    if action == "login" {
        return self.login(name, given.get("password", ""));
    }
    if action == "github" {
        return self.github_answer(given);
    }
    if action == "google" {
        return self.google_answer(given);
    }
    return self.register(name, given.get("email", ""), given.get("password", ""));
}

impl AccountsAuth.device(client: str) -> DeviceSignIn {
    retry = self.tried("device", client, DEVICE_PER_CLIENT, LIMIT_SECONDS);
    if retry > 0 {
        raise Rejected(detail="too many attempts: try again later", retry_after=retry);
    }
    now = time.time();
    secret = secrets.token_hex(32);
    for attempt in range(8) {
        code = "".join([secrets.choice(DEVICE_LETTERS) for k in range(DEVICE_LENGTH)]);
        if self.kept().expect(code, token_key(secret), now + DEVICE_SECONDS, now) {
            half = DEVICE_LENGTH // 2;
            return DeviceSignIn(
                code=code[:half] + "-" + code[half:],
                secret=secret,
                lasts=DEVICE_SECONDS,
                every=DEVICE_EVERY,
            );
        }
    }
    raise Rejected(detail="no code could be made: try again");
}

impl AccountsAuth.device_answer(headers: dict[str, str], code: str, allow: bool) {
    who = self.caller(headers);
    if who is None {
        raise Rejected(detail="sign in first");
    }
    retry = self.tried("device code", "user " + who, DEVICE_PER_USER, LIMIT_SECONDS);
    if retry > 0 {
        raise Rejected(detail="too many attempts: try again later", retry_after=retry);
    }
    said = "".join([c for c in code.upper() if c in DEVICE_LETTERS]);
    if not self.kept().decide(said, who if allow else "", time.time()) {
        raise Rejected(
            detail="no program is waiting with that code: check it, or begin again from the program"
        );
    }
}

impl AccountsAuth.device_session(secret: str) -> Session | None {
    found = self.kept().collect(token_key(secret), time.time());
    if found is None {
        raise Rejected(detail="this sign-in waited too long, or was never begun: begin again");
    }
    (answered, user) = found;
    if not answered {
        return None;
    }
    if user == "" {
        raise Rejected(detail="this sign-in was turned away");
    }
    return Session(user=user, token=self.token_for(user));
}

impl AccountsAuth.leave(headers: dict[str, str]) {
    self.end(bearer_token(headers));
    if self.local() and os.path.exists(self.local_file()) {
        os.remove(self.local_file());
    }
}

impl AccountsAuth.token_for(user: str) -> str {
    now = time.time();
    t = secrets.token_hex(32);
    self.kept().begin(token_key(t), user, now + self.session_seconds, now);
    return t;
}

impl AccountsAuth.end(credential: str) {
    self.kept().end(token_key(credential));
}

impl AccountsAuth.register(username: str, email: str, password: str) -> Session {
    u = username.strip().lower();
    if re.fullmatch(USERNAME, u) is None {
        raise Rejected(
            detail="a username is 3 to 32 letters, digits, '.', '_' or '-', starting with a letter "
                "or a digit",
        );
    }
    e = email.strip().lower();
    if e == "" and self.needs_address() {
        raise Rejected(detail="an account needs an email address");
    }
    if e != "" {
        an_address(e);
    }
    record = self.password_kept(password);
    if not self.kept().add(u, e, record, time.time()) {
        raise Rejected(detail="that username or email is taken");
    }
    if self.mails() {
        self.mail_link(u, e, "check");
    }
    return Session(user=u, token=self.token_for(u));
}

impl AccountsAuth.password_kept(password: str) -> str {
    if len(password) < 8 {
        raise Rejected(detail="a password has at least 8 characters");
    }
    return password_record(password, self.rounds);
}

impl AccountsAuth.mails -> bool {
    return self.sending and self.origin != "" and not self.local();
}

impl AccountsAuth.checked(user: str) -> bool {
    (provider, colon, rest) = user.partition(":");
    if colon != "" {
        return provider in VOUCHING;
    }
    return self.kept().address(user)[1];
}

impl AccountsAuth.mail_link(user: str, email: str, purpose: str) {
    token = secrets.token_hex(32);
    now = time.time();
    lasts = CHECK_SECONDS if purpose == "check" else RESET_SECONDS;
    self.kept().link(token_key(token), user, purpose, now + lasts, now);
    site = self.origin.rstrip("/");
    place = urlsplit(site).netloc or site;
    link = f"{site}/__jac/auth/{purpose}#{token}";
    if purpose == "check" {
        self.mailed().send_mail(
            email,
            f"Check your address at {place}",
            f"Follow this link within a day to check that this address is yours, for the account "
                f"{user} at {site}:\n\n{link}\n\nIf you made no such account, do nothing.\n",
        );
    } else {
        self.mailed().send_mail(
            email,
            f"Set a new password at {place}",
            f"Follow this link within an hour to set a new password for the account {user} at "
                f"{site}:\n\n{link}\n\n"
                f"If you did not ask for one, do nothing: the password stays as it is.\n",
        );
    }
}

impl AccountsAuth.mailed -> dyn AuthHost {
    host = self.host;
    if host is None {
        raise RuntimeError("accounts was asked before it was opened");
    }
    return host;
}

impl AccountsAuth.mail_check(headers: dict[str, str], address: str) {
    if not self.mails() {
        raise Rejected(detail=NO_MAIL);
    }
    who = self.caller(headers);
    if who is None {
        raise Rejected(detail="sign in first");
    }
    if ":" in who {
        raise Rejected(
            detail="this account is one another service vouches for, and has no address to check "
                "here",
        );
    }
    retry = self.tried("mail", "user " + who, MAIL_PER_USER, LIMIT_SECONDS);
    if retry > 0 {
        raise Rejected(detail="too many attempts: try again later", retry_after=retry);
    }
    (email, ok) = self.kept().address(who);
    given = address.strip().lower();
    if ok {
        raise Rejected(detail="this account's address is checked already");
    }
    if email == "" {
        if given == "" {
            raise Rejected(detail="this account has no address: give it one");
        }
        an_address(given);
        if not self.kept().give_address(who, given) {
            raise Rejected(detail="that email is taken");
        }
        email = given;
    } elif given != "" and given != email {
        raise Rejected(detail="this account has an address already");
    }
    self.mail_link(who, email, "check");
}

impl AccountsAuth.check(token: str, client: str) {
    if not self.mails() {
        raise Rejected(detail=NO_MAIL);
    }
    retry = self.tried("follow", client, FOLLOW_PER_CLIENT, LIMIT_SECONDS);
    if retry > 0 {
        raise Rejected(detail="too many attempts: try again later", retry_after=retry);
    }
    if self.kept().check(token_key(token), time.time()) == "" {
        raise Rejected(detail=NO_LINK);
    }
}

impl AccountsAuth.forgot(name: str, client: str) {
    if not self.mails() {
        raise Rejected(detail=NO_MAIL);
    }
    retry = self.tried("forgot", client, FORGOT_PER_CLIENT, LIMIT_SECONDS);
    if retry > 0 {
        raise Rejected(detail="too many attempts: try again later", retry_after=retry);
    }
    found = self.kept().account(name.strip().lower());
    if found is None {
        return;
    }
    user = found[0];
    email = self.kept().address(user)[0];
    if email == "" or self.tried("mail", "user " + user, MAIL_PER_USER, LIMIT_SECONDS) > 0 {
        return;
    }
    self.mail_link(user, email, "reset");
}

impl AccountsAuth.reset(token: str, password: str, client: str) -> Session {
    if not self.mails() {
        raise Rejected(detail=NO_MAIL);
    }
    retry = self.tried("follow", client, FOLLOW_PER_CLIENT, LIMIT_SECONDS);
    if retry > 0 {
        raise Rejected(detail="too many attempts: try again later", retry_after=retry);
    }
    record = self.password_kept(password);
    user = self.kept().reset(token_key(token), record, time.time());
    if user == "" {
        raise Rejected(detail=NO_LINK);
    }
    return Session(user=user, token=self.token_for(user));
}

impl AccountsAuth.login(username: str, password: str) -> Session {
    u = username.strip().lower();
    user = "";
    record = "pbkdf2_sha256$" + str(self.rounds) + "$" + "00" * 16 + "$" + "00" * 32;
    found = self.kept().account(u);
    if found is not None {
        (user, record) = found;
    }
    if not password_matches(password, record) or user == "" {
        raise Rejected(detail="incorrect username or password");
    }
    return Session(user=user, token=self.token_for(user));
}

impl AccountsAuth.external(provider: str, external_id: str, name: str = "") -> Session {
    if re.fullmatch("[a-z0-9_-]{1,32}", provider) is None
        or external_id == ""
        or len(external_id) > 256
    {
        raise Rejected(detail="an external identity is a provider's name and its ID for the user");
    }
    if not self.registration and self.kept().known(provider, external_id) == "" {
        raise Rejected(detail=CLOSED);
    }
    user = self.kept().identity(provider, external_id, provider + ":" + external_id, time.time());
    return Session(user=user, token=self.token_for(user), name=name);
}

impl AccountsAuth.externals(provider: str) -> list[str] {
    return self.kept().identities(provider);
}

impl asked_json(url: str, headers: dict[str, str], body: bytes | None = None) -> dict[str, any] {
    req = urllib.request.Request(url, data=body, headers=headers);
    with urllib.request.urlopen(req, timeout=SERVICE_SECONDS) as r {
        got: any = json.loads(r.read().decode("utf-8"));
    }
    if not isinstance(got, dict) {
        raise ValueError("not a JSON object");
    }
    made: dict[str, any] = got;
    return made;
}

impl an_address(email: str) {
    if len(email) > 254 or re.fullmatch(r"[^@\s]+@[^@\s]+", email) is None {
        raise Rejected(detail="that isn't an email address");
    }
}

impl token_key(token: str) -> str {
    return hashlib.sha256(token.encode("utf-8")).hexdigest();
}

impl password_record(password: str, rounds: int) -> str {
    salt = secrets.token_bytes(16);
    key = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, rounds);
    return "pbkdf2_sha256$" + str(rounds) + "$" + salt.hex() + "$" + key.hex();
}

impl password_matches(password: str, record: str) -> bool {
    parts = record.split("$");
    if len(parts) != 4 or parts[0] != "pbkdf2_sha256" {
        raise ValueError("a password record of an unknown kind");
    }
    key = hashlib.pbkdf2_hmac(
        "sha256", password.encode("utf-8"), bytes.fromhex(parts[2]), int(parts[1])
    );
    return hmac.compare_digest(key, bytes.fromhex(parts[3]));
}
