return {
	"seblyng/roslyn.nvim",
	---@module 'roslyn.config'
	---@type RoslynNvimConfig
	ft = { "cs", "razor" },
	opts = {
		-- your configuration comes here; leave empty for default settings
		filewatching = "roslyn",
		config = {
			settings = {
				["csharp|inlay_hints"] = {
					csharp_enable_inlay_hints_for_implicit_object_creation = true,
					csharp_enable_inlay_hints_for_implicit_variable_types = true,
				},
				["csharp|code_lens"] = {
					dotnet_enable_references_code_lens = true,
				},
			},
		},
	},
}
