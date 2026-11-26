#!/bin/bash
# 2clip.sh - copy a file or command output to clipboard via OSC 52

usage() {
    echo "Usage:"
    echo "  2clip.sh <file>         - copy file contents"
    echo "  2clip.sh -c <command>   - copy command output"
    echo "  echo 'text' | 2clip.sh  - copy from stdin"
    exit 1
}

copy_to_clipboard() {
    base64 -w0 | printf "\e]52;c;$(cat)\a"
}

if [[ $# -eq 0 ]]; then
    # Stdin mode: echo 'hello' | 2clip.sh
    if [ -t 0 ]; then
        usage
    fi
    copy_to_clipboard
elif [[ "$1" == "-c" ]]; then
    # Command mode: 2clip.sh -c "ls -la"
    shift
    if [[ $# -eq 0 ]]; then
        echo "Error: provide a command after -c"
        exit 1
    fi
    eval "$@" | copy_to_clipboard
elif [[ -f "$1" ]]; then
    # File mode: 2clip.sh file.txt
    copy_to_clipboard < "$1"
else
    echo "Error: file '$1' not found"
    exit 1
fi
