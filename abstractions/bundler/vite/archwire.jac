graph layers {
    layer bundler { *; }
}

graph import {
    "vite-plugin" --> vite { prepare }
    "vite-plugin" --> "vite.serve" { prepare }
}
