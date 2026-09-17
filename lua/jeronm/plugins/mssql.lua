return {
	"Kurren123/mssql.nvim",
	-- carga nvim-lspconfig (y con él cmp-nvim-lsp y las capabilities) antes que mssql.nvim;
	-- sin esto, en una query nueva (<leader>mn) nvim-cmp no tiene fuente LSP y no hay autocompletado
	dependencies = { "neovim/nvim-lspconfig" },
	config = function()
		local utils = require("mssql.utils")

		local MAX_ROWS = 1000 -- filas que se piden por página
		local MAX_WIDTH = 50 -- ancho máximo de cada celda
		local ns = vim.api.nvim_create_namespace("mssql_panel")

		----------------------------------------------------------------------
		-- Panel de resultados estilo SSMS, uno por pestaña
		----------------------------------------------------------------------
		local panels = {} -- [tabpage] = { bufs, wins, sources, editor_win, msg_win, msg_buf }

		local function panel_of(tab)
			tab = tab or vim.api.nvim_get_current_tabpage()
			panels[tab] = panels[tab] or { bufs = {}, wins = {}, sources = {}, tab = tab }
			return panels[tab]
		end

		local function panel_wins(panel)
			panel.wins = vim.tbl_filter(vim.api.nvim_win_is_valid, panel.wins)
			return panel.wins
		end

		-- reparte el 40% de la pantalla; la ventana de mensajes se queda pequeña
		local function arrange_panel(panel)
			local wins = panel_wins(panel)
			if #wins == 0 then
				return
			end
			local total = math.max(6, math.floor(vim.o.lines * 0.4))
			local msg_win = panel.msg_win
			local msg_height = 0
			if msg_win and vim.api.nvim_win_is_valid(msg_win) then
				msg_height = math.min(6, math.max(3, math.floor(total / 3)))
			end
			local result_wins = vim.tbl_filter(function(win)
				return win ~= msg_win
			end, wins)
			local each = #result_wins > 0 and math.max(3, math.floor((total - msg_height) / #result_wins)) or 0
			for _, win in ipairs(result_wins) do
				vim.wo[win].winfixheight = false
				vim.api.nvim_win_set_height(win, each)
				vim.wo[win].winfixheight = true
			end
			if msg_height > 0 then
				vim.wo[msg_win].winfixheight = false
				vim.api.nvim_win_set_height(msg_win, msg_height)
				vim.wo[msg_win].winfixheight = true
			end
		end

		-- corta una cadena por columnas de pantalla (para alinear la cabecera al hacer scroll)
		local function slice_display(str, from)
			if from <= 0 then
				return str
			end
			local chars = vim.fn.split(str, "\\zs")
			local width, i = 0, 1
			while i <= #chars and width < from do
				width = width + vim.fn.strdisplaywidth(chars[i])
				i = i + 1
			end
			return table.concat(vim.list_slice(chars, i), "")
		end

		-- cabecera fija de la tabla en la barra de la ventana, alineada con el scroll horizontal
		local function update_winbar(win)
			if not vim.api.nvim_win_is_valid(win) then
				return
			end
			local buf = vim.api.nvim_win_get_buf(win)
			local header = vim.b[buf].mssql_header
			if not header then
				return
			end
			local leftcol = vim.api.nvim_win_call(win, function()
				return vim.fn.winsaveview().leftcol
			end)
			local shown = vim.b[buf].mssql_shown or 0
			local total = vim.b[buf].mssql_total
			local counter = total and ("%d/%d filas"):format(shown, total) or (shown .. " filas")
			local text = (slice_display(header, leftcol):gsub("%%", "%%%%"))
			vim.wo[win].winbar = text .. "%=" .. counter .. " "
		end

		local function update_winbars()
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
				if vim.api.nvim_win_is_valid(win) and vim.b[vim.api.nvim_win_get_buf(win)].mssql_header then
					update_winbar(win)
				end
			end
		end

		local function show_in_panel(panel, bufnr, is_messages)
			local wins = panel_wins(panel)
			local msg_win = panel.msg_win
			local has_messages = msg_win and vim.api.nvim_win_is_valid(msg_win)
			if #wins == 0 then
				vim.cmd("botright split")
			elseif not is_messages and has_messages then
				-- los resultados van encima de la ventana de mensajes, como en SSMS
				vim.api.nvim_set_current_win(msg_win)
				vim.cmd("aboveleft split")
			else
				vim.api.nvim_set_current_win(wins[#wins])
				vim.cmd("belowright split")
			end
			local win = vim.api.nvim_get_current_win()
			vim.api.nvim_win_set_buf(win, bufnr)
			vim.wo[win].wrap = false
			vim.wo[win].cursorline = true
			if is_messages then
				panel.msg_win = win
				table.insert(panel.wins, win)
			else
				local position = #panel.wins + 1
				for i, other in ipairs(panel.wins) do
					if other == msg_win then
						position = i
						break
					end
				end
				table.insert(panel.wins, position, win)
				update_winbar(win)
			end
			arrange_panel(panel)
		end

		local function show_panel(panel)
			panel.bufs = vim.tbl_filter(vim.api.nvim_buf_is_valid, panel.bufs)
			local has_messages = panel.show_messages and panel.msg_buf and vim.api.nvim_buf_is_valid(panel.msg_buf)
			if #panel.bufs == 0 and not has_messages then
				vim.notify("No hay resultados todavía", vim.log.levels.INFO)
				return false
			end
			local current_win = vim.api.nvim_get_current_win()
			for _, bufnr in ipairs(panel.bufs) do
				show_in_panel(panel, bufnr)
			end
			if has_messages then
				show_in_panel(panel, panel.msg_buf, true)
			end
			vim.api.nvim_set_current_win(current_win)
			return true
		end

		local function hide_panel(panel)
			local was_inside = vim.tbl_contains(panel_wins(panel), vim.api.nvim_get_current_win())
			for _, win in ipairs(panel_wins(panel)) do
				pcall(vim.api.nvim_win_close, win, false)
			end
			panel.wins, panel.msg_win = {}, nil
			if was_inside and panel.editor_win and vim.api.nvim_win_is_valid(panel.editor_win) then
				vim.api.nvim_set_current_win(panel.editor_win)
			end
		end

		local function clear_panel(panel)
			hide_panel(panel)
			for _, bufnr in ipairs(panel.bufs) do
				if vim.api.nvim_buf_is_valid(bufnr) then
					vim.api.nvim_buf_delete(bufnr, { force = true })
				end
			end
			panel.bufs, panel.sources, panel.pending, panel.show_messages = {}, {}, false, false
		end

		local function toggle_panel()
			local panel = panel_of()
			if #panel_wins(panel) > 0 then
				hide_panel(panel)
			else
				show_panel(panel)
			end
		end

		-- F6: saltar entre el editor SQL y el panel (si está oculto, lo abre)
		local function switch_focus()
			local panel = panel_of()
			if vim.tbl_contains(panel_wins(panel), vim.api.nvim_get_current_win()) then
				if panel.editor_win and vim.api.nvim_win_is_valid(panel.editor_win) then
					vim.api.nvim_set_current_win(panel.editor_win)
				end
			elseif #panel_wins(panel) > 0 or show_panel(panel) then
				vim.api.nvim_set_current_win(panel_wins(panel)[1])
			end
		end

		----------------------------------------------------------------------
		-- Celdas: leer del servicio, ver completo y copiar
		----------------------------------------------------------------------
		local totals = {} -- filas totales por conjunto de resultados
		local function totals_key(owner, batch, result_set)
			return ("%s|%s|%s"):format(owner, batch, result_set)
		end

		local function widths_from_divider(line)
			local inner = line:match("^|%s(.*)%s|$")
			if not inner then
				return {}
			end
			local widths = {}
			for part in vim.gsplit(inner, " | ", { plain = true }) do
				widths[#widths + 1] = #part
			end
			return widths
		end

		local function column_names(bufnr)
			local inner = (vim.b[bufnr].mssql_header or ""):match("^|%s(.*)%s|$") or ""
			local names = {}
			for part in vim.gsplit(inner, " | ", { plain = true }) do
				names[#names + 1] = vim.trim(part)
			end
			return names
		end

		-- mismo formato que usa mssql.nvim para las filas que ya venían
		local function cell_text(value, width)
			local str = tostring(value)
			if vim.fn.strdisplaywidth(str) > MAX_WIDTH then
				str = str:sub(1, MAX_WIDTH) .. "..."
			end
			str = str:gsub("\n", "`\\n`")
			local shown = vim.fn.strdisplaywidth(str)
			if width and shown < width then
				str = str .. string.rep(" ", width - shown)
			end
			return str
		end

		local function row_line(cells, widths)
			local parts = {}
			for i, cell in ipairs(cells) do
				parts[i] = cell_text(cell.displayValue, widths[i])
			end
			return "| " .. table.concat(parts, " | ") .. " |"
		end

		local function column_at_cursor(widths)
			local virtual = vim.fn.virtcol(".")
			local start = 3
			for i, width in ipairs(widths) do
				if virtual < start + width + 1 then
					return i
				end
				start = start + width + 3
			end
			return math.max(#widths, 1)
		end

		local function fetch_rows(bufnr, start_index, count, callback)
			local info = vim.b[bufnr].query_result_info
			if not info then
				return
			end
			local ok, client = pcall(utils.get_lsp_client, info.subset_params.ownerUri)
			if not ok then
				vim.notify("La query de estos resultados ya no está abierta", vim.log.levels.WARN)
				return
			end
			local params = vim.tbl_extend("force", {}, info.subset_params, {
				rowsStartIndex = start_index,
				rowsCount = count,
			})
			client:request("query/subset", params, function(err, result)
				if err or not (result and result.resultSubset) then
					vim.notify("No se pudieron leer las filas: " .. vim.inspect(err), vim.log.levels.ERROR)
					return
				end
				callback(result.resultSubset.rows or {})
			end)
		end

		-- "+": trae la siguiente página de filas y la añade al final
		local function load_more(bufnr)
			local shown = vim.b[bufnr].mssql_shown or 0
			local total = vim.b[bufnr].mssql_total
			if total and shown >= total then
				vim.notify(("Ya se muestran todas las filas (%d)"):format(total), vim.log.levels.INFO)
				return
			end
			local count = total and math.min(MAX_ROWS, total - shown) or MAX_ROWS
			fetch_rows(bufnr, shown, count, function(rows)
				if #rows == 0 then
					vim.notify("No hay más filas", vim.log.levels.INFO)
					return
				end
				local widths = vim.b[bufnr].mssql_widths or {}
				local lines = {}
				for _, cells in ipairs(rows) do
					lines[#lines + 1] = row_line(cells, widths)
				end
				vim.bo[bufnr].modifiable = true
				vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, lines)
				vim.bo[bufnr].modifiable = false
				vim.b[bufnr].mssql_shown = shown + #rows
				update_winbars()
				vim.notify(
					("Mostrando %d%s filas"):format(shown + #rows, total and (" de " .. total) or ""),
					vim.log.levels.INFO
				)
			end)
		end

		-- "K": ver el valor completo de la celda, sin recortar
		local function show_cell(bufnr)
			local widths = vim.b[bufnr].mssql_widths or {}
			local row = vim.fn.line(".") - 1
			local column = column_at_cursor(widths)
			local name = column_names(bufnr)[column] or ("columna " .. column)
			fetch_rows(bufnr, row, 1, function(rows)
				local cells = rows[1]
				if not cells then
					return
				end
				local value = tostring(cells[column] and cells[column].displayValue or "")
				local lines = vim.split(value, "\n")
				local float = vim.api.nvim_create_buf(false, true)
				vim.api.nvim_buf_set_lines(float, 0, -1, false, lines)
				vim.bo[float].modifiable = false
				local width = math.min(100, math.max(30, vim.o.columns - 20))
				local height = math.min(20, math.max(3, #lines))
				local win = vim.api.nvim_open_win(float, true, {
					relative = "editor",
					width = width,
					height = height,
					row = math.floor((vim.o.lines - height) / 2),
					col = math.floor((vim.o.columns - width) / 2),
					border = "rounded",
					title = (" fila %d · %s "):format(row + 1, name),
					style = "minimal",
				})
				vim.wo[win].wrap = true
				vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = float })
				vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", { buffer = float })
			end)
		end

		-- "yc" copia la celda, "yr" la fila entera (separada por tabuladores, lista para Excel)
		local function yank_cell(bufnr, whole_row)
			local widths = vim.b[bufnr].mssql_widths or {}
			local row = vim.fn.line(".") - 1
			local column = column_at_cursor(widths)
			fetch_rows(bufnr, row, 1, function(rows)
				local cells = rows[1]
				if not cells then
					return
				end
				local text
				if whole_row then
					local values = {}
					for i, cell in ipairs(cells) do
						values[i] = tostring(cell.displayValue)
					end
					text = table.concat(values, "\t")
				else
					text = tostring(cells[column] and cells[column].displayValue or "")
				end
				vim.fn.setreg('"', text)
				pcall(vim.fn.setreg, "+", text)
				vim.notify(whole_row and "Fila copiada" or "Celda copiada", vim.log.levels.INFO)
			end)
		end

		----------------------------------------------------------------------
		-- Mensajes del servidor (PRINT, avisos y errores) en su propia ventana
		----------------------------------------------------------------------
		local execute -- se define más abajo
		local map_panel_keys

		local function ensure_messages_buf(panel)
			if panel.msg_buf and vim.api.nvim_buf_is_valid(panel.msg_buf) then
				return panel.msg_buf
			end
			local buf = vim.api.nvim_create_buf(false, true)
			pcall(vim.api.nvim_buf_set_name, buf, ("mensajes sql [%d]"):format(buf))
			vim.bo[buf].modifiable = false
			map_panel_keys(buf, false)
			panel.msg_buf = buf
			return buf
		end

		local function clear_messages(panel)
			panel.show_messages = false
			local buf = panel.msg_buf
			if buf and vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
				vim.bo[buf].modifiable = true
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
				vim.bo[buf].modifiable = false
			end
		end

		-- añade un mensaje al buffer de la pestaña a la que pertenece su query
		local function append_message(panel, message, is_error)
			local buf = ensure_messages_buf(panel)
			local lines = vim.split(tostring(message or ""):gsub("\r", ""), "\n")
			vim.bo[buf].modifiable = true
			local at = vim.api.nvim_buf_line_count(buf)
			if at == 1 and (vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "") == "" then
				at = 0
			end
			vim.api.nvim_buf_set_lines(buf, at, -1, false, lines)
			vim.bo[buf].modifiable = false
			if is_error then
				pcall(vim.api.nvim_buf_set_extmark, buf, ns, at, 0, { end_row = at + #lines, hl_group = "ErrorMsg" })
			end

			panel.show_messages = true
			if panel.tab ~= vim.api.nvim_get_current_tabpage() then
				panel.pending = true
				return
			end
			if not (panel.msg_win and vim.api.nvim_win_is_valid(panel.msg_win)) then
				local current_win = vim.api.nvim_get_current_win()
				show_in_panel(panel, buf, true)
				vim.api.nvim_set_current_win(current_win)
			end
			if panel.msg_win and vim.api.nvim_win_is_valid(panel.msg_win) then
				pcall(vim.api.nvim_win_set_cursor, panel.msg_win, { vim.api.nvim_buf_line_count(buf), 0 })
			end
		end

		map_panel_keys = function(bufnr, is_results)
			local function map(lhs, rhs, desc)
				vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc })
			end
			map("q", function()
				hide_panel(panel_of())
			end, "Ocultar resultados")
			map("<C-r>", toggle_panel, "Mostrar/ocultar resultados")
			map("<F6>", switch_focus, "Ir al editor SQL")
			map("<F5>", function()
				execute()
			end, "Ejecutar la query del editor")
			if is_results then
				map("+", function()
					load_more(bufnr)
				end, "Cargar más filas")
				map("K", function()
					show_cell(bufnr)
				end, "Ver el valor completo de la celda")
				map("yc", function()
					yank_cell(bufnr, false)
				end, "Copiar la celda")
				map("yr", function()
					yank_cell(bufnr, true)
				end, "Copiar la fila")
			end
		end

		-- F5: como SSMS, limpia los resultados de esta pestaña y ejecuta la selección o el archivo
		execute = function()
			local panel = panel_of()
			if vim.tbl_contains(panel_wins(panel), vim.api.nvim_get_current_win()) then
				if not (panel.editor_win and vim.api.nvim_win_is_valid(panel.editor_win)) then
					return
				end
				vim.api.nvim_set_current_win(panel.editor_win)
			end
			clear_panel(panel)
			clear_messages(panel)
			require("mssql").execute_query()
		end

		-- pestaña donde está abierto el buffer SQL que lanzó la consulta (la actual si lo contiene)
		local function tab_of_owner(owner_uri)
			local current = vim.api.nvim_get_current_tabpage()
			local found
			for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
				for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
					if utils.lsp_file_uri(vim.api.nvim_win_get_buf(win)) == owner_uri then
						if tab == current then
							return tab
						end
						found = found or tab
					end
				end
			end
			return found or current
		end

		-- mssql.nvim llama a esto por cada conjunto de resultados
		local function open_results(source)
			local info = vim.b[source].query_result_info
			local tab = info and tab_of_owner(info.subset_params.ownerUri) or vim.api.nvim_get_current_tabpage()
			local panel = panel_of(tab)

			-- si los buffers del plugin de la ejecución anterior ya no existen, esta es una ejecución nueva
			if #panel.sources > 0 and #vim.tbl_filter(vim.api.nvim_buf_is_valid, panel.sources) == 0 then
				clear_panel(panel)
			end

			-- la cabecera y la línea de guiones salen del buffer y pasan a la barra de la ventana
			local lines = vim.api.nvim_buf_get_lines(source, 0, -1, false)
			local header = table.remove(lines, 1) or ""
			local divider = table.remove(lines, 1) or ""

			local copy = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_lines(copy, 0, -1, false, lines)
			vim.bo[copy].modifiable = false
			vim.b[copy].query_result_info = info -- para <leader>ms (guardar resultados)
			vim.b[copy].mssql_header = header
			vim.b[copy].mssql_widths = widths_from_divider(divider)
			vim.b[copy].mssql_shown = #lines
			if info then
				local p = info.subset_params
				vim.b[copy].mssql_total = totals[totals_key(p.ownerUri, p.batchIndex, p.resultSetIndex)]
				pcall(
					vim.api.nvim_buf_set_name,
					copy,
					("resultados %d-%d [%d]"):format(p.batchIndex + 1, p.resultSetIndex + 1, copy)
				)
			end
			local filetype = vim.bo[source].filetype
			vim.api.nvim_buf_call(copy, function()
				vim.bo.filetype = filetype
			end)
			map_panel_keys(copy, true)

			table.insert(panel.sources, source)
			table.insert(panel.bufs, copy)
			if tab == vim.api.nvim_get_current_tabpage() then
				local current_win = vim.api.nvim_get_current_win()
				show_in_panel(panel, copy)
				vim.api.nvim_set_current_win(current_win)
			else
				panel.pending = true -- se muestra al volver a esa pestaña
			end
		end

		require("mssql").setup({
			keymap_prefix = "<leader>m",
			-- el servicio que descarga el plugin (5.0.20250530.2) devuelve sugerencias desfasadas
			tools_file = vim.fn.stdpath("data") .. "/mssql.nvim/sqltools-6.0.20260911.1/MicrosoftSqlToolsServiceLayer",
			max_rows = MAX_ROWS,
			max_column_width = MAX_WIDTH,
			open_results_in = open_results,
			-- view_messages_in no se usa: el plugin lo llama sin el ownerUri de la query, así que
			-- llevamos nosotros la notificación query/message (ver LspAttach) para repartir los
			-- mensajes por pestaña. register_lsp_handler sustituye al handler del plugin.
		})

		vim.keymap.set({ "n", "x" }, "<Plug>(MssqlRun)", function()
			execute()
		end, { desc = "Ejecutar selección o archivo" })
		-- reemplaza el <leader>mx del plugin para que también limpie los resultados de la pestaña
		vim.keymap.set({ "n", "v" }, "<leader>mx", function()
			execute()
		end, { desc = "Execute Query" })
		vim.keymap.set("n", "<leader>mt", toggle_panel, { desc = "Mostrar/ocultar resultados" })

		vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
			callback = function()
				if vim.bo.filetype == "sql" then
					panel_of().editor_win = vim.api.nvim_get_current_win()
				end
			end,
		})

		-- mantiene la cabecera alineada al desplazarte de lado
		vim.api.nvim_create_autocmd({ "WinScrolled", "BufWinEnter", "WinResized" }, {
			callback = update_winbars,
		})

		-- resultados o mensajes que llegaron mientras estabas en otra pestaña
		vim.api.nvim_create_autocmd("TabEnter", {
			callback = function()
				local panel = panel_of()
				if panel.pending then
					panel.pending = false
					vim.schedule(function()
						hide_panel(panel)
						show_panel(panel)
					end)
				end
			end,
		})

		vim.api.nvim_create_autocmd("TabClosed", {
			callback = function()
				for tab, panel in pairs(panels) do
					if not vim.api.nvim_tabpage_is_valid(tab) then
						for _, bufnr in ipairs(panel.bufs) do
							if vim.api.nvim_buf_is_valid(bufnr) then
								vim.api.nvim_buf_delete(bufnr, { force = true })
							end
						end
						if panel.msg_buf and vim.api.nvim_buf_is_valid(panel.msg_buf) then
							vim.api.nvim_buf_delete(panel.msg_buf, { force = true })
						end
						panels[tab] = nil
					end
				end
			end,
		})

		-- las queries nuevas (<leader>mn, <leader>md y <leader>mf) se abren en su propia pestaña;
		-- el plugin crea el buffer con :enew y lo nombra untitled-N.sql en la ventana actual
		vim.api.nvim_create_autocmd("BufFilePost", {
			pattern = "untitled-*.sql",
			callback = function(ev)
				local previous = vim.fn.bufnr("#")
				local fresh = vim.api.nvim_buf_line_count(ev.buf) == 1
					and vim.api.nvim_buf_get_lines(ev.buf, 0, 1, false)[1] == ""
				if not fresh or previous == -1 or previous == ev.buf or not vim.api.nvim_buf_is_valid(previous) then
					return
				end
				-- desde el dashboard o un buffer vacío sin nombre, la query se queda en la pestaña actual
				if
					vim.bo[previous].filetype == "alpha"
					or (vim.api.nvim_buf_get_name(previous) == "" and not vim.bo[previous].modified)
				then
					return
				end
				vim.api.nvim_win_set_buf(0, previous)
				vim.cmd("tab sbuffer " .. ev.buf)
			end,
		})

		vim.api.nvim_create_autocmd("FileType", {
			pattern = "sql",
			callback = function(ev)
				local function map(mode, lhs, rhs, desc, remap)
					vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = desc, remap = remap })
				end
				-- <leader>mm ejecuta el bloque bajo el cursor (delimitado por líneas en blanco)
				map("n", "<leader>mm", "vip<Plug>(MssqlRun)", "Ejecutar bloque SQL bajo el cursor", true)
				-- atajos estilo SSMS
				map({ "n", "x" }, "<F5>", function()
					execute()
				end, "Ejecutar selección o archivo")
				map("i", "<F5>", "<Esc><Plug>(MssqlRun)", "Ejecutar archivo", true)
				map("n", "<C-r>", toggle_panel, "Mostrar/ocultar resultados")
				map("n", "<F6>", switch_focus, "Cambiar foco editor/resultados")
			end,
		})

		vim.api.nvim_create_autocmd("LspAttach", {
			callback = function(ev)
				local client = vim.lsp.get_client_by_id(ev.data.client_id)
				if not client or client.name ~= "mssql_ls" or client._mssql_patched then
					return
				end
				client._mssql_patched = true

				-- SQL Tools Service responde completionItem/resolve con "command": null. En Lua eso llega
				-- como vim.NIL (que es verdadero), cmp-nvim-lsp manda workspace/executeCommand, el servidor
				-- nunca contesta y nvim-cmp se queda suspendido: el autocompletado deja de salir tras
				-- aceptar la primera sugerencia. Quitamos esos null antes de que lleguen a nvim-cmp.
				local request = client.request
				client.request = function(self, method, params, handler, bufnr)
					if method == "completionItem/resolve" and handler then
						local original = handler
						handler = function(err, result, ctx, config)
							if type(result) == "table" then
								for key, value in pairs(result) do
									if value == vim.NIL then
										result[key] = nil
									end
								end
							end
							return original(err, result, ctx, config)
						end
					end
					return request(self, method, params, handler, bufnr)
				end

				-- total de filas de cada conjunto de resultados, para el contador y para "cargar más"
				utils.register_lsp_handler(client, "query/complete", function(_, result)
					if not (result and result.batchSummaries) then
						return
					end
					for batch_index, batch in ipairs(result.batchSummaries) do
						for set_index, summary in ipairs(batch.resultSetSummaries or {}) do
							totals[totals_key(result.ownerUri, batch_index - 1, set_index - 1)] = summary.rowCount
						end
					end
				end)

				-- mensajes del servidor (PRINT, avisos y errores) enrutados a la pestaña de su query.
				-- El plugin llama a view_messages_in sin el ownerUri, así que llevamos nosotros esta
				-- notificación, que sí lo trae; register_lsp_handler sustituye al handler del plugin
				-- (no hay duplicados). Si el ownerUri no corresponde a ningún buffer abierto, va a la
				-- pestaña actual.
				utils.register_lsp_handler(client, "query/message", function(_, result)
					local message = result and result.message
					if not (message and message.message) then
						return
					end
					local tab = (result.ownerUri and tab_of_owner(result.ownerUri))
						or vim.api.nvim_get_current_tabpage()
					append_message(panel_of(tab), message.message, message.isError)
				end)
			end,
		})

		-- mssql.nvim renombra el buffer al guardar una query nueva (`:w ruta/nombre.sql`): su autocmd
		-- AutoNameSQL hace `:file` dentro de BufWritePost y Vim no dispara BufFilePre/Post desde dentro
		-- de otro autocmd, así que hay que vigilar BufWritePost además de BufFilePost.
		-- El query_manager guarda el ownerUri del momento en que se creó (query_manager.lua:33) mientras
		-- que wait_for_notification_async lo recalcula con el nombre nuevo (utils.lua:168): query/complete
		-- nunca coincide, la ejecución se queda "Executing..." hasta el timeout de 6 minutos y no salen
		-- resultados. Aquí reabrimos el documento con el nombre nuevo, recreamos el query_manager y
		-- reconectamos con los mismos parámetros.
		local function track_owner_uri(buf)
			vim.b[buf].mssql_owner_uri = utils.lsp_file_uri(buf)
		end

		local function recover_from_rename(buf)
			if vim.bo[buf].filetype ~= "sql" then
				return
			end
			local old_uri = vim.b[buf].mssql_owner_uri
			local new_uri = utils.lsp_file_uri(buf)
			if not old_uri or old_uri == new_uri then
				return
			end
			track_owner_uri(buf)

			local client = vim.lsp.get_clients({ name = "mssql_ls", bufnr = buf })[1]
			if not client then
				return
			end

			local query_manager = require("mssql.query_manager")
			local old_qm = vim.b[buf].query_manager
			local params = (old_qm and old_qm.get_connect_params()) or {}
			local was_connected = old_qm ~= nil and old_qm.get_state() ~= query_manager.states.Disconnected

			if was_connected then
				-- la conexión del nombre viejo se quedaría abierta en el servicio hasta cerrar Neovim
				client:request("connection/disconnect", { ownerUri = old_uri }, function() end)
			end

			if old_qm then
				vim.b[buf].query_manager = query_manager.create_query_manager(buf, client)
			end
			local qm = vim.b[buf].query_manager

			client:notify("textDocument/didClose", { textDocument = { uri = old_uri } })
			client:notify("textDocument/didOpen", {
				textDocument = {
					uri = new_uri,
					languageId = "sql",
					version = 0,
					text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"),
				},
			})

			if not (qm and was_connected and params.connection) then
				return
			end
			utils.try_resume(coroutine.create(function()
				qm.connect_async(params)
				qm.initialise_cache_async()
				utils.log_info("mssql.nvim: reconectado tras renombrar el buffer")
			end))
		end

		vim.api.nvim_create_autocmd("FileType", {
			pattern = "sql",
			callback = function(ev)
				track_owner_uri(ev.buf)
			end,
		})

		vim.api.nvim_create_autocmd({ "BufFilePost", "BufWritePost" }, {
			desc = "mssql_recover_rename",
			callback = function(ev)
				recover_from_rename(ev.buf)
			end,
		})
	end,
}
