local curl = require('plenary.curl')
local log = require('plenary.log'):new()
log.level = 'debug'

local ollama_host = os.getenv('OLLAMA_HOST') or 'localhost:11434'

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
  llm_url = 'http://' .. ollama_host .. '/api/generate',
  -- model = 'qwen2.5-coder',
  model = 'codegemma',
}

vim.api.nvim_set_hl(0, 'UserHighlight', { fg = '#ffff00', bg = '#000000' })
vim.api.nvim_set_hl(0, 'LocalLLMHighlight', { fg = '#88ff00', bg = '#000000' })

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
      title = 'Local LLM',
      title_pos = 'center',
      style = 'minimal',
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
      title_pos = 'center',
      style = 'minimal',
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
  vim.api.nvim_set_option_value('filetype', 'markdown', { buf = M.viewer.bufnr })
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
  if vim.api.nvim_win_is_valid(win_id) then
    vim.api.nvim_win_call(win_id, function()
      vim.cmd('normal! G')
      vim.cmd('normal! zb')
    end)
  end
end

local function request_llm(prompt_data, viewer_bufnr)
  vim.api.nvim_buf_set_lines(viewer_bufnr, -1, -1, false, { 'Local LLM:' })
  local last_line_num = vim.api.nvim_buf_line_count(viewer_bufnr)
  vim.api.nvim_buf_add_highlight(viewer_bufnr, -1, 'LocalLLMHighlight', last_line_num - 1, 0, -1)
  vim.api.nvim_buf_set_lines(viewer_bufnr, -1, -1, false, { '' })

  curl.post({
    url = M.llm_url,
    stream = function(err, chunk)
      if chunk then
        local res = vim.json.decode(chunk)
        -- log.debug(res)

        vim.uv.timer_start(vim.uv.new_timer(), 0, 0, function()
          -- メインスレッドで安全にAPIを呼び出すためにvim.scheduleを使用
          vim.schedule(function()
            -- バッファの内容を更新
            local last_line_num = vim.api.nvim_buf_line_count(viewer_bufnr)
            local last_line_text = vim.api.nvim_buf_get_lines(viewer_bufnr, last_line_num - 1, last_line_num, false)[1]
            last_line_text = last_line_text .. res.response
            vim.api.nvim_buf_set_lines(viewer_bufnr, last_line_num - 1, -1, false, vim.split(last_line_text, '\n'))
            if res.done then
              vim.api.nvim_buf_set_lines(viewer_bufnr, -1, -1, false, { '', '----', '' })
            end
            move_bottom(M.viewer.winid)
          end)
        end)
      end
    end,
    body = vim.fn.json_encode({
      model = M.model,
      prompt = table.concat(prompt_data, '\n'),
    }),
  })
end

local function send_prompt_to_viewer(prompt_bufnr, viewer_bufnr)
  -- prompt の内容を取得
  local raw_prompt_data = vim.api.nvim_buf_get_lines(prompt_bufnr, 0, -1, false)

  -- -- viewer に prompt の内容を追加
  local insert_line = -1
  if is_empty_buffer(viewer_bufnr) then
    insert_line = 0
  end

  vim.api.nvim_buf_set_lines(viewer_bufnr, insert_line, -1, false, { 'User:' })

  local last_line_num = vim.api.nvim_buf_line_count(viewer_bufnr)
  vim.api.nvim_buf_add_highlight(viewer_bufnr, -1, 'UserHighlight', last_line_num - 1, 0, -1)

  local display_prompt_data = {}
  vim.list_extend(display_prompt_data, raw_prompt_data)
  vim.list_extend(display_prompt_data, { '' })

  vim.api.nvim_buf_set_lines(viewer_bufnr, -1, -1, false, display_prompt_data)
  -- prompt の内容をクリア
  vim.api.nvim_buf_set_lines(prompt_bufnr, 0, -1, false, {})
  move_bottom(M.viewer.winid)

  request_llm(raw_prompt_data, M.viewer.bufnr)
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
