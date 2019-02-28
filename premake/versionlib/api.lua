---
-- VersionLib.
-- Copyright (c) 2018 Sol
---
local p = premake
local versionlib = p.modules.versionlib
versionlib.cache = {
    version = "0.0.0"
}

---
-- register versionlib api.
---
p.api.register {
    name = "versionlib",
    scope = "config",
    kind = "table:keyed"
}

function split(str,pat)
    local tbl={}
    str:gsub(string.format("([^%s]+)", pat), function(x) tbl[#tbl+1]=x end)
    return tbl
end

function join(arr, glue, limit)
    local str = ""
    local i, v
    for i,v in pairs(arr) do
        if limit ~= nil and i > limit then goto endloop end
        if i > 1 then str = str .. glue end
        str = str .. v
    end
::endloop::
    return str
end

local function getMajorVer(ver)
    return table.remove(split(ver, "."), 1)
end

local function getMinVer(ver)
    local info = split(ver, ".");
    local limit = 3
    if (info[3] ~= nil and info[3] == "0") then limit = 2 end
    return join(info, ".", limit)
end

local function symlink(source, target)
    return join({
            ("rm -f " .. target),
            ("ln -s " .. source .. " " .. target)
    }, " && ")
end

function setversion(version)
    versionlib.cache.version = version;
    print("Version: " .. versionlib.cache.version)
end

function makeversion()
    local version = versionlib.cache.version
    targetextension (".so." .. version)
    --targetextension (".so")

	local versioned = "lib%{cfg.linktarget.basename}.so." .. getMajorVer(version)

    --print ("SONAME: " .. versioned)
    --print ("RPATH : %{cfg.linktarget.directory}")

    linkoptions ("-Wl,-soname=" .. versioned)
    linkoptions ("-Wl,-rpath,./")
    --linkoptions ("-Wl,-soname=lib%{cfg.linktarget.basename}.so." .. getMajorVer(version))
    --linkoptions ("-Wl,-rpath,%{cfg.linktarget.directory}")

	--[[
    postbuildcommands {
		("../tools/linkversion.sh %{cfg.linktarget.name} " .. version)
    }
    ]]--    
    postbuildcommands {		
        join({
            "cd %{path.getabsolute(cfg.linktarget.directory, cfg.targetdir)}",
            symlink("%{cfg.linktarget.name}", versioned),
            symlink(versioned, "lib%{cfg.linktarget.basename}.so")
        }, " && ")
    }
end
