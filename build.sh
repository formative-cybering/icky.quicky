#!/bin/bash

rm -f icky

valac --pkg gtk4 --pkg gio-2.0 --pkg gio-unix-2.0 --pkg webkit2gtk-4.0 --pkg posix -o quicky quicky.vala
