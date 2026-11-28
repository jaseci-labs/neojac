import os;
import signal;
import subprocess;
import sys;
def:pub run_asked_window(title: str, width: int, height: int, min_width: int, min_height: int);

obj:pub WindowProcess {
    has proc: subprocess.Popen | None = None;

    def open(port: int);
    def watch;
}

def relaunch;
def close_window(number: int, frame: any);

glob _window: WindowProcess = WindowProcess(),
     _window_host: bool = register_window_host(
         WindowHost(
             run_asked=run_asked_window,
             open=lambda (port: int) { _window.open(port) },
             watch=lambda { _window.watch() },
             relaunch=lambda { relaunch() },
         ),
     );
