require 'pathname'


def patchelf(root_dir, prefix, binary)
  stdout = <<-EOS
./distributable/bin/python3:
	/usr/local/Cellar/python@3.12/3.12.5/Frameworks/Python.framework/Versions/3.12/Python (compatibility version 3.12.0, current version 3.12.0)
	/usr/local/Cellar/python@3.12/3.12.5/Frameworks/Python.framework/Versions/3.12/Python (compatibility version 3.12.0, current version 3.12.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1311.100.3)
EOS
  puts('DEBUG PATCHELF:')
  puts(root_dir)
  puts(prefix)
  puts(binary)
  binary_path = File.join(root_dir, prefix, binary)
  puts(binary_path)
  # return unless File.exist?(binary_path)
  puts("otool -L #{binary_path}")
  # stdout, status = Open3.capture2("otool -L #{binary_path}")
  puts(stdout)
  lib_paths = stdout.lines.grep(/#{prefix}/).map(&:lstrip)
  puts(lib_paths)
  lib_paths.each do |lib|
    # if File.exist?(lib)
    relative_path = Pathname.new(lib).relative_path_from(Pathname.new(File.join(prefix, File.dirname(binary))))
    new_lib = File.join('@executable_path', relative_path)
    puts("install_name_tool", "-change", lib, new_lib, binary_path)
      # system("install_name_tool", "-change", lib, new_lib, binary_path)

      # Recursively iterate through libraries
      # patchelf(root_path, prefix, lib.delete_prefix(prefix))
    # end
  end
end




# def patchelf(binary, prefix)
#   stdout = <<-EOS
# ./distributable/bin/python3:
# 	/usr/local/Cellar/python@3.12/3.12.5/Frameworks/Python.framework/Versions/3.12/Python (compatibility version 3.12.0, current version 3.12.0)
# 	/usr/local/Cellar/python@3.12/3.12.5/Frameworks/Python.framework/Versions/3.12/Python (compatibility version 3.12.0, current version 3.12.0)
# 	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1311.100.3)
# EOS
#   binary_path = Pathname.new(binary.delete_prefix(prefix))
#   # return unless File.exist?(binary_path)
#   puts("otool -L #{binary_path}")
#   # stdout, status = Open3.capture2("otool -L #{binary_path}")
#   lib_paths = stdout.lines.grep(/#{prefix}/).map(&:lstrip)
#   puts(lib_paths)
#   lib_paths.each do |lib|
#     puts('LIB', lib)
#     puts('.................')
#     # if File.exist?(lib)
#       # Recursively iterate through libraries
#       # patchelf(lib, prefix)
#     relative_path = Pathname.new(lib).relative_path_from(Pathname.new(File.dirname(binary)))
#     new_lib = File.join('@executable_path', relative_path)
#     puts("install_name_tool", "-change", lib, new_lib, binary_path)
#       # system("install_name_tool", "-change", lib, relative_path, binary_path)
#     # end
#   end
# end

patchelf('/tmp/random', '/usr/local/', 'bin/python3')


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