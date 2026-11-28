import sys;
import time;
import from jaclang.comptime { apply, args_type, note, noted, params, restore, set_field }
import from jobs.contract { Jobs, JobsHost }

comptime def job(f: Callable);
type JobNote = Callable[[str, str], None];

glob _jobs: list[dyn Jobs] = [];

obj JobsProgram(ProgramHost, JobsHost) {
    def command -> list[str];

    def owner -> str;

    def run(name: str, input: any, note: Callable[[str, str], None]) -> any;

    def run_space(owner: str, name: str, input: any, note: Callable[[str, str], None]) -> any;
}

def:pub jobs -> dyn Jobs;

glob _job_command: list[str] = [],
     _job_owner: str = "";
def:pub set_job_command(command: list[str], owner: str);
def job_command -> list[str];
def job_owner -> str;

obj:pub JobFailed(Exception) {
    has detail: str;

    def __str__ -> str;
}

obj:pub Job[R] {
    has id: str,
        said: list[tuple[str, str]] = [],
        ended: bool = False,
        got: any = None,
        failed: str = "";

    def read;

    def done -> bool;

    def notes -> list[tuple[str, str]];
    def settled -> any;
}

def:pub job_result[R](j: Job[R]) -> R;
def:pub start_job[R, I](name: str, input: I) -> Job[R];
def:pub run_job(name: str, input: any, note: Callable[[str, str], None]) -> any;

glob _hosted_jobs: list[Callable[[], bool]] = [];
def:pub register_hosted_jobs -> bool;
def:pub ran_job -> bool;
def run_space_job(owner: str, name: str, input: any, note: Callable[[str, str], None]) -> any;
