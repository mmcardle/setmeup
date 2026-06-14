return {
  { 'williamboman/mason.nvim', config = true },
  { 'williamboman/mason-lspconfig.nvim',
    dependencies = { 'neovim/nvim-lspconfig' },
    opts = {
      ensure_installed = { 'gopls', 'pyright', 'rust_analyzer', 'ts_ls' },
      handlers = { function(server) require('lspconfig')[server].setup({}) end },
    },
  },
}
