#!/usr/bin/env bash
set -euo pipefail
xcrun swift-format lint --recursive --strict Flashcards
