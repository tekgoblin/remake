---
-- Remake: Premake proxy
-- Copyright (c) 2018-2020 tekgoblin
---

-- ========================================================================================
-- ========================================================================================
-- OBJECT EXTENSIONS

function settype(ty, obj)
	if obj == nil then obj={} end
	setmetatable(obj, {__index = ty })
	return obj
end

function Table(t)
	if t == nil then
		t = {}
	elseif type(t) ~= 'table' then
		t = { t }
	end
    return settype(table, t)
end

function Class(def)
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

-- ========================================================================================
-- ========================================================================================
-- STRING EXTENSIONS

function string:isempty()
	return self == nil or #self == 0 or self == ''
end

function string:trim()
    return self:match "^%s*(.-)%s*$"
end

-- ========================================================================================
-- ========================================================================================
-- TABLE EXTENSIONS

function table:each(fn)
	local _,v,r
	for _,v in pairs(self) do
		--if type(v) == 'table' then Table(v) end
		r = fn(v,_)
		if r == false then goto breakeach end
	end
	::breakeach::
	return self
end

function table:ensureKey(key)
	if self[key] == nil then
		self[key] = Table()
	end
	return self[key]
end

function table:append(item)
	if item == nil then return end
	if type(item) ~= 'table' then
		if not self:contains(item) then
			self:insert(item)
		end
	else
		item = Table(item)
		item:each(function(v,k)	self:append(v) end)
	end
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
		elseif type(v) == 'boolean' or type(v) == 'function' then
			print(formatting .. tostring(v))
		else
			print(formatting .. v)
		end
	end
	print(string.rep(" ", indent * level) .. "}");
end

function foreach(list, fn)
	list = Table(list)
	local l = Table()
	for _,v in pairs(list) do
		if type(v) == 'table' then
			l:append(foreach(v, fn))
		else
			l:append(fn(v))
		end
	end
	return l
end

-- ========================================================================================
-- ========================================================================================
-- path EXTENSIONS

function npath(p)
	return path.translate(path.normalize(p), '/')
end

function normalizepath(p)
    local r, e = os.realpath(p)
    if r == nil then
        premake.error(e)
    end
	return npath(r)
end

function path.ensure(dir)
	--print("--->Request to make path: " .. dir)
	--print(debug.traceback())
	--premake.error("Request was not a path\n" .. debug.traceback())

	local bits = Table(dir:explode("/"))
	if bits:isempty() then
	    return dir
    end

	--bits:dump()
	local c = ''
    if bits[1]:isempty() then
        bits:remove(1)
        c='/'
    end

	for _,v in ipairs(bits) do
		--if v:contains('.') then goto breakloop end
		c = path.join(c, v)
		--print("\tPath chunk: " .. v .. " :: " .. c)

		--local result, errorCode = os.outputof("echo \"" .. c .. "\"")
		if not os.isdir(c) then
			print("Ensuring path: " .. c)
			os.mkdir(c)
			--print("--")
			return c
        --else
            --print("\tOk: " .. v .. " :: " .. c)
		end
	end
	--::breakloop::

	return c
end
