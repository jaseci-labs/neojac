impl job(f: Callable) {
    comptime assert len(params(f)) == 2, "a job's function takes its input and a note(phase, text)";
    note(f, "job", None);
}

impl JobsProgram.command -> list[str] {
    return job_command();
}

impl JobsProgram.owner -> str {
    return job_owner();
}

impl JobsProgram.run(name: str, input: any, note: Callable[[str, str], None]) -> any {
    return run_job(name, input, note);
}

impl JobsProgram.run_space(
    owner: str, name: str, input: any, note: Callable[[str, str], None]
) -> any {
    return run_space_job(owner, name, input, note);
}

impl jobs -> dyn Jobs {
    if len(_jobs) == 0 {
        j: dyn Jobs = bound("jobs");
        j.open(JobsProgram());
        _jobs.append(j);
    }
    return _jobs[0];
}

impl set_job_command(command: list[str], owner: str) {
    _job_command.clear();
    for c in command {
        _job_command.append(c);
    }
    _job_owner = owner;
}

impl job_command -> list[str] {
    if len(_job_command) > 0 {
        return list(_job_command);
    }
    return sys.orig_argv[0:len(sys.orig_argv) - len(sys.argv) + 1];
}

impl job_owner -> str {
    return _job_owner;
}

impl JobFailed.__str__ -> str {
    return self.detail;
}

impl Job.read {
    if self.ended {
        return;
    }
    st = jobs().read(self.id);
    for n in st.notes {
        self.said.append(n);
    }
    if st.done {
        self.ended = True;
        self.got = st.result;
        self.failed = st.failed;
    }
}

impl Job.done -> bool {
    self.read();
    return self.ended;
}

impl Job.notes -> list[tuple[str, str]] {
    self.read();
    out = self.said;
    self.said = [];
    return out;
}

impl Job.settled -> any {
    while not self.done() {
        time.sleep(0.05);
    }
    if self.failed != "" {
        raise JobFailed(detail=self.failed);
    }
    return self.got;
}

impl job_result[R](j: Job[R]) -> R {
    return decode[R](j.settled());
}

impl start_job[R, I](name: str, input: I) -> Job[R] {
    return Job[R](id=jobs().start(name, encode[I](input)));
}

impl run_job(name: str, input: any, note: Callable[[str, str], None]) -> any {
    comptime for n in noted("job") {
        if name == n.module + "." + n.name {
            run = lambda (v: any) -> any {
                a = restore(args_type(n.decl));
                comptime ps = params(n.decl);
                comptime i = ps[0];
                comptime k = ps[1];
                set_field(a, i.name, decode[i.type](v));
                set_field(a, k.name, note);
                return encode(apply(n.decl, a));
            };
            return run(input);
        }
    }
    raise ValueError(f"no job '{name}' in this program");
}

impl register_hosted_jobs -> bool {
    _hosted_jobs.append(lambda -> bool { return jobs().work(); });
    return True;
}

impl ran_job -> bool {
    comptime for n in noted("job") {
        return jobs().work();
    }
    for hosted in _hosted_jobs {
        return hosted();
    }
    return False;
}

impl run_space_job(owner: str, name: str, input: any, note: Callable[[str, str], None]) -> any {
    for h in plan().hosted {
        runs = space_host(h.host).job if h.space == owner else None;
        if runs is not None {
            runner: Callable[[str, str, str, any, Callable[[str, str], None]], any] = runs;
            return runner(owner, space_code(owner), name, input, note);
        }
    }
    raise ValueError(f"this program runs no jobs of a space '{owner}'");
}
