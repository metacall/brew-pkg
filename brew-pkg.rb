# Builds an OS X installer package from an installed formula.
require 'formula'
require 'optparse'
require 'tmpdir'
require 'open3'

def patchelf(binary)
  stdout, status = Open3.capture2("otool -L #{binary}")
  old_lib = stdout.lines.grep(/#{lib_regex}/).first&.split&.first
end

# # change the hardcoded ../Frameworks relative path that Xcode does by rewriting the binaries after the build
# # check with:
# #   otool -L <binary>

# # this is the new location
# # make sure this is the same Destination the Frameworks are copied to in the "Copy Files" step
# # the default "@executable_path/" would be Destination = Products Directory
# NEW_FRAMEWORKS_PATH="@executable_path/"

# # the one we want to replace
# DEFAULT_FRAMEWORKS_PATH="@executable_path/../Frameworks/"

# function change_binary {
#     local libpaths=`otool -L "$1" | grep "$DEFAULT_FRAMEWORKS_PATH" | tr '\t' ' ' | cut -d " " -f2`
#     local lib
#     for lib in $libpaths; do
#         if [ "$2" == "recursive" ]; then
#             local libbinary=`echo $lib | sed "s,$DEFAULT_FRAMEWORKS_PATH,,"`
#             change_binary "$libbinary"
#         fi
#         local newlib=`echo $lib | sed "s,$DEFAULT_FRAMEWORKS_PATH,$NEW_FRAMEWORKS_PATH,"`;
#         echo "changing library path in '$1': '$lib' => '$newlib'"
#         install_name_tool -change "$lib" "$newlib" "$1"
#     done
# }

# cd $BUILT_PRODUCTS_DIR
# change_binary "$EXECUTABLE_NAME" recursive

# INSTALL_DIR = if ENV['METACALL_ARCH'] == 'arm64'
#                 'opt/homebrew'
#               else
#                 'usr/local'
#               end

# def change_library_path(loader)
#   lib_regex = INSTALL_DIR
#   metacall_lib = "distributable/metacall-core/lib/lib#{loader}_loader.so"

#   stdout, status = Open3.capture2("otool -L #{metacall_lib}")
#   old_lib = stdout.lines.grep(/#{lib_regex}/).first&.split&.first

#   if old_lib
#     old_lib_regex = old_lib.split('/').last(3).join('/')
#     new_lib = Dir.chdir('distributable') do
#       Dir.glob("**/*").find { |f| File.file?(f) && f.end_with?(old_lib_regex) }
#     end

#     if new_lib
#       system("install_name_tool -change #{old_lib} @loader_path/../.#{new_lib} #{metacall_lib}")
#       puts "Updated #{loader} loader: #{old_lib} -> #{new_lib}"
#     else
#       puts "Failed to update #{loader} loader: Could not find the new library path."
#     end
#   else
#     puts "Failed to update #{loader} loader: Could not find the old library path."
#   end
# end

# change_library_path() {
#   loader=$1
#   lib_regex=$INSTALL_DIR
#   metacall_lib=distributable/metacall-core/lib/lib${loader}_loader.so

#   old_lib=$(otool -L "$metacall_lib" | grep -E "$lib_regex" | awk '{print $1}')
#   old_lib_regex=$(echo $old_lib | awk -F'/' '{print $(NF-2)"/"$(NF-1)"/"$NF}') # Get the path suffix
#   new_lib=$(cd distributable && find . -type f -regex ".*/$old_lib_regex")

#   if [ -n "$old_lib" ] && [ -n "$new_lib" ]; then
#     install_name_tool -change "$old_lib" "@loader_path/../.$new_lib" "$metacall_lib"
#     echo "Updated $loader loader: $old_lib -> $new_lib"
#   else
#     echo "Failed to update $loader loader: Could not find the old or new library path."
#   fi
# }

module Homebrew extend self
  def pkg
    options = {
      identifier_prefix: 'org.homebrew',
      with_deps: false,
      without_kegs: false,
      scripts_path: '',
      output_dir: '',
      compress: false,
      package_name: '',
      ownership: '',
      additional_deps: []
    }
    packages = []

    option_parser = OptionParser.new do |opts|
      opts.banner = <<-EOS
Usage: brew pkg [--identifier-prefix] [--with-deps] [--without-kegs] [--name] [--output-dir] [--compress] formula [...additional formulas]

Build an OS X installer package from a formula. It must be already
installed; 'brew pkg' doesn't handle this for you automatically. The
'--identifier-prefix' option is strongly recommended in order to follow
the conventions of OS X installer packages.
      EOS

      opts.on('-i', '--identifier-prefix identifier_prefix', 'Set a custom identifier prefix to be prepended') do |o|
        options[:identifier_prefix] = o.chomp('.')
      end

      opts.on('-d', '--with-deps', 'Include all the package\'s dependencies in the built package') do
        options[:with_deps] = true
      end

      opts.on('-k', '--without-kegs', 'Exclude package contents at /usr/local/Cellar/packagename') do
        options[:without_kegs] = true
      end

      opts.on('-s', '--scripts scripts_path', 'Set the path to custom preinstall and postinstall scripts') do |o|
        options[:scripts_path] = o
      end

      opts.on('-o', '--output-dir output_dir', 'Define the output dir where files will be copied') do |o|
        options[:output_dir] = o
      end

      opts.on('-c', '--compress', 'Generate a tgz file with the package files into the current folder') do
        options[:compress] = true
      end

      opts.on('-n', '--name package_name', 'Define a custom output package name') do |o|
        options[:package_name] = o
      end

      ownership_options = ['recommended', 'preserve', 'preserve-other']
      opts.on('-w', '--ownership ownership_mode', 'Define the ownership as: recommended, preserve or preserve-other') do |o|
        if ownership_options.include?(o)
          options[:ownership] = value
          ohai "Setting pkgbuild option --ownership with value #{value}"
        else
          opoo "#{value} is not a valid value for pkgbuild --ownership option, ignoring"
        end
      end

      opts.on('-a', '--additional-deps deps_separated_by_coma', 'Provide additional dependencies in order to package all them together') do |o|
        options[:additional_deps] = o.split(',')
      end
    end

    # Parse the command line arguments
    option_parser.parse!(ARGV)

    # Exit if there's no formula or there's more than one
    abort option_parser.banner if ARGV.length != 1

    # ARGV now contains the free arguments after parsing the options
    packages = [ARGV.first] + options[:additional_deps]
    ohai "Building packages: #{packages.join(', ')}"

    # Define the formula
    dependencies = []
    formulas = packages.map do |formula|
      f = Formulary.factory(formula)

      # Make sure it's installed first
      if !f.any_version_installed?
        onoe "#{f.name} is not installed. First install it with 'brew install #{f.name}'."
        abort
      end

      # Add deps if we specified --with-deps
      dependencies += f.recursive_dependencies if options[:with_deps]

      # TODO: Implement proper filtering
      # if options[:with_deps]
      #   dependencies += f.recursive_dependencies.reject do |dep|
      #     dep.build? || dep.test?
      #   end
      # end

      f
    end

    # Add the dependencies to the rest of formulas if any
    formulas += dependencies

    # Define the first package which is the main one
    f = formulas.first
    name = f.name
    identifier = options[:identifier_prefix] + ".#{name}"
    version = f.version.to_s
    version += "_#{f.revision}" if f.revision.to_s != '0'

    # If the package name is not defined, define the default one
    if options[:package_name] == ''
      options[:package_name] = "#{name}-#{version}"
    end

    # Setup staging dir
    if options[:output_dir] == ''
      options[:output_dir] = Dir.mktmpdir('brew-pkg')
    end

    staging_root = options[:output_dir] + HOMEBREW_PREFIX
    ohai "Creating package staging root using Homebrew prefix #{HOMEBREW_PREFIX}"
    FileUtils.mkdir_p staging_root

    formulas.each do |pkg|
      formula = Formulary.factory(pkg.to_s)

      dep_version = formula.version.to_s
      dep_version += "_#{formula.revision}" if formula.revision.to_s != '0'

      ohai "Staging formula #{formula.name}"

      # Get all directories for this keg, rsync to the staging root
      if File.exist?(File.join(HOMEBREW_CELLAR, formula.name, dep_version))

        dirs = Pathname.new(File.join(HOMEBREW_CELLAR, formula.name, dep_version)).children.select { |c| c.directory? }.collect { |p| p.to_s }

        dirs.each { |d| safe_system "rsync", "-a", "#{d}", "#{staging_root}/" }

        if File.exist?("#{HOMEBREW_CELLAR}/#{formula.name}/#{dep_version}") && !options[:without_deps]

          ohai "Staging directory #{HOMEBREW_CELLAR}/#{formula.name}/#{dep_version}"

          safe_system "mkdir", "-p", "#{staging_root}/Cellar/#{formula.name}/"
          safe_system "rsync", "-a", "#{HOMEBREW_CELLAR}/#{formula.name}/#{dep_version}", "#{staging_root}/Cellar/#{formula.name}/"
        end
      end

      # Write out a LaunchDaemon plist if we have one
      if formula.service?
        ohai "Plist found at #{formula.plist_name}, staging for /Library/LaunchDaemons/#{formula.plist_name}.plist"
        launch_daemon_dir = File.join staging_root, "Library", "LaunchDaemons"
        FileUtils.mkdir_p launch_daemon_dir
        fd = File.new(File.join(launch_daemon_dir, "#{formula.plist_name}.plist"), "w")
        fd.write formula.service.to_plist
        fd.close
      end
    end

    # Zip it
    if options[:compress]
      tgzfile = "#{options[:package_name]}.tgz"
      ohai "Compressing package #{tgzfile}"
      args = [ "-czf", tgzfile, "-C", staging_root, "." ]
      safe_system "tar", *args
    end

    # Add scripts if we specified --scripts
    found_scripts = false
    if options[:scripts_path] != ''
      if File.directory?(options[:scripts_path])
        pre = File.join(options[:scripts_path],"preinstall")
        post = File.join(options[:scripts_path],"postinstall")
        if File.exist?(pre)
          File.chmod(0755, pre)
          found_scripts = true
          ohai "Adding preinstall script"
        end
        if File.exist?(post)
          File.chmod(0755, post)
          found_scripts = true
          ohai "Adding postinstall script"
        end
      end
      if not found_scripts
        opoo "No scripts found in #{options[:scripts_path]}"
      end
    end

    # Build it
    pkgfile = "#{options[:package_name]}.pkg"
    ohai "Building package #{pkgfile}"
    args = [
      "--quiet",
      "--root", "#{options[:output_dir]}",
      "--identifier", identifier,
      "--version", version
    ]
    if found_scripts
      args << "--scripts"
      args << options[:scripts_path]
    end
    if options[:ownership] != ''
      args << "--ownership"
      args << options[:ownership]
    end
    args << "#{pkgfile}"
    safe_system "pkgbuild", *args

    FileUtils.rm_rf options[:output_dir]
  end
end

Homebrew.pkg
