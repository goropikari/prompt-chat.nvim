local M = {
  is_windows_hidden = true,
  viewer = {
    bufnr = -1,
    winid = -1,
    show_interval = 30,
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

local function append_lines_one_by_one(bufnr, text_table, interval)
  local line_idx = 1 -- 現在の処理中の行インデックス
  local char_idx = 1 -- 現在の行で追加する文字インデックス
  local total_lines = #text_table -- 配列内の行数

  -- 最初に空の行をバッファに追加
  if not is_empty_buffer(bufnr) then
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { '' })
  end

  -- 非同期に1文字ずつ追加する
  local timer = vim.loop.new_timer()

  timer:start(
    0,
    interval,
    vim.schedule_wrap(function()
      -- 現在の行が配列の行数を超えたら終了
      if line_idx > total_lines then
        timer:stop()
        timer:close()
        return
      end

      -- 現在の行の文字列を取得
      local current_text = text_table[line_idx]

      -- その行が終了したら次の行に移動
      if char_idx > #current_text then
        line_idx = line_idx + 1
        char_idx = 1
        -- 次の行の追加
        if line_idx <= total_lines then
          vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { '' })
        end
        return
      end

      -- 現在の行の内容を取得し、1文字追加して更新
      local current_line = vim.api.nvim_buf_get_lines(bufnr, -2, -1, false)[1]
      current_line = current_line .. current_text:sub(char_idx, char_idx)

      -- 1文字を追加
      vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, { current_line })

      char_idx = char_idx + 1 -- 次の文字に進む
    end)
  )
end

local function send_prompt_to_viewer(prompt_buf, viewer_buf)
  -- prompt の内容を取得
  local data = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)

  -- -- viewer に prompt の内容を追加
  -- local insert_line = -1
  -- if is_empty_buffer(viewer_buf) then
  --   insert_line = 0
  -- end
  -- vim.api.nvim_buf_set_lines(viewer_buf, insert_line, -1, false, data)
  append_lines_one_by_one(viewer_buf, data, M.viewer.show_interval)

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
