#!/usr/bin/env bash
set -euxo pipefail

# Install latest brew
if [[ $(command -v brew) == "" ]]; then
    echo "Installing brew in order to build MetaCall"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install brew-pkg
brew tap --verbose metacall/brew-pkg
brew install --verbose --HEAD metacall/brew-pkg/brew-pkg

# Test Python with dependencies, compress and custom output tarball name
brew install python@3.12
brew pkg --output python --with-deps --compress python@3.12
test -f python.tgz
test -f python.pkg

brew pkg --output python-without-deps --compress python@3.12
test -f python-without-deps.tgz
test -f python-without-deps.pkg
tar -ztvf python-without-deps.tgz
