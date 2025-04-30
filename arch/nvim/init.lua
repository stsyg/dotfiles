vim.g.mapleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.termguicolors = true

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    lazypath
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    {'nvim-telescope/telescope.nvim', dependencies = {'nvim-lua/plenary.nvim'}},
    {'nvim-treesitter/nvim-treesitter', build = ':TSUpdate'},
    {'nvim-lualine/lualine.nvim'},
    {'folke/which-key.nvim'},
    {'neovim/nvim-lspconfig'},
    {'hrsh7th/nvim-cmp', dependencies = {'hrsh7th/cmp-nvim-lsp'}}
})