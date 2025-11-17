-- Robust table pretty-printer for Lua
-- Features:
--  - handles cycles (prints reference path)
--  - sorts keys deterministically (optional)
--  - detects array-like tables and prints them as sequences
--  - escapes strings safely
--  - configurable indent and max depth

local M = {}

local function escape_str(s)
    s = tostring(s)
    s = s:gsub("\\","\\\\")
    s = s:gsub('\"','\\\"')
    s = s:gsub('\n','\\n')
    s = s:gsub('\r','\\r')
    s = s:gsub('\t','\\t')
    return s
end

local function is_array(t)
    -- Return true when table is a sequence 1..n with no non-numeric keys
    local n = 0
    local max = 0
    for k,_ in pairs(t) do
        if type(k) == 'number' and k > 0 and math.floor(k) == k then
            n = n + 1
            if k > max then max = k end
        else
            return false
        end
    end
    return max == n
end

local function default_opts()
    return {
        indent = "  ",    -- indentation per level
        maxDepth = math.huge, -- maximum recursion depth
        sortKeys = true,    -- deterministic ordering of keys
        showMetatable = false, -- show metatable as a separate entry
    }
end

local function key_sort(a,b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then
        return ta < tb
    end
    if ta == 'number' then
        return a < b
    end
    return tostring(a) < tostring(b)
end

local function table_to_string(root, user_opts)
    local opts = default_opts()
    if user_opts then
        for k,v in pairs(user_opts) do opts[k] = v end
    end

    local visited = {} -- table -> path

    local function serialize(value, depth, path)
        local ty = type(value)
        if ty == 'string' then
            return '"' .. escape_str(value) .. '"'
        elseif ty == 'number' or ty == 'boolean' or ty == 'nil' then
            return tostring(value)
        elseif ty == 'table' then
            if visited[value] then
                return string.format('<cycle to %s>', visited[value])
            end
            if depth >= opts.maxDepth then
                return '<max depth reached>'
            end

            visited[value] = path

            local lines = {}
            local indent = string.rep(opts.indent, depth)
            local inner_indent = string.rep(opts.indent, depth + 1)

            if is_array(value) then
                for i = 1, #value do
                    local v = value[i]
                    table.insert(lines, inner_indent .. serialize(v, depth + 1, path .. '[' .. i .. ']'))
                end
            else
                local keys = {}
                for k in pairs(value) do table.insert(keys, k) end
                if opts.sortKeys then table.sort(keys, key_sort) end
                for _,k in ipairs(keys) do
                    local v = value[k]
                    local key_repr
                    if type(k) == 'string' and k:match('^[_%a][_%w]*$') then
                        key_repr = k
                    else
                        key_repr = '[' .. serialize(k, depth + 1, path .. '[key:' .. tostring(k) .. ']') .. ']'
                    end
                    table.insert(lines, inner_indent .. key_repr .. ' = ' .. serialize(v, depth + 1, path .. '.' .. tostring(k)))
                end
            end

            if opts.showMetatable then
                local mt = getmetatable(value)
                if mt then
                    table.insert(lines, inner_indent .. '<metatable> = ' .. serialize(mt, depth + 1, path .. '<metatable>'))
                end
            end

            visited[value] = nil

            if #lines == 0 then
                return '{}'
            else
                return '{\n' .. table.concat(lines, ',\n') .. '\n' .. indent .. '}'
            end
        else
            -- function, userdata, thread, etc.
            return '<' .. ty .. ': ' .. tostring(value) .. '>'
        end
    end

    return serialize(root, 0, 'root')
end

local function print_table(t, opts)
    local s = table_to_string(t, opts)
    print(s)
    return s
end

-- Expose API
M.table_to_string = table_to_string
M.print_table = print_table

-- Example usage when run directly
if ... == nil then
    local demo = {
        name = "Alice",
        age = 30,
        tags = {"dev", "lua"},
        meta = {a = 1}
    }
    demo.self = demo -- cycle
    M.print_table(demo, {indent = '    ', showMetatable = false})
end

return M
