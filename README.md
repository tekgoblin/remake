## Remake / Premake

Extra functionality for premake5 projects. Atm it's not a module just an include, so it acts as a proxy to premake in featured places.

### Features

#### *Config*
Proxy over various premake commands to enforce a project and build structure. Makes it nicer to configure for more complex projects that benefit from shared pathing configurations. All paths are expanded to their full path instead of relative paths. Helps with *distcopy* and the like to ensure copies go to the right place beneath linux, windows, etc.

This is a legacy function that may disappear or be reduced in functionality. Still useful to me, so for now it's staying.

Example:
```
workspace "tests"
	paths = Config('source', '3rdparty', 'build', 'dist', {
		['VULKAN_SDK'] = "/usr/local/VulkanSDK/1.1.82.1",
		['Qt'] = '/usr/shared/Qt/5.9.6',
	})
```

This creates a paths variable that contains the current setup of the configuration. i.e:
```
    paths.base = Current working directory
    paths.source = base/source
    paths.3rdparty = base/3rdparty
    paths.build = base/build
    paths.buildLib = build/%{cfg.buildcfg}/%{cfg.architecture}
    paths.dist = base/dist    
    paths.extra.VULKAN_SDK = "/usr/local/VulkanSDK/1.1.82.1"
    paths.extra.Qt = '/usr/shared/Qt/5.9.6'
```	

While Executing:
```
location (paths.build)
targetdir (paths.buildLib)
syslibdirs (paths.buildLib)
libdirs (paths.buildLib)

Create full path to paths.dist
```	


#### *using*
Limited dependency resolution functionality. Provide only names of projects or libraries to this function.

**Note**: This function should be used last in a project definition. Any module specifed here should already be defined and accessible, otherwise it may only specify a *links* dependency only.

    
Example:
```
using { "sdl2", "sdl2main", "opengl32" }
```

This will fold all known settings for sdl2, sdl2main, and opengl32 into the current project if they exist. Otherwise it will be added to a links directive as a passthrough fallback. i.e. opengl32 is vendor provided lib, so it will be linked unless you've defined it as a project name or a library definition like shown below.


#### *public, shared*
Scoped definition functionality that act on the current project/lib and/or are exported publicly.
These include proxies functions for: *defines*, *includedirs*, *libdirs* and *links*.

Example:
```
shared.defines { "DEBUG" }      -- Defined for any project using this one, and itself
public.defines { "SHARED_LIB" } -- Defined only for projects usning this one
defines { "NOT_EXPORTED" } -- Defined only for this project, normal premake
```	

#### *library*
Limited functionality to define a dependency that will not be built but 'using' recognizes and merges settings for linking, defines, etc.
Since this include is a proxy, this functionality is a little more ugly. Do not use a shared scope in these as it's not a real project.
Example:
```
library("sdl2", function()
	public.includedirs "include"
	public.libdirs "libs/x86_64"
	public.defines "SDL_SHARED"
	public.links "sdl2"
end)
```	

#### *includeall*
Scans a path including all 'premake5.lua' files found. This will execute a recursive path scan.

#### *mytarget*
Used for postbuildcommand and *Config*. Literally results in %{cfg.buildcfg}/%{cfg.architecture}/%{cfg.buildtarget.name}

#### *distcopy*
Proxy for *postbuildcommand* {COPY}. Combine with mytarget() to make a postbuild commdand copy of your target.

#### *distmirror*
Like distcopy but accepts mulitple paths.
