# blink-cmp-kitty

A kitty completion source for the [blink.cmp]
[Neovim](https://github.com/neovim/neovim) plugin. Provides completion
suggestions based on the content of [kitty](https://sw.kovidgoyal.net/kitty/)
windows.

## Features

- Integrates with [kitty](https://sw.kovidgoyal.net/kitty/)'s remote control to
  provide completion suggestions based on the content of every window, the one
  running Neovim left out.
- Picks out words, `kebab-case`, `snake_case` and `dot.case` names as text, and
  emails, URLs and `--options` as values.
- Never holds up typing: windows are read in the background, one after the
  other, with a deadline and a cap on what is read; a completion is answered
  from the words kept.
- Configurable windows, tabs and OS windows to read, and trigger characters to
  activate completions.

## Requirements

- Neovim 0.10+
- [kitty](https://sw.kovidgoyal.net/kitty/) with [remote
  control](https://sw.kovidgoyal.net/kitty/remote-control/) allowed, for example
  in `kitty.conf`:

  ```conf
  allow_remote_control socket-only
  listen_on unix:@kitty-{kitty_pid}
  ```

  `kitty @ ls` in another window prints JSON once it works. Inside a multiplexer
  (zellij, tmux), set `listen_on`: the source then talks to `KITTY_LISTEN_ON`
  instead of the terminal.
- [blink.cmp]

## Installation & Configuration

Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "saghen/blink.cmp",
  dependencies = {
      "dynamotn/blink-cmp-kitty",
  },
  opts = {
    sources = {
      default = {
        --- your other sources
        "kitty",
      },
      providers = {
        kitty = {
          module = "blink-cmp-kitty",
          name = "kitty",
          -- default options
          opts = {
            enabled = true,
            -- only suggest completions from `kitty` if the `trigger_chars`
            -- are used
            triggered_only = false,
            trigger_chars = { "." },
            -- `kitten` when installed, else `kitty`
            executable = nil,
            -- what `kitty @ get-text` reads of each window: `all` takes the
            -- scrollback too, `screen` only what is shown
            extent = "all",
            -- which OS windows, tabs and windows are read; each is handed
            -- what `kitty @ ls` says about it
            include_os_window = function(os_window) return true end,
            include_tab = function(tab) return true end,
            include_window = function(window) return not window.is_self end,
            -- seconds between two reads of the windows
            min_update_period = 5,
            -- seconds a word stays once its window no longer shows it
            item_lifetime = 60,
            -- milliseconds a kitty command may take
            timeout = 2000,
            -- bytes read of one window at most
            max_bytes = 1024 * 1024,
            -- a `vim.log.levels` value; the log is `stdpath("log")/blink-cmp-kitty.log`
            log_level = vim.log.levels.OFF,
          },
        },
      }
    }
  }
}
```

## Commands

| Command                 | What it does                                   |
| ----------------------- | ---------------------------------------------- |
| `:BlinkCmpKittyLs`      | Show what `kitty @ ls` says, as JSON           |
| `:BlinkCmpKittyItems`   | Show the words kept, and why a read failed     |
| `:BlinkCmpKittyRefresh` | Read the windows again now                     |

The windows are also read again on entering a Neovim window, once the source is
in use.

## Development

```sh
make test   # plenary specs; clones plenary.nvim and blink.cmp into .tests/
make lint   # stylua --check
```

## Contributing

Contributions are welcome! Please open an issue or submit a pull request if you
have any suggestions, bug reports, or feature requests.

## Credits

- [garyhurtz/blink_cmp_kitty](https://github.com/garyhurtz/blink_cmp_kitty): the
  kitty source whose features this rewrites
- [dynamotn/blink-cmp-zellij](https://github.com/dynamotn/blink-cmp-zellij): the
  zellij source it is shaped after

[blink.cmp]: https://github.com/Saghen/blink.cmp
