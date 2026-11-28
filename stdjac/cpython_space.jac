import json;
import sys;
import importlib;
import from schedule.contract { Scheduled }
def load_cpython_space(space: str, dir: str) -> any;
def run_cpython_space(
    space: str,
    dir: str,
    mine: list[str],
    port: Callable[[str, bytes, str, bool], tuple[int, bytes]],
) -> list[Scheduled];
def space_scheduled(t: any) -> Scheduled;
def run_cpython_job(
    space: str, dir: str, name: str, input: any, note: Callable[[str, str], None]
) -> any;

glob _cpython_host: bool = register_space_host(
    "cpython",
    SpaceHost(
        start=lambda (
            space: str,
            dir: str,
            mine: list[str],
            port: Callable[[str, bytes, str, bool], tuple[int, bytes]],
        ) -> list[Scheduled] { return run_cpython_space(space, dir, mine, port); },
        job=lambda (
            space: str, dir: str, name: str, input: any, note: Callable[[str, str], None]
        ) -> any { return run_cpython_job(space, dir, name, input, note); },
    ),
);

glob _cpython_jobs: bool = register_hosted_jobs();
