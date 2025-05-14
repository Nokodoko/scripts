#!/bin/env python3

brightness_file = '/sys/class/backlight/intel_backlight/brightness'

try:
    with open(brightness_file, 'r') as file:
        current_val = int(file.read().strip())
except FileNotFoundError:
    print(f"{brightness_file} not found")
    exit(1)
except ValueError:
    print(f"Could not convert value in {brightness_file} to an int")
    exit(1)

new_val = current_val - 50
try:
    with open(brightness_file, 'w') as file:
        file.write(str(new_val))
except IOError as e:
    print(
        f"Unable to write to {brightness_file}, try again with sudo")
    print(f"IOError: {e}")
    exit(1)
