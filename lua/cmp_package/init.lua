local source = {}
local Job = require("plenary.job")

---Source constructor.
source.new = function()
	local self = setmetatable({}, { __index = source })
	self.your_awesome_variable = 1
	return self
end

---Return the source name for some information.
source.get_debug_name = function()
	return "package"
end

---Return the source is available or not.
---@return boolean
function source:is_available()
	return true
end

local function jq(d, its_repo, callback)
	local args = its_repo and ".items[].name" or ".items[].login"
	Job
		:new({
			command = "jq",
			args = { args },
			writer = d:result(),
			on_exit = function(job)
				local res = job:result()

				if not res then
					return callback({})
				end

				local packs = {}
				for _, name in ipairs(res) do
					table.insert(packs, { label = name, insertText = name })
				end
				callback(packs)
			end,
		})
		:start()
end

---Invoke completion (required).
---  If you want to abort completion, just call the callback without arguments.
---@param request  cmp.CompletionRequest
---@param callback fun(response: lsp.CompletionResponse|nil)
function source:complete(request, callback)
	local cur_line = request.context.cursor_line
	local query = string.match(cur_line, '%s*"([^"]*)"?')
	if not query then
		return callback({})
	end

	local its_repo = string.match(query, "/")

	query = string.gsub(query, "%s+", "")
	if not query then
		return callback({})
	end

	local url = its_repo and string.format("https://api.github.com/search/repositories?q=%s", query)
		or string.format("https://api.github.com/search/users?q=%s", query)

	Job
		:new({
			command = "curl",
			args = { url },
			on_exit = function(job)
				callback(jq(job, its_repo, callback))
			end,
		})
		:start()
end

---Resolve completion item that will be called when the item selected or before the item confirmation.
---@param completion_item lsp.CompletionItem
---@param callback fun(completion_item: lsp.CompletionItem|nil)
function source:resolve(completion_item, callback)
	callback(completion_item)
end

---Execute command that will be called when after the item confirmation.
---@param completion_item lsp.CompletionItem
---@param callback fun(completion_item: lsp.CompletionItem|nil)
function source:execute(completion_item, callback)
	callback(completion_item)
end

return source
