import hmac;
import json;
import os;
import sys;
import from auth.contract { Auth, AuthHost, Rejected, Session, SignIn }
import from mail.contract { MailNotSent }
import from transport.contract { Request, Response, json_fail }

glob _auth: list[dyn Auth] = [];

obj AuthProgram(ProgramHost, AuthHost) {
    def windowed -> bool;

    def consume_limit(scope: str, actor: str, limit: int, seconds: int) -> int;

    def sends_mail -> bool;

    def send_mail(to: str, subject: str, text: str);
}

def:pub open_auth;
def:pub address_checked -> bool;
def:pub auth_caller(headers: dict[str, str]) -> str;
def:pub deployment_signed(r: Request) -> bool;

def asked(a: SignIn) -> dict[str, any];
def signed(s: Session) -> dict[str, any];

def:pub auth_route(r: Request) -> Response | None;
