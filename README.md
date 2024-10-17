# norminette-lint.nvim

A Neovim linter that uses Norminette to enforce C coding style.

This Neovim plugin provides seamless integration with Norminette, a C code linter that helps maintain consistent and high-quality coding style. Upon saving or making changes in a C file, the plugin automatically runs Norminette and displays the errors directly in your editor, making it easy to identify and fix issues.

https://github.com/user-attachments/assets/f96f2a86-5ce8-47a6-a84c-968060185fff

## Features

- **Norminette Integration**: Runs Norminette transparently when saving C files or detecting changes.
- **Error Visualization**: Displays Norminette errors directly in the editor using Neovim's diagnostic system.
- **Support for Header Files**: Handles `.h` files by creating temporary files.
- **Configurable Keybindings**: Easily enable or disable the linter with a user-defined key combination.
- **Customizable Configuration**: Adjust plugin settings upon initialization.

## Installation

### Requirements

- **Neovim**: Version 0.5.0 or later.
- **Norminette**: Installed on your system.

### Using Lazy.nvim

This plugin can be installed using [Lazy.nvim](https://github.com/folke/lazy.nvim). Add the following code to your Neovim configuration file:

```lua
{
  "TuTaRdrgZ/norminette-lint.nvim",
  config = function()
    require("norminette-lint").setup({
      enable_on_start = false,  -- Default to false to improve startup performance
      keybinding = "<leader>Fn", -- Default keybinding, you can define yours
    })
  end
}
