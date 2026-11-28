import threading;
import from "node:module" { createRequire }
import from "node:vm" { runInThisContext }
import from schedule.contract { Scheduled }
def run_node_space(
    space: str,
    dir: str,
    mine: list[str],
    port: Callable[[str, bytes, str, bool], tuple[int, bytes]],
);

glob _node_host: bool = register_space_host(
    "node",
    SpaceHost(
        start=lambda (
            space: str,
            dir: str,
            mine: list[str],
            port: Callable[[str, bytes, str, bool], tuple[int, bytes]],
        ) -> list[Scheduled] {
            run_node_space(space, dir, mine, port);
            return [];
        },
    ),
);

glob _node_jobs: bool = register_hosted_jobs();
