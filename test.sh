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

# Test
brew pkg --with-deps --compress python

ls -la


# mv metacall-${METACALL_VERSION}.pkg release/metacall-tarball-macos-${METACALL_ARCH}.pkg
# mv metacall-${METACALL_VERSION}.tgz release/metacall-tarball-macos-${METACALL_ARCH}.tgz
