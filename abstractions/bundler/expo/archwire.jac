graph layers {
    layer bundler { *; }
}

graph import {
    "expo-project" --> expo { prepare }
    "expo-project" --> "expo.serve" { prepare }
}
