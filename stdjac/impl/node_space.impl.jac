impl run_node_space(
    space: str,
    dir: str,
    mine: list[str],
    port: Callable[[str, bytes, str, bool], tuple[int, bytes]],
) {
    carried = runInThisContext("globalThis.__JAC_IN_PROCESS__ ??= {}");
    for sp in mine {
        carried[sp] = lambda (path: str, text: str, caller: str, trusted: bool, *rest: any) -> any {
            (status, reply) = port(path, text.encode("utf-8"), caller, trusted);
            return [status, reply.decode("utf-8")];
        };
    }
    main = createRequire(dir + "/")(dir + "/__main.mjs");
    its_port = main.port;
    home = threading.get_ident();

    def ask(path: str, body: bytes, caller: str, trusted: bool) -> tuple[int, bytes] {
        reply = its_port(path, body.decode("utf-8"), caller, trusted)._neojac_wait();
        status: int = reply[0];
        text: str = reply[1];
        return (status, text.encode("utf-8"));
    }

    carry_in_process(
        space,
        lambda (path: str, body: bytes, caller: str, trusted: bool) -> tuple[int, bytes] {
            if threading.get_ident() == home {
                return ask(path, body, caller, trusted);
            }
            if not loop_serving() {
                raise RuntimeError(
                    f"node space '{space}' is called from the thread that started the program, and "
                    f"this program serves nothing for another thread's call to wait on",
                );
            }
            got: list[tuple[int, bytes]] = [];
            failed: list[Exception] = [];
            done = threading.Event();
            who = rt_caller;
            on_loop(
                lambda {
                    its_own = rt_caller;
                    rt_caller_set(who);
                    try {
                        got.append(ask(path, body, caller, trusted));
                    } except Exception as e {
                        failed.append(e);
                    } finally {
                        rt_caller_set(its_own);
                    }
                    done.set();
                },
            );
            done.wait();
            if len(failed) > 0 {
                raise failed[0];
            }
            return got[0];
        },
    );
}
