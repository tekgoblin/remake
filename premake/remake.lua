require 'extensions'
require 'versionlib'

local gConfig = nil
Config = Object()

function Config:new(source, libs, build, dist)
	local self = setType(Config)

	self.base = _WORKING_DIR
	self.libs = self.base:append(libs)
	self.source = self.base:append(source)
	self.build = self.base:append(build)
	self.dist = ''

	self.buildLib = self.build:append("%{cfg.buildcfg}/%{cfg.architecture}")

	location (self.build)
	--debugdir (self.dist)
	targetdir (self.buildLib)
	syslibdirs { self.buildLib }
	libdirs { self.buildLib }

	self:retarget('dist', self.base:append(dist))
	if not os.isdir(self.dist) then
		os.mkdir(self.dist)
	end

	gConfig = self
	return self
end

function Config:dump(indent)
	print("Config")
	print("Base Path      : ", self.base)
	print("Lib Path       : ", self.libs)
	print("Source Path    : ", self.source)
	print("Build Path     : ", self.build)
	print("Build Libs Path: ", self.buildLib)
	print("Output Path    : ", self.dist)
	print()
end

function Config:retarget(key, val)
	if val == nil then  return end
	if key == 'dist' then
		self[key] = os.realpath(val)
		debugdir(self[key])
	end
end

function includeall(path) 
	if not os.isdir(path) then
		premake.error("includeall path '" .. path .. "' doesn't exist or can't be found")
	end
	local list = os.matchfiles(path:append("*/premake5.lua"))
	for _,v in pairs(list) do
		include (v)
	end
end

function distCopy(list)
	local dist = gConfig.dist
	if dist == nil then
		dist = '../dist/'
	end
	dist = os.realpath(dist)
	--print("DIST COPY TO : " .. dist)
	if list == nil then return end
	if type(list) ~= 'table' then
		list = Table{ list }
	end
	for _,v in pairs(list) do
		if v == nil then goto continue end
		if type(v) == 'table' then
			distCopy(v)
		else
			postbuildcommands ("{COPY} " .. v .. " " .. dist)
		end
		::continue::
	end
end

function myTarget()
	return "%{cfg.buildcfg}/%{cfg.architecture}/%{cfg.buildtarget.name}"	
end


exports = {
    ['p'] = Table{},
	['includedirs'] = function(list) pmerge(getProjectName(), 'includes', list) end,
	['links'] = function(list) pmerge(getProjectName(), 'links', list) end,
	['defines'] = function(list) pmerge(getProjectName(), '_defines', list) end
}

function foreach(list, fn)
	list = ensureTable(list)
	local l = Table{}
	for _,v in pairs(list) do
		l:append(fn(v))
	end	
	return l
end

function pget(name)
	if exports.p[name] == nil then	
		return nil 
	end
	return exports.p[name]
end

function pnew(name)
	exports.p[name] = Table { 
		['name'] = name,
		['includes'] = Table{},	
		['links'] = Table{},
		['defines'] = Table{},
		['_defines'] = Table{}
	}
	return exports.p[name]
end

function pexec(ctx)
	includedirs(ctx.includes)
	dependson(ctx.links)
	links(ctx.links)	
	defines(ctx.defines)
end

function pmerge(name, key, list)
	local ctx = pget(name) or pnew(name)
	if key == 'includes' then
		ctx[key]:append(foreach(list, os.realpath))
	else
		ctx[key]:append(list)
	end

	pexec(ctx)
end

function using(list)
	if list == nil then
		premake.error("'using' missing parameter(s)")
	end

	local pname = getProjectName()
	if pname == nil then
		premake.error("'using' must be used in a project scope")
	end

	list = ensureTable(list)
	local ctx = pget(pname) or pnew(pname)
	for _,v in pairs(list) do	
		print ("Merging " .. v .. " into " .. ctx.name)
		local import = pget(v)
		if import == nil then
			premake.error("No import definition for '" .. v .. "' exists")
		else
			ctx.includes:append(import.includes)
			ctx.links:append(v)			
			ctx.links:append(import.links)
			ctx.defines:append(import._defines)
		end
	end

	pexec(ctx)
end
