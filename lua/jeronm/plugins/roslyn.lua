return {
	-- "seblyng/roslyn.nvim",
	-- ---@module 'roslyn.config'
	-- ---@type RoslynNvimConfig
	-- ft = { "cs", "razor" },
	-- opts = {
	-- 	-- your configuration comes here; leave empty for default settings
	-- 	filewatching = "roslyn",
	-- 	config = {
	-- 		settings = {
	-- 			["csharp|background_analysis"] = {
	-- 				dotnet_analyzer_diagnostics_scope = "openFiles",
	-- 				dotnet_compiler_diagnostics_scope = "openFiles",
	-- 			},
	-- 			["csharp|inlay_hints"] = {
	-- 				csharp_enable_inlay_hints_for_implicit_object_creation = true,
	-- 				csharp_enable_inlay_hints_for_implicit_variable_types = true,
	-- 			},
	-- 			["csharp|code_lens"] = {
	-- 				dotnet_enable_references_code_lens = true,
	-- 			},
	-- 		},
	-- 	},
	-- },
	"seblyng/roslyn.nvim",
	---@module "roslyn.config"
	---@type RoslynNvimConfig
	ft = { "cs", "razor" },

	init = function()
		vim.lsp.config("roslyn", {
			capabilities = {
				workspace = {
					didChangeWatchedFiles = {
						dynamicRegistration = true,
					},
				},
				textDocument = {
					diagnostic = {
						dynamicRegistration = true,
					},
				},
			},

			settings = {
				["csharp|background_analysis"] = {
					dotnet_analyzer_diagnostics_scope = "openFiles",
					dotnet_compiler_diagnostics_scope = "openFiles",
				},
				["csharp|inlay_hints"] = {
					csharp_enable_inlay_hints_for_implicit_object_creation = true,
					csharp_enable_inlay_hints_for_implicit_variable_types = true,
				},
				["csharp|code_lens"] = {
					dotnet_enable_references_code_lens = true,
				},
			},
		})
	end,

	opts = {
		filewatching = "auto",
		lock_target = false,
	},
}
