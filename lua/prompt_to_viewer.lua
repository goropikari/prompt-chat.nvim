local M = {
  is_windows_hidden = true,
  viewer = {
    bufnr = -1,
    winid = -1,
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
      style = 'minimal',
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
      style = 'minimal',
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

local function send_prompt_to_viewer(prompt_buf, viewer_buf)
  -- prompt の内容を取得
  local data = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)

  -- viewer に prompt の内容を追加
  local insert_line = -1
  if is_empty_buffer(viewer_buf) then
    insert_line = 0
  end
  vim.api.nvim_buf_set_lines(viewer_buf, insert_line, -1, false, data)

  -- prompt の内容をクリア
  vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, {})
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
