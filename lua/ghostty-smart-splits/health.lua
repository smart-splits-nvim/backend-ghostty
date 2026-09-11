local M = {}

function M.report()
  if vim.fn.has('nvim-0.11') == 1 then
    vim.health.ok('Neovim >= 0.11')
  else
    vim.health.error('Neovim >= 0.11 is required')
  end
  if vim.fn.has('macunix') == 1 then
    vim.health.ok('macOS')
  else
    vim.health.warn('Only macOS is supported')
  end
  if vim.fn.executable('osascript') == 1 then
    vim.health.ok('osascript is available')
  else
    vim.health.warn('osascript is unavailable')
  end
  if require('ghostty-smart-splits.config').transport == 'ephemeral' then
    vim.health.info("transport = 'ephemeral': each request starts osascript")
  elseif require('ghostty-smart-splits.transport').status().running then
    vim.health.ok("transport = 'persistent': osascript process is running")
  else
    vim.health.info("transport = 'persistent': starts on the next attachment or action")
  end
  -- cmux embeds Ghostty and reports TERM_PROGRAM=ghostty too.
  if vim.env.TERM_PROGRAM == 'ghostty' then
    vim.health.ok(vim.env.CMUX_SURFACE_ID and 'Running in cmux' or 'Running in Ghostty')
    vim.health.info('Automation permissions: not checked')
  else
    vim.health.warn('Not running in Ghostty or cmux')
  end
  if vim.env.SSH_CONNECTION or vim.env.TMUX or vim.env.ZELLIJ then
    vim.health.warn('SSH and nested terminal multiplexers are not supported')
  end
  if pcall(require, 'smart-splits') then
    vim.health.ok('smart-splits.nvim is available')
  else
    vim.health.error('Install smart-splits-nvim/smart-splits.nvim')
  end
end

function M.check()
  vim.health.start('backend-ghostty')
  M.report()
end

return M
