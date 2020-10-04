## Remake / Premake

Remake is a proxy for premake. It cleans up some extra code that could get unruly or annoying and makes dependency management of libraries a little easier / clearer. Atm it's about half a module and used as a require for now. I may get around to making it a full module when I get more time to do so.

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

The point of this is to provide a linked dependency management functionality to premake. If a project is 'using' a shared lib that includes this functionality then it's settings and linkables will be folded into the current project automatically.


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
Functionality to define a project like scoped dependency that will not be built but specifies linkages, includes and defines that are needed for the library. The 'using' function recognizes and merges these libraries managing their dependencies. It does not specify a project. A library is just metadata that's used to manage dependencies.

Example:
```
library "sdl2"
	public.includedirs "include"
	public.libdirs "libs/x86_64"
	public.defines "SDL_SHARED"
	public.links "sdl2"
```

#### *includeall*
Scans a path including all 'premake5.lua' files found. This will execute a recursive path scan.

#### *distcopy*
Proxy for *postbuildcommand* {COPY}. Combine with mytarget() to make a postbuild commdand copy of your target.

#### *distmirror*
Like distcopy but accepts mulitple paths.

#### *mytarget*
Used for postbuildcommand and *Config*. Literally results in %{cfg.buildcfg}/%{cfg.architecture}/%{cfg.buildtarget.name}


### Extra functionality

#### pkgcfg

Does what is sounds like. Executes `pkg-config --cflags --libs $libname` and imports the configuration into a table that it returns. Errors if no package found.

#### applypkg

Applies a configuration generated from pkgcfg to the current scope. Imports includes, defines, etc.

Example: ```applypkg(pkgcfg('SDL2_mixer'))```


### Simple Example

Below is a simple example for linux. It shows that the console app "example" is using "sdl2". This is processed into example being linked with everything "sdl2" is linked with as well as all of it's shared/public defines, includedirs, libdirs, etc. Triggering "os" to be pulled into "example" and linking the specified libraries "m", "rt", "pthread", "dl"...

```
require "remake"
workspace "exampleapp"
	configurations { "Debug", "Release" }
	architecture "x64"

    paths = Config('source', 'libs', 'build', 'dist')

library "os"
    public.links { "m", "rt", "pthread", "dl" }

library "sdl2"
    applypkg(pkgcfg('SDL2'))
    applypkg(pkgcfg('SDL2_image'))
    applypkg(pkgcfg('SDL2_mixer'))
    using "os"

library{} -- like filter{}, it clears the tracked library scope

project "example"
    kind "consoleapp"
    language "c++"
    cppdialect "c++14"

    files "*.cpp"

    using "sdl"

    distcopy()
    --[[
    copy the resulting exe to dist/
    nothing else needs to be specified as it defaults to mytarget()
    ]]--
```
