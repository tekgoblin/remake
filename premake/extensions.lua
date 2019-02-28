function os.winSdkVersion()
	local sdk_version = nil
	if (os.host() == "windows") then
		local reg_arch = iif( os.is64bit(), "\\Wow6432Node\\", "\\" )
		sdk_version = os.getWindowsRegistry("HKLM:SOFTWARE" .. reg_arch .."Microsoft\\Microsoft SDKs\\Windows\\v10.0\\ProductVersion")
	end
	
	return sdk_version
end

function npath(p)
	if os.host() == "windows" then
		return path.translate(path.normalize(p))
	else
		return path.translate(path.normalize(p), '/')
	end
end

local function getFileName(url)
	return url:match("^.+/(.+)$")
end

local function getFileExtension(url)
	return getFileName(url):match("^.+(%..+)$")
end

function getProjectName()
	return project().name
end

function string:append (list)
	if list == nil then return "" end
	if type(list) == "string" then
		return (self .. '/' .. list)
	else
		for i, name in ipairs(list) do
			list[i] = (self .. '/' .. name)
		end
		return list
	end
end

function string:prepend (list)
	if list == nil then return "" end
	if type(list) == "string" then
		return (list .. '/' .. self)
	else
		for i, name in ipairs(list) do
			list[i] = (list .. '/' .. self)
		end
		return list
	end
end

function Table(t)
    return setmetatable(t, {__index = table})
end

function Object(def)
	if def == nil then def = {} end
	local obj = def
	obj.__index = obj
	setmetatable(obj, {
		__call = function (cls, ...)
			return cls:new(...)
		end,
	})

	return obj
end

function setType(ty, obj)
	if obj == nil then obj={} end
	setmetatable(obj, ty)
	return obj
end

function table:length()
	local count = 0
	for _ in pairs(self) do 
		count = count + 1 
	end
	return count
end

function table:dump (indent, level)
	if not level then level = 0 end
	if not indent then indent = 4 end
	
	print("{");
	for k, v in pairs(self) do
		formatting = string.rep(" ", indent * (level+1)) .. k .. ": "
		if v == nil then
			print("nil")
		elseif type(v) == "table" then
			io.write(formatting)
			Table(v):dump(indent, level+1)
		elseif type(v) == 'boolean' then
			print(formatting .. tostring(v))
		else
			print(formatting .. v)
		end
	end
	print(string.rep(" ", indent * level) .. "}");
end

function table:filter(cb)
    local result = Table{};

	for k,v in ipairs(self) do
		if cb(v, k, self) then
			result:insert(v)
		end
	end

    return result;
end

function table:find(value)
    for _,v in ipairs(self) do
        if v == value then
            return _;
        end
    end
	return nil
end

function table:append(list)
	if list == nil then return end
	
	if type(list) == 'string' then 
		if self:find(list) == nil then
			self:insert(list)
		end
	else
		for _,v in pairs(list) do
			self:append(v)
		end	
	end
end

function ensureTable(val)
	if val == nil then
		return Table{}
	elseif type(val) == 'string' then
		return Table { val }
	else
		return val
	end	
end
