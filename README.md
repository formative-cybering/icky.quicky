# Icky Quicky

Degenerate web browser

CLI:

```sh
# start daemon
quicky

# open browser with url
quicky "http://localhost:8080"
```

hyprland.conf example:

```hyprlang
exec-once = quicky

windowrule = size 1200 800, class:^(icky.quicky)
windowrule = noinitialfocus, class:^(icky.quicky)
```

---

Build: requires vala, gtk4, glib2 + webkitgtk-6.0

```sh
./build.sh
```

Run:

```sh
./quicky
```
