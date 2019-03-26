---
-- VersionLib.
-- Copyright (c) 2018 Sol
---
	local p = premake

	if not premake.modules.versionlib then
		p.modules.versionlib = {}
		p.modules.versionlib._VERSION = p._VERSION

		verbosef('Loading versionlib module...')
		include('api.lua')
	end

	return p.modules.versionlib
