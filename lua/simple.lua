local M = {}
M.is_windows_hidden = false

-- viewer の作成
--
-- viewer 用の buffer を作る
-- nvim_create_buf(listed: boolean, scratch: boolean) -> integer
-- listed: このバッファをバッファリストに表示するかどうかを決定します。
--   true: :ls コマンドなどでこのバッファが表示される（バッファリストに含まれる）。
--   false: バッファリストに表示されない。
-- scratch: 一時的なバッファかどうか（通常のファイルとして保存しないかどうか）を決定します。
--   true: 一時的なバッファ（スクラッチバッファ）。通常のファイルとして保存されず、スワップファイルも作成されません。
--   false: 通常のバッファ（ファイルとして保存可能）。
local viewer_buf = vim.api.nvim_create_buf(false, true)

-- buffer にテキストを設定
-- nvim_buf_set_lines(buffer, start, end, strict_indexing, replacement)
-- buffer: 操作するバッファのID（bufnr）。0 を指定すると、現在のバッファが対象となります。
-- start: 行の開始インデックス。ここからテキストが変更されます。0から始まるインデックスで、0 が1行目を指します。
-- end: 行の終了インデックス。start と end の間の行が変更されます。-1 を指定すると、バッファの最後の行までが対象になります。
-- strict_indexing: 行インデックスが範囲外の場合にエラーを出すかどうかを指定します。true にするとインデックスが正確である必要があり、false にすると行が範囲外でも処理が続行されます。
-- replacement: 置き換える行のリスト（テーブル形式）。このリストの内容が start と end で指定した範囲の行と置き換えられます。空のリストを指定すると、行が削除されます。
vim.api.nvim_buf_set_lines(viewer_buf, 0, -1, false, {
  'This is a scratch buffer.',
  "It won't be saved to a file.",
})

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
local viewer_win_id = vim.api.nvim_open_win(viewer_buf, true, viewer_win_opts)

-- prompt の作成
local prompt_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, { 'Prompt Text' })

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

local prompt_win_id = vim.api.nvim_open_win(prompt_buf, true, prompt_win_opts)

local function show_windows()
  if M.is_windows_hidden then
    -- viewer window を再表示
    viewer_win_id = vim.api.nvim_open_win(viewer_buf, false, viewer_win_opts)

    -- prompt window を再表示
    prompt_win_id = vim.api.nvim_open_win(prompt_buf, true, prompt_win_opts)

    M.is_windows_hidden = false
  end
end

local function hide_windows()
  if not M.is_windows_hidden then
    vim.api.nvim_win_hide(prompt_win_id)
    vim.api.nvim_win_hide(viewer_win_id)
    M.is_windows_hidden = true
  end
end

vim.api.nvim_set_keymap('n', '<leader>o', '', {
  noremap = true,
  silent = true,
  callback = show_windows,
})

vim.api.nvim_buf_set_keymap(prompt_buf, 'n', '<Esc>', '', {
  noremap = true,
  silent = true,
  callback = hide_windows,
})
vim.api.nvim_buf_set_keymap(viewer_buf, 'n', '<Esc>', '', {
  noremap = true,
  silent = true,
  callback = hide_windows,
})
