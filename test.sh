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
test -f python.tar.gz
test -f python.pkg
tar -ztvf python.tar.gz

# Test Python without dependencies, compress and custom output tarball name
brew pkg --name python-without-deps --compress python@3.12
test -f python-without-deps.tar.gz
test -f python-without-deps.pkg
tar -ztvf python-without-deps.tar.gz

# Test Ruby with additional dependencies, compress and custom output tarball name
brew install ruby@3.3
brew pkg --name ruby-with-python --compress --relocatable --additional-deps python@3.12 ruby@3.3
test -f ruby-with-python.tar.gz
test -f ruby-with-python.pkg
tar -ztvf ruby-with-python.tar.gz

ls -lh python.tar.gz python.pkg python-without-deps.tar.gz python-without-deps.pkg ruby-with-python.tar.gz ruby-with-python.pkg

# Symlink tests
verify_symlinks() {
    local tarball=$1
    local extract_dir="/tmp/verify_$$"
    
    echo "Verifying symlinks in $tarball..."
    
    rm -rf "$extract_dir"
    mkdir -p "$extract_dir"
    tar -xzf "$tarball" -C "$extract_dir"
    
    local symlink_count=0
    local broken_count=0
    local absolute_count=0
    
    while IFS= read -r -d '' link; do
        symlink_count=$((symlink_count + 1))
        local target
        target=$(readlink "$link")
        
        if [[ "$target" == /* ]]; then
            echo "ERROR: Absolute symlink found: $link -> $target"
            absolute_count=$((absolute_count + 1))
        fi
        
        local link_dir
        link_dir=$(dirname "$link")
        local resolved="${link_dir}/${target}"
        
        if [[ ! -e "$resolved" ]]; then
            echo "ERROR: Broken symlink: $link -> $target"
            broken_count=$((broken_count + 1))
        fi
    done < <(find "$extract_dir" -type l -print0)
    
    rm -rf "$extract_dir"
    
    if [[ $absolute_count -gt 0 ]]; then
        echo "FAIL: Found $absolute_count absolute symlinks in $tarball"
        return 1
    fi
    
    if [[ $broken_count -gt 0 ]]; then
        echo "FAIL: Found $broken_count broken symlinks in $tarball"
        return 1
    fi
    
    if [[ $symlink_count -eq 0 ]]; then
        echo "FAIL: No symlinks found in $tarball"
        return 1
    fi
    
    echo "PASS: $tarball has $symlink_count valid relative symlinks"
    return 0
}

verify_symlinks python.tar.gz
verify_symlinks python-without-deps.tar.gz
verify_symlinks ruby-with-python.tar.gz

echo "All symlink verification tests passed"
