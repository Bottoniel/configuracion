vim.g.mapleader = " "

local keymap = vim.keymap

keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })

keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "move up selecte lines" })
keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "move down selected lines" })

keymap.set("n", "<C-B>", "<C-V>", { noremap = true, silent = true })

keymap.set("n", "<leader>+", "<C-a>", { desc = "increment number" })
keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" })

keymap.set("x", "<leader>p", '"_dP', { desc = "split window vertically" })

keymap.set("n", "<leader>sv", "<C-w>v", { desc = "split window vertically" })
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "split window horizontally" })
keymap.set("n", "<leader>se", "<C-w>=", { desc = "make splits equal size" })
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "close current split" })

keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" })
keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" })
keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" })
keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previos tab" })
keymap.set("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" })

--code lens
-- vim.keymap.set("n", "<leader>cl", vim.lsp.codelens.run, { desc = "Run code lens" })
vim.keymap.set("n", "<leader>cr", function()
	vim.lsp.codelens.enable(true)
end, { desc = "Refresh code len" })

-- keymap.set("n", "<leader>sm", "<C-w>|<C-w>_", { desc = "maximizar ventana" })
-- keymap.set("n", "<leader>sm", "<C-w>=", { desc = "minimizar ventana" })
--
-- toggle maximizar/restaurar ventana
local maximized = false
keymap.set("n", "<leader>sm", function()
	if maximized then
		vim.cmd("wincmd =")
		maximized = false
	else
		vim.cmd("wincmd |")
		vim.cmd("wincmd _")
		maximized = true
	end
end, { desc = "Maximizar/restaurar ventana" })
