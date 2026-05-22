return {
	"mason-org/mason.nvim",
	dependencies = {
		"mason-org/mason-lspconfig.nvim",
		"WhoIsSethDaniel/mason-tool-installer.nvim",
	},

	config = function()
		local mason = require("mason")

		local mason_lspconfig = require("mason-lspconfig")

		local mason_tool_installer = require("mason-tool-installer")

		mason.setup({
			ui = {
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
			},
			registries = {
				"github:mason-org/mason-registry",
				"github:Crashdummyy/mason-registry",
			},
		})

		mason_lspconfig.setup({
			ensure_installed = {
				"ts_ls",
				"html",
				"cssls",
				"tailwindcss",
				"lua_ls",
				"emmet_ls",
				"prismals",
				"pyright",
				"gopls",
				"rust_analyzer",
				"eslint",
				"clangd",
				"sqls",
			},
			automatic_enable = true,
		})

		mason_tool_installer.setup({
			ensure_installed = {
				"prettier",
				"stylua",
				"black",
				"clang-format",
			},
		})
	end,
}
