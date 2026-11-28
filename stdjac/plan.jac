import json;
import os;
import sys;

import from neojac {
    def __app_plan -> str;
}

import from common.contract { Host, Secret }

obj Page {
    has space: str,
        base: str = "/",
        headers: dict[str, str] = {},
        routes: list[str] = [],
        held: bool = False;
}

obj Hosted {
    has space: str,
        host: str,
        code: str = "";
}

obj Window {
    has title: str,
        width: int = 1280,
        height: int = 860,
        min_width: int = 640,
        min_height: int = 480;
}

obj AppPlan {
    has app: str = "",
        spaces: list[str] = [],
        carried: bool = False,
        has_entry: bool = False,
        hosted: list[Hosted] = [],
        pages: list[Page] = [],
        forwarded: dict[str, str] = {},
        remotes: dict[str, str] = {},
        accounts: str = "",
        window: Window | None = None,
        data_dir: str = "",
        arrangement: str = "",
        others: list[AppPlan] = [],
        arrangements: list[str] = [],
        chosen: bool = True;
}

glob _plan: list[AppPlan] = [];
def:pub plan -> AppPlan;
def:pub app_data(p: AppPlan) -> str;
def:pub data_dir -> str;

glob _upgraded: list[str] = [];
def:pub upgraded(what: str);
def:pub upgrades_made -> list[str];

obj:pub ProgramHost(Host) {
    def data_dir -> str;

    def upgraded(what: str);

    def secret(s: Secret) -> str;
}

def:pub host -> ProgramHost;
def arrangement_file(p: AppPlan) -> str;
def arranged(first: AppPlan) -> AppPlan;
def:pub keep_arrangement(name: str);
def:pub env_name(app: str, what: str) -> str;
def:pub remote_url(space: str) -> str;
def:pub space_code(space: str) -> str;
