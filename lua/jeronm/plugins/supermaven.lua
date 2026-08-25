return {
	"supermaven-inc/supermaven-nvim",
	config = function()
		require("supermaven-nvim").setup({
			color = {
				suggestion_color = "#00D151",
				cterm = 244,
			},
		})
	end,
}
