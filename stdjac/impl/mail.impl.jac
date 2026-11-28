impl mailer -> dyn Mailer {
    if len(_mail) == 0 {
        m: dyn Mailer = bound("mail");
        m.open(host());
        _mail.append(m);
    }
    return _mail[0];
}
