return {
  { 'nvim-treesitter/nvim-treesitter', build = ':TSUpdate',
    opts = {
      ensure_installed = { 'go', 'python', 'rust', 'typescript', 'lua', 'bash', 'json' },
      highlight = { enable = true },
    },
  },
}
