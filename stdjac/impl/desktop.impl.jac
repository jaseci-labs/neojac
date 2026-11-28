impl run_asked_window(title: str, width: int, height: int, min_width: int, min_height: int) {
    if len(sys.argv) != 3 or sys.argv[1] != "--window" {
        return;
    }
    code = run_window(sys.argv[2], title, width, height, min_width, min_height);
    if code == -1 {
        print("neojac has no webview for this platform yet", file=sys.stderr);
    } elif code == -2 {
        print("this app's window needs GTK 3 and WebKitGTK 4.1", file=sys.stderr);
    }
    sys.exit(0 if code == 0 else 1);
}

impl WindowProcess.open(port: int) {
    if os.environ.get("JAC_DEV_FRAMED", "") != "" {
        return;
    }
    page = os.environ.get("JAC_DEV_PAGE", "");
    self.proc = subprocess.Popen([
        sys.executable,
        "--window",
        page if page != "" else "http://127.0.0.1:" + str(port) + "/",
    ]);
    signal.signal(signal.SIGTERM, close_window);
    signal.signal(signal.SIGINT, close_window);
}

impl WindowProcess.watch {
    p = self.proc;
    if p is None {
        return;
    }
    ended = p.poll();
    if ended is not None {
        sys.exit(0 if ended == 0 else 1);
    }
}

impl relaunch {
    p = _window.proc;
    if p is not None and p.poll() is None {
        p.terminate();
        p.wait();
    }
    sys.stdout.flush();
    os.execv(sys.executable, [sys.executable] + sys.argv[1:len(sys.argv)]);
}

impl close_window(number: int, frame: any) {
    p = _window.proc;
    if p is not None and p.poll() is None {
        p.terminate();
    }
    sys.exit(128 + number);
}
