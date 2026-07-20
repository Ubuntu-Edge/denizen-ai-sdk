# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(denizen_ai_native VERSION 0.0.1 LANGUAGES C)

add_library(sqlite_vec SHARED
  "sqlite-vec.c"
)

set_target_properties(sqlite_vec PROPERTIES
  OUTPUT_NAME "sqlite_vec"
)

# sqlite-vec is compiled as a loadable extension (not SQLITE_CORE)
target_compile_definitions(sqlite_vec PRIVATE)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(sqlite_vec PRIVATE "-Wl,-z,max-page-size=16384")
endif()
