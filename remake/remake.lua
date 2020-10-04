---
-- Remake: Premake proxy
-- Copyright (c) 2018-2020 tekgoblin
---

local ISDEBUG = false
local ISWIN = false
if os.host() == "windows" then
	ISWIN=true
end

include "extensions.lua"

local function debuglog(msg)
	if ISDEBUG then
		print(msg)
	end
end

local function remakeError(s)
    premake.error("remake error: " .. s)
end

--========================================================================================
-- remake state

local gConfig = nil     -- global project configuration container
local exports = Table() -- holds all exported information from libraries / projects
local _m = nil          -- current library/project scope
local _oldprj = project -- because yes, i'm wrapping project to track scopes
local _oldgrp = group

Config = Class()
function Config:new(source, libs, build, dist, extra)
    local self = settype(Config, {
	    base = _WORKING_DIR,
	    libs = path.join(_WORKING_DIR, npath(libs)),
	    source = path.join(_WORKING_DIR, npath(source)),
	    build = path.join(_WORKING_DIR, npath(build)),
	    dist = path.join(_WORKING_DIR, npath(dist)),
	    --self.buildLib = path.join(self.build, "%{cfg.buildcfg}", "%{cfg.architecture}")
        extra = foreach(extra, normalizepath),
    })

	location (self.build)
	--targetdir (self.build)
	syslibdirs (self.build)
	libdirs (self.build)

	----debugdir (self.dist)
	--targetdir (self.buildLib)

	path.ensure(self.dist)

	gConfig = self
	return self
end

function Config:dump(indent)
	print("Remake config")

	print("Base Path      : ", self.base)
	print("Lib Path       : ", self.libs)
	print("Source Path    : ", self.source)
	print("Build Path     : ", self.build)
	--print("Build Libs Path: ", self.buildLib)
	print("Output Path    : ", self.dist)

	print("Extra Paths    : ")
	self.extra:each(function(v,k)
		print("\t" .. k .. '\t @ ' .. v)
	end)

	print()
end

function Config:getCRoot()
	return os.getcwd():gsub(gConfig.base .. '/', '')
end

local function clearscope()
    _m = nil
end

local function getScope(modonly)
    if _m ~= nil then return _m.name end
    if modonly ~= nil then return nil end

	local p = project()
	if p == nil then
		remakeError("Can't determine project scope. Not a module and project() is nil")
	end
	return p.name
end

local function getModule(name)
	return exports[name] or nil
end

local function newModule(libname, ismod)
    if libname == nil then
        remakeError("Can't create nil module")
    end
    if ismod == nil or type(ismod) ~= 'boolean' then
        ismod = false
    end

	exports[libname] = Table {
		name = libname,
		ismodule = ismod,
		merged = false,
		public = Table(),
	}

	return exports[libname]
end

local function ensureModule(name)
	return getModule(name) or newModule(name)
end

local function kmerge(name, key, list)
	local ctx = ensureModule(name)
	local target = ctx.public:ensureKey(key)
	if key == 'includedirs' or key == 'libdirs' then
		target:append(foreach(list, normalizepath))
	else
		target:append(list)
	end
end

local function processlib(self)
    if self == nil then
        print("Can't process a nil module")
        return
	end

    local type = 'library'
    if not self.ismodule then
        type = 'project'
	end

	io.write("Processing '" .. type .. "': '" .. self.name .. "'")
	if self.merged then
		print(", already processed!")
		return
	end

	debuglog("")
    debuglog("\t'using' for " .. self.name)
	local validk = Table { 'includedirs', 'libdirs', 'links', 'defines', 'using' }
	local list = self.public['using'] or Table()
	list:each(function(mod,k)
		debuglog("\tChecking for module: '" .. mod .. "'")
		local m = getModule(mod)
		if m == nil then
			remakeError("Project/library '" .. mod .. "' doesn't exist or isn't in scope")
		end

		debuglog("\t\t" ..  mod)
		validk:each(function(v,_)
			if m.public[v] == nil then return end
			debuglog("\t\t\t" .. v)
			if v ~= 'using' then
				public[v](m.public[v])
			end
		end)

		if not m.ismodule then
			shared.links(m.name)
		else
			debuglog("\tSkipping link for module: '" .. m.name .. "'")
		end
		debuglog("...")
	end)
	--print("Module(" .. self.name .. ") processed")
	print(", done...")
	self.merged = true

	if not self.ismodule then
		debuglog("Applying linkages for '" .. self.name .. "': ")
		--apply public linkages
		validk:each(function(v,_)
			if v == 'using' then return end
			if self.public[v] == nil then return end
			local fn = nil
			if v == 'defines' then
				debuglog('Defines: ')
				fn = defines
			elseif v == 'includedirs' then
				debuglog('IncludeDirs: ')
				fn = includedirs
			elseif v == 'libdirs' then
				debuglog('LibDirs: ')
				fn = libdirs
			elseif v == 'links' then
				debuglog('Links: ')
				fn = links
			else
				return
			end
			if ISDEBUG == true then
			self.public[v]:dump()
			end
			fn(self.public[v])
		end)
	else
		debuglog("linkages:")
		if ISDEBUG == true then
		self.public:dump()
		end
	end
	debuglog("------")
	--self:dump()
end

function remakedump()
    print("---------------------------")
    print("Dumping remake state")
    exports:dump()
    print("---------------------------")
end

public = Table {
	includedirs  = function(list) kmerge(getScope(), 'includedirs', list) end,
	libdirs      = function(list) kmerge(getScope(), 'libdirs', list) end,
	defines      = function(list) kmerge(getScope(), 'defines', list) end,
	links        = function(list) kmerge(getScope(), 'links', list) end,
	buildoptions = function(list) kmerge(getScope(), 'buildoptions', list) end,
}

shared = Table {
	includedirs = function(list)
		public.includedirs(list)
		includedirs(list)
	end,
	libdirs = function(list)
		public.libdirs(list)
		libdirs(list)
	end,
	defines = function(list)
		public.defines(list)
		defines(list)
	end,
	links = function(list)
		local scopeName = getScope()
		local l = Table(list)
		public.links(list)
		--debuglog("SHARED LINKING: ", scopeName, " :: LINKING: ")
		--l:dump()
		links(list)
	end,
	buildoptions = function(list)
	    public.buildoptions(list)
	    buildoptions(list)
    end,
}

-- extend premake functionality
group = function(name)
    _m = nil -- clear the scope
    return _oldgrp(name)
end

project = function(name)
	local mod = getModule(name)
	if mod ~= nil then
		remakeError("Lib '" .. name .. "' already exists")
	end

    debuglog("New project scope started: '" .. name .. "'")
    _m = newModule(name)

    return _oldprj(name)
end

function library(name)
    if name == nil or type(name) == 'table' then
        clearscope()
        return
    end
	if getModule(name) ~= nil then
		remakeError("Lib '" .. name .. "' already exists")
	end

    debuglog("New lib scope started: '" .. name .. "'")
    _m = newModule(name, true)
end

function using(list)
	if list == nil then
		remakeError("'using' missing parameter(s)")
	end

	local name = getScope()
	if name == nil then
		remakeError("using must be used in a project or library scope")
	end

	kmerge(name, 'using', list)
	processlib(getModule(name))
end


local function getFileName(url)
	return url:match("^.+/(.+)$")
end

local function getFileExtension(url)
	return getFileName(url):match("^.+(%..+)$")
end

function includeall(loc)
    if loc == nil then
        premake.error("includeall path is nil")
        return
    end
	if not os.isdir(loc) then
		premake.error("includeall path '" .. loc .. "' doesn't exist or can't be read/found")
    end
    table.foreachi(os.matchfiles(path.join(loc, "**/premake5.lua")), function(v)
		print("Including " .. v)
		include (v)
	end)
end

function mytarget()
	return "%{cfg.buildtarget.abspath}"
end

function mytarget_file()
    return "%{cfg.buildtarget.name}"
end

function distcopy(list, target)
	if type(list) == 'table' then
		table.foreachi(list, function(f)
		    distcopy(f, target)
		end)
		return
	end

	if list == nil then
	    list = mytarget()
    end

	if target == nil then
		target = gConfig.dist
	end

	if list:sub(0, 1) ~= '%' then
		list = normalizepath(list)
		target = path.ensure(target)
	end

	local cp
	if ISWIN then
		cp = "{COPY}"
	else
		cp = "cp -f"
	end
	local cmd = cp .. " \"" .. list .. "\" \"" .. target .. "\""

	postbuildcommands (cmd)
end

--[[
function retarget(list, root)
	if list == nil then
		return nil
	end
	if type(list) == "table" then
		local T = Table{}
		list = Table(list)
		list:each(function(file,k)
			T[file] = retarget(file, root)
		end)
		return T
	end

	if root == nil then root = paths.getCRoot() end
	if list:sub(0, 1) ~= '%' then
		return path.join(paths.dist, root, list)
	end

	return path.join(paths.dist, root)
end

function distmirror(list, target)
	local l = retarget(list, target)
	if type(l) ~= 'table' then
		distcopy(l, target)
		return
	end
	l:each(function(target, file)
		distcopy(file, target)
	end)
end
]]--

function prettyPathing()
	vpaths {
		["Headers/*"] = {
			path.join(paths.source, "**.h"),
		},
		["Headers/Libs/*"] = { path.join(paths.libs, "**.h") },
		["Sources/*"] = {
			path.join(paths.source, "**.c"),
		},
		["Sources/Libs/*"] = {
			path.join(paths.libs, "**.c"),
		},
		["Docs"] = "**.txt"
	}
end

if ISWIN then
    function os.winSdkVersion()
        local sdk_version = nil
        if (os.host() == "windows") then
            local reg_arch = iif( os.is64bit(), "\\Wow6432Node\\", "\\" )
            sdk_version = os.getWindowsRegistry("HKLM:SOFTWARE" .. reg_arch .."Microsoft\\Microsoft SDKs\\Windows\\v10.0\\ProductVersion")
        end

        return sdk_version
    end
end

--[[
function makevar(vname, vval, echar)
	if echar == nil then
		echar = '"'
	end
	return (vname .. "=" .. echar .. vval .. echar)
end
]]--

function pkginclude(libname)
    local p = pkgcfg(libname)
    if p == nil then return nil end
    return Table {
        includedirs = p.incluedirs
    }
end

function pkgcfg(libname, r, deflibpath)
	if deflibpath == nil then
	    if os.target() == "linux" then
		    deflibpath = { "/usr/lib", "/usr/lib/x86_64-linux-gnu" }
        else
            deflibpath = {}
        end
	end

    if r == nil then
        r = Table {
			includedirs  = Table(),
			libdirs      = Table(),
			links        = Table(),
			defines      = Table(),
			buildoptions = Table(),
        }
	end

	if type(libname) == 'table' then
		foreach(libname, function(lib)
			pkgcfg(lib, r, deflibpath)
		end)
		return r
	end

	local lname = string.lower(libname)
	local result, errorCode = os.outputof("pkg-config --cflags --libs " .. lname)
	if errorCode == 0 then
		print("pkg-config ok:", libname)
		result = string.explode(result, " ")
		for _,v in pairs(result) do
			v = v:trim()
			if v:startswith("-I") then
				v = v:gsub("-I", "", 1)
				r.includedirs:append(v)
			elseif v:startswith("-l") then
				v = v:gsub("-l", "", 1)
				r.links:append(v)
			elseif v:startswith("-L") then
				v = v:gsub("-L", "", 1)
				r.libdirs:append(v)
			elseif v:startswith("-D") then
				v = v:gsub("-D", "", 1)
				r.defines:append(v)
			else
				r.buildoptions:append(v)
			end
		end

		return r
	end

	local p = os.findlib(libname, deflibpath)
	if p == nil then
		remakeError("Couldn't find lib: ".. libname)
		return r
	end

	-- duplicates aren't added anyway but we need to know the real name of the file
	r.links:append(libname)
	r.libdirs:append(p)

    return r
end

--function applypkg(cfg)
--	if cfg == nil then return end
--
--	includedirs(cfg.includedirs)
--	libdirs(cfg.libdirs)
--	defines(cfg.defines)
--	links(cfg.links)
--	buildoptions(cfg.buildoptions)
--
--    if cfg['cppflags'] ~= nil then
--        filter "files:*.cpp"
--            buildoptions(cfg.cppflags)
--            links(cfg.cpplibs)
--        filter{}
--    end
--end

--function public_applypkg(cfg)
function applypkg(cfg)
	if cfg == nil then return end

	shared.includedirs(cfg.includedirs)
	shared.libdirs(cfg.libdirs)
	shared.defines(cfg.defines)
	shared.links(cfg.links)
	shared.buildoptions(cfg.buildoptions)

    if cfg['cppflags'] ~= nil then
        filter "files:*.cpp"
            buildoptions(cfg.cppflags)
            shared.links(cfg.cpplibs)
        filter{}
    end
end
