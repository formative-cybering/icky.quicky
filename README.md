# Icky Quicky

Degenerate web browser

CLI:

```sh
# start daemon
quicky

# add note
quicky "http://localhost:8080"
```

hyprland.conf example:

```hyprlang
exec-once = quicky

windowrule = size 500 200, class:^(icky.quicky)
windowrule = noinitialfocus, class:^(icky.quicky)
```

---

Build: requires vala, gtk4 + glib2 + libwebkit2gtk-4.0-dev

```sh
./build.sh
```

Run:

```sh
./quicky
```
