cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Request Administrator elevation at launch. The desktop tunnel
# (sstp_vpn_plugin) creates a Wintun adapter and rewrites the routing table;
# both need it. Unelevated, the app still starts and looks healthy, but every
# connect() can only ever fail with VpnStatus.missingPrivilege.
#
# This MUST be a linker option, not a <trustInfo> block in runner.exe.manifest.
# The linker emits its own UAC manifest (asInvoker by default) and mt.exe merges
# it with the manifest file; declaring the level in both produces a duplicate
# section and the build dies with the deeply unhelpful
#
#     LINK : fatal error LNK1327: failure during running mt.exe
#
# Setting it here means exactly one trustInfo is ever produced. (Learned the hard
# way in sstp_vpn_plugin -- see its example/windows/runner/CMakeLists.txt.)
#
# The tradeoff, taken knowingly: the WHOLE app runs elevated and the user gets a
# UAC prompt on every launch, even if they never connect. The right design is a
# privileged helper service with an unelevated UI (what WireGuard does); that is
# privilege separation and out of scope here.
if(MSVC)
  set_target_properties(${BINARY_NAME} PROPERTIES
    LINK_FLAGS "/MANIFESTUAC:\"level='requireAdministrator' uiAccess='false'\""
  )
endif()

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
