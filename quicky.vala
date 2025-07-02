using Posix;
using Gtk;
using WebKit;

public class IckyQuicky : Gtk.Application {
  private string current_url;
  private const string SOCKET_PATH = "/tmp/icky-quicky-daemon.sock";
  private const string PID_FILE = "/tmp/icky-quicky-daemon.pid";
  private SocketService? socket_service;
  private bool is_daemon = false;
  private Gtk.ApplicationWindow? win = null;
  private WebKit.WebView? webview = null;

  public IckyQuicky (string url) {
    Object (
      application_id: "icky.quicky",
      flags: ApplicationFlags.HANDLES_COMMAND_LINE | ApplicationFlags.NON_UNIQUE
    );
    this.current_url = url;
  }

  private void show_browser_window () {
    if (win == null) {
      win = new Gtk.ApplicationWindow (this);
      win.set_name("icky-quicky");
      win.set_default_size(800, 600);

      webview = new WebKit.WebView();
      win.set_child(webview);
    }
    if (webview != null) {
      webview.load_uri(this.current_url);
    }
    win.present();
  }

  public override void activate () {
    if (is_daemon) {
      start_daemon();
      hold();
    } else {
      show_browser_window();
    }
  }

  private void start_daemon () {
    try {
      socket_service = new SocketService();

      if (FileUtils.test(SOCKET_PATH, FileTest.EXISTS)) {
        FileUtils.unlink(SOCKET_PATH);
      }

      var socket_address = new UnixSocketAddress(SOCKET_PATH);
      socket_service.add_address(socket_address, SocketType.STREAM, SocketProtocol.DEFAULT, null, null);
      socket_service.incoming.connect(on_incoming_connection);
      socket_service.start();

      write_pid_file();
      print("Quicky daemon started\n");
    } catch (Error e) {
      GLib.stderr.printf("Error starting daemon: %s\n", e.message);
    }
  }

  private bool on_incoming_connection (SocketConnection connection, Object? source_object) {
    try {
      var input_stream = new DataInputStream(connection.input_stream);
      var message = input_stream.read_line();

      if (message != null && message.length > 0) {
        Idle.add(() => {
          this.current_url = message;
          show_browser_window();
          return false;
        });
      }
    } catch (Error e) {
      GLib.stderr.printf("Error handling connection: %s\n", e.message);
    }
    return false;
  }

  private void write_pid_file () {
    try {
      var file = File.new_for_path(PID_FILE);
      var output_stream = file.create(FileCreateFlags.REPLACE_DESTINATION);
      var data_stream = new DataOutputStream(output_stream);
      data_stream.put_string(((int)Posix.getpid()).to_string());
      output_stream.close();
    } catch (Error e) {
      GLib.stderr.printf("Error writing PID file: %s\n", e.message);
    }
  }

  public override int command_line (ApplicationCommandLine cmd) {
    string[] args = cmd.get_arguments();

    if (args.length > 1) {
      if (args[1] == "stop") {
        if (is_daemon_running()) {
          stop_daemon();
          print("Daemon stopped\n");
        } else {
          print("Daemon is not running\n");
        }
        return 0;
      } else {
        if (is_daemon_running()) {
          send_url_to_daemon(args[1]);
          return 0;
        } else {
          this.current_url = args[1];
          this.is_daemon = true;
          this.activate();
          Idle.add(() => {
            show_browser_window();
            return false;
          });
          return 0;
        }
      }
    } else {
      if (is_daemon_running()) {
        print("Daemon is already running\n");
        return 0;
      } else {
        this.current_url = "https://ill.computer";
        this.is_daemon = true;
        this.activate();
        return 0;
      }
    }
  }

  private bool is_daemon_running () {
    if (!FileUtils.test(PID_FILE, FileTest.EXISTS)) {
      return false;
    }

    try {
      string pid_content;
      FileUtils.get_contents(PID_FILE, out pid_content);
      pid_t pid = (pid_t)int.parse(pid_content.strip());

      if (Posix.kill((Posix.pid_t)pid, 0) == 0) {
        return true;
      } else {
        FileUtils.unlink(PID_FILE);
        if (FileUtils.test(SOCKET_PATH, FileTest.EXISTS)) {
          FileUtils.unlink(SOCKET_PATH);
        }
        return false;
      }
    } catch (Error e) {
      return false;
    }
  }

  private void send_url_to_daemon (string url) {
    try {
      var socket_client = new SocketClient();
      var socket_address = new UnixSocketAddress(SOCKET_PATH);
      var connection = socket_client.connect(socket_address);

      var output_stream = new DataOutputStream(connection.output_stream);
      output_stream.put_string(url + "\n");
      output_stream.close();
      connection.close();
    } catch (Error e) {
      GLib.stderr.printf("Error sending url to daemon: %s\n", e.message);
    }
  }

  private void stop_daemon () {
    try {
      string pid_content;
      if (FileUtils.get_contents(PID_FILE, out pid_content)) {
        pid_t pid = (pid_t)int.parse(pid_content.strip());
        Posix.kill((Posix.pid_t)pid, Posix.Signal.TERM);

        // Clean up files
        if (FileUtils.test(PID_FILE, FileTest.EXISTS)) {
          FileUtils.unlink(PID_FILE);
        }
        if (FileUtils.test(SOCKET_PATH, FileTest.EXISTS)) {
          FileUtils.unlink(SOCKET_PATH);
        }
      }
    } catch (Error e) {
      GLib.stderr.printf("Error stopping daemon: %s\n", e.message);
    }
  }

  public static int main (string[] args) {
    var app = new IckyQuicky ("https://ill.computer");

    Posix.signal(Posix.Signal.TERM, cleanup_on_exit);
    Posix.signal(Posix.Signal.INT, cleanup_on_exit);

    return app.run (args);
  }

  private static void cleanup_on_exit (int sig) {
    if (FileUtils.test(PID_FILE, FileTest.EXISTS)) {
      FileUtils.unlink(PID_FILE);
    }
    if (FileUtils.test(SOCKET_PATH, FileTest.EXISTS)) {
      FileUtils.unlink(SOCKET_PATH);
    }
    Posix.exit(0);
  }
}
