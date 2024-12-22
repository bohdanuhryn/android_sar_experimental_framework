#!/bin/bash

packages=($1)
for package in "${packages[@]}"; do
    adb shell monkey -p "$package" -c android.intent.category.LAUNCHER 1
done
