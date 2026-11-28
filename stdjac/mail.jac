import from mail.contract { Mailer }

glob _mail: list[dyn Mailer] = [];
def mailer -> dyn Mailer;
