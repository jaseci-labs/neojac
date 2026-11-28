impl register_window_host(h: WindowHost) -> bool {
    _window_host.append(h);
    return True;
}

impl window_host -> WindowHost {
    if len(_window_host) == 0 {
        raise RuntimeError("this program shows no window");
    }
    return _window_host[0];
}

impl register_space_host(host: str, h: SpaceHost) -> bool {
    _space_hosts[host] = h;
    return True;
}

impl space_host(host: str) -> SpaceHost {
    if host not in _space_hosts {
        raise RuntimeError(f"this program runs no {host} space in its process");
    }
    return _space_hosts[host];
}
