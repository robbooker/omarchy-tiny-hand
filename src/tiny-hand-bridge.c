#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <poll.h>
#include <signal.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/un.h>
#include <time.h>
#include <unistd.h>

#define FRAME_NS 16666667L
#define RESPONSE_SIZE 1024
#define REQUEST_SIZE (PATH_MAX * 5)

static volatile sig_atomic_t keep_running = 1;
static char hypr_socket_path[sizeof(((struct sockaddr_un *)0)->sun_path)];
static char bridge_socket_path[sizeof(((struct sockaddr_un *)0)->sun_path)];
static char bridge_owner_path[sizeof(((struct sockaddr_un *)0)->sun_path)];
static char hotkey_owner_path[sizeof(((struct sockaddr_un *)0)->sun_path)];
static bool cursor_was_hidden = false;

static void request_stop(int signal_number) {
  (void)signal_number;
  keep_running = 0;
}

static bool build_paths(void) {
  const char *runtime_dir = getenv("XDG_RUNTIME_DIR");
  const char *instance = getenv("HYPRLAND_INSTANCE_SIGNATURE");
  if (!runtime_dir || !*runtime_dir || !instance || !*instance) return false;

  int hypr_length = snprintf(hypr_socket_path, sizeof(hypr_socket_path),
                             "%s/hypr/%s/.socket.sock", runtime_dir, instance);
  int bridge_length = snprintf(bridge_socket_path, sizeof(bridge_socket_path),
                               "%s/omarchy-tiny-hand-%lu.sock", runtime_dir,
                               (unsigned long)getuid());
  int owner_length = snprintf(bridge_owner_path, sizeof(bridge_owner_path),
                              "%s/omarchy-tiny-hand-%lu.owner", runtime_dir,
                              (unsigned long)getuid());
  int hotkey_owner_length = snprintf(hotkey_owner_path, sizeof(hotkey_owner_path),
                                     "%s/omarchy-tiny-hand-hotkey-%lu.owner",
                                     runtime_dir, (unsigned long)getuid());
  return hypr_length > 0 && (size_t)hypr_length < sizeof(hypr_socket_path)
      && bridge_length > 0 && (size_t)bridge_length < sizeof(bridge_socket_path)
      && owner_length > 0 && (size_t)owner_length < sizeof(bridge_owner_path)
      && hotkey_owner_length > 0
      && (size_t)hotkey_owner_length < sizeof(hotkey_owner_path);
}

static bool write_all(int fd, const char *data, size_t length) {
  while (length > 0) {
    ssize_t written = write(fd, data, length);
    if (written < 0) {
      if (errno == EINTR) continue;
      return false;
    }
    data += written;
    length -= (size_t)written;
  }
  return true;
}

static ssize_t hypr_request(const char *request, char *response, size_t capacity) {
  if (!request || !response || capacity < 2) return -1;

  int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
  if (fd < 0) return -1;

  struct timeval timeout = { .tv_sec = 0, .tv_usec = 80000 };
  (void)setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
  (void)setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));

  struct sockaddr_un address = { .sun_family = AF_UNIX };
  (void)snprintf(address.sun_path, sizeof(address.sun_path), "%s", hypr_socket_path);
  if (connect(fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
    close(fd);
    return -1;
  }

  if (!write_all(fd, request, strlen(request))) {
    close(fd);
    return -1;
  }
  (void)shutdown(fd, SHUT_WR);

  size_t used = 0;
  while (used + 1 < capacity) {
    ssize_t count = read(fd, response + used, capacity - used - 1);
    if (count == 0) break;
    if (count < 0) {
      if (errno == EINTR) continue;
      close(fd);
      return -1;
    }
    used += (size_t)count;
  }
  response[used] = '\0';
  close(fd);
  return (ssize_t)used;
}

static bool parse_coordinate(const char *json, const char *key, double *value) {
  const char *position = strstr(json, key);
  if (!position) return false;
  position = strchr(position, ':');
  if (!position) return false;

  errno = 0;
  char *end = NULL;
  double parsed = strtod(position + 1, &end);
  if (errno != 0 || end == position + 1) return false;
  *value = parsed;
  return true;
}

static bool parse_cursor_json(const char *json, double *x, double *y) {
  return json && x && y
      && parse_coordinate(json, "\"x\"", x)
      && parse_coordinate(json, "\"y\"", y);
}

static bool query_cursor(double *x, double *y) {
  char response[RESPONSE_SIZE];
  return hypr_request("j/cursorpos", response, sizeof(response)) > 0
      && parse_cursor_json(response, x, y);
}

static void set_cursor_hidden(bool hidden) {
  char response[RESPONSE_SIZE];
  const char *request = hidden
      ? "eval hl.config({ cursor = { invisible = true } })"
      : "eval hl.config({ cursor = { invisible = false } })";
  if (hypr_request(request, response, sizeof(response)) >= 0
      && strstr(response, "ok") != NULL) {
    cursor_was_hidden = hidden;
  }
}

static bool lua_quote(const char *source, char *output, size_t capacity) {
  if (!source || !output || capacity < 3) return false;

  size_t used = 0;
  output[used++] = '"';
  for (const unsigned char *cursor = (const unsigned char *)source; *cursor; cursor++) {
    const char *escape = NULL;
    switch (*cursor) {
      case '\\': escape = "\\\\"; break;
      case '"': escape = "\\\""; break;
      case '\n': escape = "\\n"; break;
      case '\r': escape = "\\r"; break;
      case '\t': escape = "\\t"; break;
      default: break;
    }

    if (escape) {
      size_t length = strlen(escape);
      if (used + length + 2 > capacity) return false;
      memcpy(output + used, escape, length);
      used += length;
    } else {
      if (used + 2 > capacity) return false;
      output[used++] = (char)*cursor;
    }
  }
  output[used++] = '"';
  output[used] = '\0';
  return true;
}

static bool shell_quote(const char *source, char *output, size_t capacity) {
  if (!source || !output || capacity < 3) return false;

  size_t used = 0;
  output[used++] = '\'';
  for (const char *cursor = source; *cursor; cursor++) {
    if (*cursor == '\'') {
      static const char escape[] = "'\\\\''";
      if (used + sizeof(escape) > capacity) return false;
      memcpy(output + used, escape, sizeof(escape) - 1);
      used += sizeof(escape) - 1;
    } else {
      if (used + 2 > capacity) return false;
      output[used++] = *cursor;
    }
  }
  output[used++] = '\'';
  output[used] = '\0';
  return true;
}

static bool hypr_eval(const char *code) {
  char request[REQUEST_SIZE];
  int length = snprintf(request, sizeof(request), "eval %s", code);
  if (length <= 0 || (size_t)length >= sizeof(request)) return false;

  char response[RESPONSE_SIZE];
  return hypr_request(request, response, sizeof(response)) >= 0
      && strstr(response, "ok") != NULL;
}

static bool executable_path(const char *fallback, char *output, size_t capacity) {
  ssize_t length = readlink("/proc/self/exe", output, capacity - 1);
  if (length >= 0 && (size_t)length < capacity) {
    output[length] = '\0';
    return true;
  }

  if (!fallback || !*fallback || strlen(fallback) >= capacity) return false;
  (void)snprintf(output, capacity, "%s", fallback);
  return true;
}

static bool configure_click_binding(const char *bridge_path, bool install) {
  static const char remove_code[] =
      "do if _G.omarchy_tiny_hand_click_bind then "
      "_G.omarchy_tiny_hand_click_bind:unbind(); "
      "_G.omarchy_tiny_hand_click_bind = nil end end";
  if (!install) return hypr_eval(remove_code);

  char quoted_path[PATH_MAX * 4];
  if (!shell_quote(bridge_path, quoted_path, sizeof(quoted_path))) return false;

  char command[PATH_MAX * 4 + 16];
  int command_length = snprintf(command, sizeof(command), "%s click", quoted_path);
  if (command_length <= 0 || (size_t)command_length >= sizeof(command)) return false;

  char quoted_command[PATH_MAX * 4 + 32];
  if (!lua_quote(command, quoted_command, sizeof(quoted_command))) return false;

  char code[REQUEST_SIZE - 8];
  int code_length = snprintf(
      code, sizeof(code),
      "do if _G.omarchy_tiny_hand_click_bind then "
      "_G.omarchy_tiny_hand_click_bind:unbind() end; "
      "_G.omarchy_tiny_hand_click_bind = "
      "hl.bind(\"mouse:272\", hl.dsp.exec_cmd(%s), "
      "{ description = \"Tiny Hand click observer\", non_consuming = true, "
      "transparent = true, ignore_mods = true }) end",
      quoted_command);
  return code_length > 0 && (size_t)code_length < sizeof(code) && hypr_eval(code);
}

static bool configure_hotkey_binding(bool install) {
  static const char remove_code[] =
      "do if _G.omarchy_tiny_hand_hotkey_bind then "
      "_G.omarchy_tiny_hand_hotkey_bind:unbind(); "
      "_G.omarchy_tiny_hand_hotkey_bind = nil end end";
  static const char install_code[] =
      "do if _G.omarchy_tiny_hand_hotkey_bind then "
      "_G.omarchy_tiny_hand_hotkey_bind:unbind() end; "
      "_G.omarchy_tiny_hand_hotkey_bind = "
      "hl.bind(\"SUPER + ALT + P\", "
      "hl.dsp.exec_cmd(\"omarchy-shell -q tiny-hand toggle\"), "
      "{ description = \"Toggle Tiny Hand\" }) end";
  return hypr_eval(install ? install_code : remove_code);
}

static bool replace_owner_token(const char *path) {
  char token[32];
  int length = snprintf(token, sizeof(token), "%lu", (unsigned long)getpid());
  if (length <= 0 || (size_t)length >= sizeof(token)) return false;
  (void)unlink(path);
  return symlink(token, path) == 0;
}

static bool owns_token(const char *path) {
  char expected[32];
  int expected_length = snprintf(expected, sizeof(expected), "%lu",
                                 (unsigned long)getpid());
  if (expected_length <= 0 || (size_t)expected_length >= sizeof(expected)) return false;

  char actual[32];
  ssize_t actual_length = readlink(path, actual, sizeof(actual) - 1);
  if (actual_length < 0) return false;
  actual[actual_length] = '\0';
  return strcmp(actual, expected) == 0;
}

static bool read_owner_pid(const char *path, pid_t *owner) {
  char token[32];
  ssize_t length = readlink(path, token, sizeof(token) - 1);
  if (length <= 0) return false;
  token[length] = '\0';

  errno = 0;
  char *end = NULL;
  long value = strtol(token, &end, 10);
  if (errno != 0 || end == token || *end != '\0' || value <= 1 || value > INT_MAX) {
    return false;
  }
  *owner = (pid_t)value;
  return true;
}

static bool owner_became_stale(const char *path, pid_t original_owner) {
  const struct timespec pause = { .tv_sec = 0, .tv_nsec = 20000000L };
  for (int attempt = 0; attempt < 100; attempt++) {
    pid_t current_owner = 0;
    if (!read_owner_pid(path, &current_owner) || current_owner != original_owner) {
      return false;
    }
    if (kill(original_owner, 0) < 0 && errno == ESRCH) return true;
    (void)nanosleep(&pause, NULL);
  }
  return false;
}

static int make_click_server(void) {
  int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0);
  if (fd < 0) return -1;

  struct sockaddr_un address = { .sun_family = AF_UNIX };
  (void)snprintf(address.sun_path, sizeof(address.sun_path), "%s", bridge_socket_path);
  (void)unlink(bridge_socket_path);

  if (bind(fd, (struct sockaddr *)&address, sizeof(address)) < 0
      || chmod(bridge_socket_path, S_IRUSR | S_IWUSR) < 0
      || listen(fd, 16) < 0) {
    close(fd);
    (void)unlink(bridge_socket_path);
    return -1;
  }

  if (!replace_owner_token(bridge_owner_path)) {
    close(fd);
    (void)unlink(bridge_socket_path);
    return -1;
  }
  return fd;
}

// A replacement bridge binds the same public socket path before the retiring
// process has necessarily exited. Linux reports different inode namespaces for
// a bound AF_UNIX descriptor and its filesystem node, so fstat/lstat cannot
// establish ownership. A tiny PID symlink is the generation token instead:
// only the process whose token remains current may unlink the public listener
// or reveal the system cursor.
static bool owns_click_socket(void) {
  return owns_token(bridge_owner_path);
}

static void drain_clicks(int server_fd) {
  for (;;) {
    int client = accept4(server_fd, NULL, NULL, SOCK_CLOEXEC | SOCK_NONBLOCK);
    if (client < 0) {
      if (errno == EINTR) continue;
      return;
    }

    char message[32];
    ssize_t count = read(client, message, sizeof(message));
    close(client);
    if (count > 0) {
      if (fputs("C\n", stdout) == EOF || fflush(stdout) == EOF) {
        keep_running = 0;
        return;
      }
    }
  }
}

static void add_nanoseconds(struct timespec *time, long nanoseconds) {
  time->tv_nsec += nanoseconds;
  while (time->tv_nsec >= 1000000000L) {
    time->tv_nsec -= 1000000000L;
    time->tv_sec += 1;
  }
}

static void install_signal_handlers(void) {
  struct sigaction action = {0};
  action.sa_handler = request_stop;
  sigemptyset(&action.sa_mask);
  (void)sigaction(SIGTERM, &action, NULL);
  (void)sigaction(SIGINT, &action, NULL);
  (void)sigaction(SIGHUP, &action, NULL);
  signal(SIGPIPE, SIG_IGN);
}

static bool watch_parent(void) {
  pid_t parent = getppid();
  return prctl(PR_SET_PDEATHSIG, SIGTERM) == 0 && getppid() == parent;
}

static int stream_events(const char *executable) {
  if (!build_paths()) {
    fputs("tiny-hand-bridge: Hyprland session environment is unavailable\n", stderr);
    return 1;
  }

  int server_fd = make_click_server();
  if (server_fd < 0) {
    fprintf(stderr, "tiny-hand-bridge: cannot create %s: %s\n",
            bridge_socket_path, strerror(errno));
    return 1;
  }

  if (!watch_parent()) {
    bool still_owner = owns_click_socket();
    close(server_fd);
    if (still_owner) {
      (void)unlink(bridge_socket_path);
      (void)unlink(bridge_owner_path);
    }
    return 1;
  }

  install_signal_handlers();

  char resolved_executable[PATH_MAX];
  bool click_binding_installed = executable_path(executable, resolved_executable,
                                                   sizeof(resolved_executable))
      && configure_click_binding(resolved_executable, true);
  if (!click_binding_installed) {
    fputs("tiny-hand-bridge: click observer could not be registered\n", stderr);
  }

  double previous_x = 0;
  double previous_y = 0;
  bool previous_valid = false;
  unsigned int frame_count = 0;
  int consecutive_failures = 0;
  struct timespec next_frame;
  clock_gettime(CLOCK_MONOTONIC, &next_frame);

  const char *keep_cursor = getenv("TINY_HAND_KEEP_SYSTEM_CURSOR");
  bool should_hide_cursor = !keep_cursor || strcmp(keep_cursor, "1") != 0;
  if (should_hide_cursor) set_cursor_hidden(true);

  while (keep_running) {
    drain_clicks(server_fd);

    double x = 0;
    double y = 0;
    if (query_cursor(&x, &y)) {
      consecutive_failures = 0;
      if (!previous_valid || x != previous_x || y != previous_y) {
        if (printf("M %.3f %.3f\n", x, y) < 0 || fflush(stdout) == EOF) break;
        previous_x = x;
        previous_y = y;
        previous_valid = true;
      }
    } else if (++consecutive_failures == 30) {
      fputs("tiny-hand-bridge: waiting for Hyprland cursor IPC\n", stderr);
    }

    // Older plugin releases always revealed the cursor while retiring. A
    // replacement can start slightly before that cleanup finishes, so assert
    // ownership again during the first second of the new stream. Combined
    // with the inode check below, current releases hand off without flicker
    // and upgrades from the original bridge do not leave two cursors behind.
    frame_count++;
    if (should_hide_cursor && (frame_count == 18U || frame_count == 60U)) {
      set_cursor_hidden(true);
    }

    add_nanoseconds(&next_frame, FRAME_NS);
    while (clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &next_frame, NULL) == EINTR
           && keep_running) {}
  }

  bool still_owner = owns_click_socket();
  close(server_fd);
  if (still_owner) {
    if (click_binding_installed && !configure_click_binding(NULL, false)) {
      fputs("tiny-hand-bridge: click observer could not be removed\n", stderr);
    }
    (void)unlink(bridge_socket_path);
    (void)unlink(bridge_owner_path);
    if (cursor_was_hidden) set_cursor_hidden(false);
  }
  return 0;
}

static int hotkey_events(void) {
  if (!build_paths()) {
    fputs("tiny-hand-bridge: Hyprland session environment is unavailable\n", stderr);
    return 1;
  }
  if (!watch_parent()) return 1;
  install_signal_handlers();

  if (!configure_hotkey_binding(true)) {
    fputs("tiny-hand-bridge: toggle shortcut could not be registered\n", stderr);
    return 1;
  }
  if (!replace_owner_token(hotkey_owner_path)) {
    (void)configure_hotkey_binding(false);
    fputs("tiny-hand-bridge: toggle shortcut ownership could not be recorded\n", stderr);
    return 1;
  }

  while (keep_running) {
    int result = poll(NULL, 0, -1);
    if (result < 0 && errno != EINTR) break;
  }

  if (owns_token(hotkey_owner_path)) {
    if (!configure_hotkey_binding(false)) {
      fputs("tiny-hand-bridge: toggle shortcut could not be removed\n", stderr);
    }
    (void)unlink(hotkey_owner_path);
  }
  return 0;
}

// Quickshell normally terminates Process children gracefully when `running`
// becomes false, but destroying an entire plugin can kill them before their
// signal handlers finish. This detached fallback removes only bindings whose
// recorded owner generation has actually died. If a replacement helper has
// claimed either token, it is left untouched.
static int cleanup_stale_runtime(void) {
  if (!build_paths()) return 0;

  pid_t click_owner = 0;
  pid_t hotkey_owner = 0;
  bool stale_click = read_owner_pid(bridge_owner_path, &click_owner)
      && owner_became_stale(bridge_owner_path, click_owner);
  bool stale_hotkey = read_owner_pid(hotkey_owner_path, &hotkey_owner)
      && owner_became_stale(hotkey_owner_path, hotkey_owner);

  if (stale_click) {
    (void)configure_click_binding(NULL, false);
    (void)unlink(bridge_socket_path);
    (void)unlink(bridge_owner_path);
    set_cursor_hidden(false);
  }
  if (stale_hotkey) {
    (void)configure_hotkey_binding(false);
    (void)unlink(hotkey_owner_path);
  }
  return 0;
}

static int send_click(void) {
  if (!build_paths()) return 0;

  int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
  if (fd < 0) return 0;
  struct sockaddr_un address = { .sun_family = AF_UNIX };
  (void)snprintf(address.sun_path, sizeof(address.sun_path), "%s", bridge_socket_path);
  if (connect(fd, (struct sockaddr *)&address, sizeof(address)) == 0) {
    (void)write_all(fd, "click\n", 6);
  }
  close(fd);
  return 0;
}

static int parse_for_test(const char *json) {
  double x = 0;
  double y = 0;
  if (!parse_cursor_json(json, &x, &y)) return 1;
  printf("%.3f %.3f\n", x, y);
  return 0;
}

static void print_usage(FILE *stream) {
  fputs("Usage: tiny-hand-bridge <stream|hotkey|cleanup|click|parse> [json]\n", stream);
}

int main(int argc, char **argv) {
  if (argc == 2 && strcmp(argv[1], "stream") == 0) return stream_events(argv[0]);
  if (argc == 2 && strcmp(argv[1], "hotkey") == 0) return hotkey_events();
  if (argc == 2 && strcmp(argv[1], "cleanup") == 0) return cleanup_stale_runtime();
  if (argc == 2 && strcmp(argv[1], "click") == 0) return send_click();
  if (argc == 3 && strcmp(argv[1], "parse") == 0) return parse_for_test(argv[2]);
  print_usage(stderr);
  return 2;
}
