return {
	dir = vim.fn.expand("~/Documents/Net/abap/abap-adt.nvim"),
	name = "abap-adt",
	dependencies = { "nvim-telescope/telescope.nvim" },
	config = function()
		require("abap-adt").setup({
			sapcli = "sapcli",
			-- sin workdir: baja a la carpeta actual (:pwd) en cada descarga
			default_package = nil,
			corrnr = nil,
			transport_target = "LOCAL",
			max_results = 51,
			picker = "auto",
			debounce_ms = 350,
			min_chars = 2,
			keymaps = {
				search = "<leader>af",
				create = "<leader>an",
				write = "<leader>aw",
			},
		})
	end,
}
