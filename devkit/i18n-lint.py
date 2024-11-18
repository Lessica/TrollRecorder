#!/usr/bin/env python3

import os
import subprocess

def lint_strings_files(directory):
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith('.strings') or file.endswith('.stringsdict'):
                file_path = os.path.join(root, file)
                try:
                    subprocess.run(['plutil', '-lint', file_path], check=True)
                    print(f"Linting passed for {file_path}")
                except subprocess.CalledProcessError:
                    print(f"Linting failed for {file_path}")

if __name__ == "__main__":
    lint_strings_files('res')
