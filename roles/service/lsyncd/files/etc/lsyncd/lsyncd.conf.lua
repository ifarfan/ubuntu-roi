--
-- See: https://github.com/axkibe/lsyncd/issues/441
--
local confdir = '/etc/lsyncd/conf.d/'
local entries = readdir( confdir )

for name, isdir in pairs( entries ) do
    if not isdir then
        dofile( confdir .. name )
    end
end
