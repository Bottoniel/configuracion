return {
	name = "dotnetkit.nvim",
	dir = vim.fn.expand("~/Documents/nvim"),
	ft = "cs",
	cmd = {
		"CsNew",
		"CsAddRef",
		"CsRemoveRef",
		"CsSlnAdd",
		"CsSlnRemove",
		"CsAddPkg",
		"CsListPkg",
		"CsRemovePkg",
		"CsUpdatePkg",
		"CsNewProject",
		"CsBuild",
		"CsRun",
		"CsWatch",
		"CsStop",
		"CsDebugRun",
		"EfMigrate",
		"EfUpdate",
		"EfRemove",
		"EfList",
		"EfScript",
	},
	dependencies = { "L3MON4D3/LuaSnip" },
	keys = {
		{
			"<leader>cn",
			function()
				require("csnew").create()
			end,
			desc = "New C# type",
		},
	},
	opts = {},
}
