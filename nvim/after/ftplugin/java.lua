-- ftplugin: java.lua

-- Treesitter highlight
require("config.treesitter").ensure_parsers_installed { "java", "javadoc" }
require("config.treesitter").setup_highlight("java")

-- TODO: LSP (jdtls)

