lfs = require "lfs";

files = {}

function files:mkdirs( str )
	local pos = 0;
	while true do
		pos = string.find(str, "/", pos+1)
		if ( pos == nil ) then
			break;
		end 
		dir = string.sub(str, 0, pos)
		if( self:file_exists( dir ) == false ) then
			_, err = lfs.mkdir(dir);
		end
	end
	if( self:file_exists( str ) == false ) then
		_, err = lfs.mkdir( str .. '/' );
	end
	if err then
		ngx.say( err );
		return ngx.exit(ngx.HTTP_OK);
	end
	return true;
end


--判断目录或文件是否存在
function files:file_exists(path)
	local file = io.open(path, "rb")
	if file then file:close() end
	return file ~= nil
end

--获取路径
function files:getFilePath(filename)
    if string.find(filename,":") then  
        return string.match(filename, "(.*)\\[^\\]*%.%w+") -- windows  
    else  
        return string.match(filename, "(.*)/[^/]*%.%w+$")   -- *nix system  
    end  
end

--获取文件名  
function files:getFileName(filename)  
    if string.find(filename,":") then  
        return string.match(filename, ".*\\([^\\]*%.%w+)")  -- windows  
    else  
        return string.match(filename, ".*/([^/]*%.%w+)$")   -- *nix system  
    end  
end

--获取扩展名
function files:getExtension(str)
	return str:match(".+%.(%w+)$")
end

--读取文件
function files:readFile(fileName)
	local content = {};
	local f = io.open(fileName,'r')
	for l in f:lines() do
		table.insert(content,l)
	end
	f:close()
	return content
end

function files:write(path, content, mode)  
	mode = mode or "w+b"  
	local file = io.open(path, mode)  
	if file then  
		if file:write(content) == nil then return false end  
		io.close(file)  
		return true  
	else  
		return false  
	end  
end 

return files;
