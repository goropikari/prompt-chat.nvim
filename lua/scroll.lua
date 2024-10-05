local M = {
  is_windows_hidden = true,
  viewer = {
    bufnr = -1,
    winid = -1,
    show_interval = 5,
  },
  prompt = {
    bufnr = -1,
    winid = -1,
  },
}

local function show_windows()
  if M.is_windows_hidden then
    -- Floating Windowの設定
    local viewer_width = math.floor(vim.o.columns * 0.7) -- 横幅を画面の70%
    local viewer_height = math.floor(vim.o.lines * 0.5) -- 縦幅を画面の50%

    local viewer_win_opts = {
      relative = 'editor',
      width = viewer_width,
      height = viewer_height,
      col = math.floor((vim.o.columns - viewer_width) / 2), -- 中央に配置
      row = math.floor(vim.o.lines * 0.1),
      border = 'single', -- 枠線を付ける
      -- style = 'minimal',
      title = 'Viewer',
      title_pos = 'left',
    }

    -- Floating Windowを作成
    M.viewer.winid = vim.api.nvim_open_win(M.viewer.bufnr, true, viewer_win_opts)

    local prompt_width = viewer_width
    local prompt_height = 3

    local prompt_win_opts = {
      relative = 'editor',
      width = prompt_width,
      height = prompt_height,
      border = 'single', -- 枠線を付ける
      -- style = 'minimal',
      title = 'Prompt',
      row = viewer_win_opts.row + viewer_height + 2,
      col = viewer_win_opts.col,
      title_pos = 'left',
    }

    M.prompt.winid = vim.api.nvim_open_win(M.prompt.bufnr, true, prompt_win_opts)

    M.is_windows_hidden = false
  end
end

local function hide_windows()
  if not M.is_windows_hidden then
    vim.api.nvim_win_hide(M.prompt.winid)
    vim.api.nvim_win_hide(M.viewer.winid)
    M.is_windows_hidden = true
  end
end

local function setup_buffer()
  M.viewer.bufnr = vim.api.nvim_create_buf(false, true)
  M.prompt.bufnr = vim.api.nvim_create_buf(false, true)
end

local function is_empty_buffer(bufnr)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if line_count ~= 1 then
    return false
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  return lines[1] == ''
end

local function move_bottom(win_id)
  vim.api.nvim_win_call(win_id, function()
    vim.cmd('normal! G')
    vim.cmd('normal! zb')
  end)
end

local function scroll_window(win_id, scroll_lines)
  vim.api.nvim_win_call(win_id, function()
    -- `normal!` コマンドを使ってスクロールをシミュレート
    if scroll_lines > 0 then
      vim.cmd('normal! ' .. scroll_lines .. '') -- `Ctrl-E`に相当（下スクロール）
    else
      vim.cmd('normal! ' .. math.abs(scroll_lines) .. '') -- `Ctrl-Y`に相当（上スクロール）
    end
  end)
end

local function scroll_viewer(scroll_lines)
  scroll_window(M.viewer.winid, scroll_lines)
end

local function request_llm(prompt_data)
  return { 'Local LLM', 'Hello', '' }
end

local function send_prompt_to_viewer(prompt_buf, viewer_buf)
  -- prompt の内容を取得
  local prompt_data = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)

  -- -- viewer に prompt の内容を追加
  local insert_line = -1
  if is_empty_buffer(viewer_buf) then
    insert_line = 0
  end

  local res = request_llm(prompt_data)
  table.insert(prompt_data, 1, 'User:')
  table.insert(prompt_data, '')

  vim.api.nvim_buf_set_lines(viewer_buf, insert_line, -1, false, prompt_data)
  vim.api.nvim_buf_set_lines(viewer_buf, -1, -1, false, res)

  -- prompt の内容をクリア
  vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, {})
  move_bottom(M.viewer.winid)
end

local function setup_keymaps(opts)
  vim.api.nvim_set_keymap('n', '<leader>o', '', {
    noremap = true,
    silent = true,
    callback = show_windows,
  })

  vim.api.nvim_buf_set_keymap(M.prompt.bufnr, 'n', '<Esc>', '', {
    noremap = true,
    silent = true,
    callback = hide_windows,
  })
  vim.api.nvim_buf_set_keymap(M.viewer.bufnr, 'n', '<Esc>', '', {
    noremap = true,
    silent = true,
    callback = hide_windows,
  })
  vim.api.nvim_buf_set_keymap(M.prompt.bufnr, 'i', '<c-s>', '', {
    noremap = true,
    silent = true,
    callback = function()
      send_prompt_to_viewer(M.prompt.bufnr, M.viewer.bufnr)
    end,
  })
end

function M.setup(opts)
  setup_buffer()
  setup_keymaps(opts)
end

M.setup()
show_windows()
