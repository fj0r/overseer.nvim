local constants = require("overseer.constants")
local overseer = require("overseer")
local TAG = constants.TAG

---@type overseer.TemplateDefinition
local tmpl = {
  priority = 60,
  params = {
    args = { type = "list", delimiter = " " },
    cwd = { optional = true },
  },
  builder = function(params)
    return {
      cmd = { "cargo" },
      args = params.args,
      cwd = params.cwd,
      default_component_params = {
        errorformat = [[%Eerror: %\%%(aborting %\|could not compile%\)%\@!%m,]]
          .. [[%Eerror[E%n]: %m,]]
          .. [[%Inote: %m,]]
          .. [[%Wwarning: %\%%(%.%# warning%\)%\@!%m,]]
          .. [[%C %#--> %f:%l:%c,]]
          .. [[%E  left:%m,%C right:%m %f:%l:%c,%Z,]]
          .. [[%.%#panicked at \'%m\'\, %f:%l:%c]],
      },
    }
  end,
}

---@param opts overseer.SearchParams
---@return nil|string
local function get_cargo_dir(opts)
  local cargo_toml
  if opts.filetype == "rust" then
    local parent = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p:h")
    cargo_toml = vim.fn.findfile("Cargo.toml", parent .. ";")
  end
  if not cargo_toml then
    cargo_toml = vim.fn.findfile("Cargo.toml", opts.dir .. ";")
  end
  if cargo_toml == "" then
    return nil
  end
  return vim.fn.fnamemodify(cargo_toml, ":p:h")
end

return {
  cache_key = function(opts)
    return get_cargo_dir(opts)
  end,
  condition = {
    callback = function(opts)
      if vim.fn.executable("cargo") == 0 then
        return false, 'Command "cargo" not found'
      end
      if not get_cargo_dir(opts) then
        return false, "No Cargo.toml file found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local cargo_dir = get_cargo_dir(opts)
    local commands = {
      { args = { "build" }, tags = { TAG.BUILD } },
      { args = { "test" }, tags = { TAG.TEST } },
      { args = { "check" } },
      { args = { "doc" } },
      { args = { "clean" } },
      { args = { "bench" } },
      { args = { "update" } },
      { args = { "publish" } },
      { args = { "run" } },
    }
    local ret = {}
    for _, command in ipairs(commands) do
      table.insert(
        ret,
        overseer.wrap_template(
          tmpl,
          { name = string.format("cargo %s", table.concat(command.args, " ")), tags = command.tags },
          { args = command.args, cwd = cargo_dir }
        )
      )
    end
    table.insert(ret, overseer.wrap_template(tmpl, { name = "cargo" }))
    cb(ret)
  end,
}
