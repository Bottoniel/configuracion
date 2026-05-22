return {
	"mistweaverco/kulala.nvim",
	keys = {
		{
			"<leader>mm",
			function()
				require("kulala").run()
			end,
			desc = "Send request",
		},
		{
			"<leader>ml",
			function()
				require("kulala").run_all()
			end,
			desc = "Send all requests",
		},
		{
			"<leader>mb",
			function()
				require("kulala").replay()
			end,
			desc = "Open scratchpad",
		},
	},
	ft = { "http", "rest" },
	opts = {
		global_keymaps = false,
		global_keymaps_prefix = "<leader>m",
		kulala_keymaps_prefix = "",
	},
}
