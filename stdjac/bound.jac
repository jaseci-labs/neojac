import json;
import os;
import sys;
import from jaclang.comptime { Kind, fields, get_field, kind, set_field }
import from common.contract { Secret }

obj:pub Offers {
    has variables: list[str],
        listed: list[str],
        named: str,
        makers: list[Callable[[], any]];
}

glob _made: dict[str, any] = {};
def:pub bound(abstraction: str, offers: Callable[[], Offers] | None = None) -> any;
def:pub settle[T](x: T, variables: list[str]) -> T;
def:pub give_settings[S](settings: S, plugin: S);
def given(variables: list[str], field: str) -> tuple[str, str] | None;
def unfit(got: tuple[str, str], field: str, why: Exception);
