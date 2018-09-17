helpers = {}

--in_table() 函数搜索table中是否存在指定的值。
function helpers:in_table( string , table )
	for _,v in ipairs( table ) do
		if( v == string ) then
			return true;
		end
	end 
	return false;
end

--去除字符串两边空格
function helpers:trim ( string, char )
	if not char then
		char = "%s";
	end
	return (string.gsub(string, "^".. char .."*(.-)" .. char .. "*$", "%1")) 
end

--去除字符串左边空格
function helpers:ltrim ( string, char )
	if not char then
		char = "%s";
	end
	return (string.gsub(string, "^".. char .."*(.-)$", "%1")) 
end

--去除字符串右边空格
function helpers:rtrim ( string, char )
	if not char then
		char = "%s";
	end
	return (string.gsub(string, "^(.-)" .. char .. "*$", "%1")) 
end

--分割字符串
-- 参数:待分割的字符串,分割字符 
-- 返回:子串表.(含有空串) 
function helpers:split(str, split_char)
	local sub_str_tab = {}
	while true do
		local pos = string.find(str, split_char) 
		if not pos then
			table.insert(sub_str_tab,str)
			break
		end
		local sub_str = string.sub(str, 1, pos - 1)
		table.insert(sub_str_tab,sub_str)
		str = string.sub(str, pos + 1, string.len(str))
	end
	return sub_str_tab
end

return helpers;
