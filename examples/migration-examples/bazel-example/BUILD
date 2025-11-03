# Example Bazel BUILD file for migration testing

cc_binary(
    name = "hello",
    srcs = ["main.cpp", "greeter.cpp"],
    hdrs = ["greeter.h"],
    copts = ["-std=c++17", "-Wall"],
    linkopts = ["-lpthread"],
    deps = [":utils"],
)

cc_library(
    name = "utils",
    srcs = ["utils.cpp"],
    hdrs = ["utils.h"],
    copts = ["-std=c++17"],
)

py_binary(
    name = "script",
    srcs = ["script.py"],
    deps = [":pylib"],
)

py_library(
    name = "pylib",
    srcs = ["lib.py"],
)

