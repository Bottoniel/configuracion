return {
	"nvim-treesitter/nvim-treesitter",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		require("nvim-treesitter").install({
			"c_sharp",
			"lua",
			"c",
			"javascript",
			"typescript",
			"tsx",
			"json",
			"yaml",
			"html",
			"css",
			"markdown",
			"bash",
			"python",
			"go",
			"rust",
			"sql",
		})

		vim.api.nvim_create_autocmd("FileType", {
			callback = function()
				pcall(vim.treesitter.start)
			end,
		})
	end,
}
