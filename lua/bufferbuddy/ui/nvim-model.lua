---@class VimApi
---@field nvim_set_current_win fun(win: integer)
---@field nvim_win_set_cursor fun(win: integer, pos: integer[])
---@field nvim_buf_set_keymap fun(buf: integer, mode: string, lhs: string, rhs: string, opts: table)
---@field nvim_replace_termcodes fun(str: string, from_part: boolean, do_lt: boolean, special: boolean): string
---@field nvim_feedkeys fun(keys: string, mode: string, escape_csi: boolean)
---@field nvim_buf_get_mark fun(buf: integer, name: string): integer[]

---@class VimOptions
---@field columns integer
---@field lines integer

---@class Vim
---@field api VimApi
---@field o VimOptions
---@field schedule fun(fn: fun())
---@field cmd fun(cmd: string)

---@class NvimModel
---@field create fun(): Vim

local M = { create = function() return vim end }

return M
