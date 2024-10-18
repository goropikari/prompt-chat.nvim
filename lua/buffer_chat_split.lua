local state = {
  bufnr = 0,
  last_line_num = 2, -- 1-index
  messages = {},
  tmp_assistant_message = {},
}

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
  split = 'left',
  width = math.floor(vim.o.columns * 0.3),
}
local winid = vim.api.nvim_open_win(state.bufnr, true, win_opts)

local function send_to_buffer(chunk)
  if chunk then
    local res = vim.json.decode(chunk)
    vim.schedule(function()
      local content = res.message.content
      table.insert(state.tmp_assistant_message, content)
      vim.api.nvim_buf_set_text(state.bufnr, -1, -1, -1, -1, vim.split(content, '\n'))
      if res.done then
        vim.api.nvim_buf_set_lines(state.bufnr, -1, -1, false, { '', 'User:', '' })
        state.last_line_num = vim.api.nvim_buf_line_count(state.bufnr)
        table.insert(state.messages, {
          role = 'assistant',
          message = vim.fn.join(state.tmp_assistant_message, ''),
        })
        state.tmp_assistant_message = {}
      end
      move_bottom(winid)
    end)
  end
end

vim.api.nvim_buf_set_keymap(state.bufnr, 'i', '<c-s>', '', {
  noremap = true,
  silent = true,
  callback = function()
    local user_input = vim.api.nvim_buf_get_lines(state.bufnr, state.last_line_num - 1, -1, false)
    local user_text = vim.fn.join(user_input, '\n')
    vim.api.nvim_buf_set_lines(state.bufnr, -1, -1, false, { '', 'LLM', '' })
    table.insert(state.messages, { role = 'user', content = user_text })
    vim.fn.jobstart(
      vim.fn.flatten({ 'curl', '--no-buffer', 'http://localhost:11434/api/chat', '-d', vim.json.encode({ model = 'codegemma', messages = state.messages }) }),
      {
        on_stdout = function(_, chunk, _)
          for _, v in ipairs(chunk) do
            if v ~= '' then
              send_to_buffer(v)
            end
          end
        end,
        stdout_buffered = false,
      }
    )
  end,
})
