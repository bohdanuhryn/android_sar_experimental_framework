#!/bin/bash

packages=($1)
for package in "${packages[@]}"; do
    adb shell am force-stop "$package"
done
