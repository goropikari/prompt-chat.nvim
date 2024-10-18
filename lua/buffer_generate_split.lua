local M = {}

local state = {
  bufnr = -1,
  winid = -1,
  prev_last_line_num = 2, -- 1-index
  context = {}, -- LLM に多少文脈を覚えてもらうよう
}

local config = {
  model = 'codegemma',
  url = 'http://localhost:11434/api/generate',
  user_prompt = 'User:',
  llm_prompt = 'LLM:',
}

local function move_bottom(win_id)
  if vim.api.nvim_win_is_valid(win_id) then
    local last_num = vim.api.nvim_buf_line_count(state.bufnr)
    vim.api.nvim_win_set_cursor(state.winid, { last_num, 0 })
  end
end

local function send_to_buffer(json_string, bufnr)
  if json_string then
    local res = vim.json.decode(json_string)
    vim.api.nvim_buf_set_text(bufnr, -1, -1, -1, -1, vim.split(res.response, '\n'))
    if res.done then
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { '', config.user_prompt, '' })
      state.prev_last_line_num = vim.api.nvim_buf_line_count(bufnr)
      state.context = res.context
    end
  end
end

local function setup_keymap(bufnr)
  vim.api.nvim_buf_set_keymap(bufnr, 'i', '<c-s>', '', {
    noremap = true,
    silent = true,
    callback = function()
      -- user が入力した分を取得
      local user_input = vim.api.nvim_buf_get_lines(bufnr, state.prev_last_line_num - 1, -1, false)
      local user_text = vim.fn.join(user_input, '\n')
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { '', config.llm_prompt, '' })
      vim.fn.jobstart({
        'curl',
        '--no-buffer',
        config.url,
        '-d',
        vim.json.encode({ model = config.model, prompt = user_text, context = state.context }),
      }, {
        on_stdout = function(_, chunk, _)
          for _, v in ipairs(chunk) do
            if v ~= '' then
              vim.schedule(function()
                send_to_buffer(v, bufnr)
                move_bottom(state.winid)
              end)
            end
          end
        end,
        stdout_buffered = false,
      })
    end,
  })
end

local function setup_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('filetype', 'markdown', { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { config.user_prompt, '' })

  return bufnr
end

function M.setup(opts)
  state.bufnr = setup_buffer()
  setup_keymap(state.bufnr)
end

function M.toggle_window()
  if vim.api.nvim_win_is_valid(state.winid) then
    vim.api.nvim_win_close(state.winid, false)
    state.winid = -1
  else
    local win_opts = {
      split = 'left',
      width = math.floor(vim.o.columns * 0.3),
    }
    state.winid = vim.api.nvim_open_win(state.bufnr, true, win_opts)
  end
end

vim.api.nvim_create_user_command('ChatToggle', M.toggle_window, {})

M.setup({})

return M
