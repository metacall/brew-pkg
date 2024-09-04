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
brew pkg --name python --with-deps --compress python@3.12
test -f python.tgz
test -f python.pkg
# tar -ztvf python.tgz

brew pkg --name python-without-deps --compress python@3.12
test -f python-without-deps.tgz
test -f python-without-deps.pkg
# tar -ztvf python-without-deps.tgz

brew install ruby@3.3
brew pkg --name ruby-with-python --compress --relocatable --additional-deps python@3.12 ruby@3.3
test -f ruby-with-python.tgz
test -f ruby-with-python.pkg
# tar -ztvf ruby-with-python.tgz

# Debug files and sizes
ls -lh
