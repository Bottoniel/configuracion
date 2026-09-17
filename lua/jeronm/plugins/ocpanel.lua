return {
	dir = vim.fn.expand("~/Documents/lua"),
	name = "ocpanel",
	config = function()
		require("ocpanel").setup({
			opencode = "opencode",
			workdir = nil,
			hostname = "127.0.0.1",
			port = 4096,
			ui = {
				width = 0.40,
				input_height = 8,
			},
			keymaps = {
				toggle = "<leader>og",
				model = "<leader>op",
			},
		})
	end,
}
