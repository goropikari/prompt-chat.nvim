local state = {
  bufnr = 0,
  last_line_num = 2,
}
local title = 'Chat'

local function make_spinner()
  local spinner_symbols = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
  local spinner_symbols_len = #spinner_symbols
  local cnt = 0
  return function()
    local ret = spinner_symbols[cnt + 1]
    cnt = (cnt + 1) % spinner_symbols_len
    return ret
  end
end

local function move_bottom(win_id)
  if vim.api.nvim_win_is_valid(win_id) then
    vim.api.nvim_win_call(win_id, function()
      vim.cmd('normal! G')
      vim.cmd('normal! zb')
    end)
  end
end

state.bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_option_value('filetype', 'markdown', { buf = state.bufnr })
vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, { 'User:', '' })

local win_opts = {
  relative = 'editor',
  width = math.floor(vim.o.columns * 0.7),
  height = math.floor(vim.o.lines / 2),
  col = math.floor((vim.o.columns - vim.o.columns * 0.7) / 2), -- 中央に配置
  row = math.floor(vim.o.lines * 0.1),
  border = 'double', -- 枠線を付ける
  title = title,
  title_pos = 'center',
  style = 'minimal',
}
local winid = vim.api.nvim_open_win(state.bufnr, true, win_opts)

local function send_to_buffer(chunk)
  if chunk then
    local res = vim.json.decode(chunk)
    vim.schedule(function()
      vim.api.nvim_buf_set_text(state.bufnr, -1, -1, -1, -1, vim.split(res.response, '\n'))
      if res.done then
        vim.api.nvim_buf_set_lines(state.bufnr, -1, -1, false, { '', 'User:', '' })
        state.last_line_num = vim.api.nvim_buf_line_count(state.bufnr)
        vim.api.nvim_win_set_config(winid, { title = title, title_pos = 'center' })
      end
      move_bottom(winid)
    end)
  end
end

vim.api.nvim_buf_set_keymap(state.bufnr, 'i', '<c-s>', '', {
  noremap = true,
  silent = true,
  callback = function()
    vim.api.nvim_buf_set_lines(state.bufnr, -1, -1, false, { '', 'LLM', '' })
    local user_input = vim.api.nvim_buf_get_lines(state.bufnr, state.last_line_num - 1, -1, false)
    local text = vim.fn.join(user_input, '\n')
    local timer = vim.uv.new_timer()
    local spinner = make_spinner()
    vim.uv.timer_start(
      timer,
      0,
      200,
      vim.schedule_wrap(function()
        vim.api.nvim_win_set_config(winid, { title = title .. ' ' .. spinner(), title_pos = 'center' })
      end)
    )
    vim.fn.jobstart(
      vim.fn.flatten({ 'curl', '--no-buffer', 'http://localhost:11434/api/generate', '-d', vim.json.encode({ model = 'codegemma', prompt = text }) }),
      {
        on_stdout = function(_, chunk, _)
          for _, v in ipairs(chunk) do
            if v ~= '' then
              send_to_buffer(v)
            end
          end
        end,
        on_exit = function()
          timer:stop()
          timer:close()
        end,
        stdout_buffered = false,
      }
    )
  end,
})
