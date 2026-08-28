# Catppuccin Mocha Theme Overlay

## Scope

This package provides a shareable VS Code color overlay for the Catppuccin Mocha theme. It covers workbench surfaces, Explorer selection states, Git decorations, low-saturation file icons, green comments, and Better Comments tags.

The source of truth is [`settings-overlay.jsonc`](./settings-overlay.jsonc). The overlay does not contain personal paths, proxies, SSH hosts, project settings, editor language-formatting rules, or Rust-specific type/function color palettes.

The official theme name and extension use `Catppuccin`; the user-facing archive name uses “Cappuccino Mocha”.

## Required extensions

Install these extensions in the VS Code profile that owns the target settings:

```text
Catppuccin.catppuccin-vsc
pkief.material-icon-theme
aaron-bond.better-comments
```

Install `rust-lang.rust-analyzer` separately when the workspace contains Rust. This overlay does not change rust-analyzer semantic-highlighting switches; it only supplies generic theme-scoped comment colors.

Do not install `kraftwer1.darcula-extra` or add a Darcula-specific semantic/token color block.

The CLI form is:

```sh
code --install-extension Catppuccin.catppuccin-vsc
code --install-extension pkief.material-icon-theme
code --install-extension aaron-bond.better-comments
```

Use the Windows VS Code CLI or the Extensions view for the same desktop profile that displays the workbench. A WSL remote extension host does not replace the local workbench theme installation.

## Agent installation procedure

An Agent applying this package must follow this scope:

1. Resolve the active desktop VS Code user settings file. The usual Windows path is `C:\Users\<user>\AppData\Roaming\Code\User\settings.json`. If a profile-specific settings file is active, use that file instead.
2. Read and parse the target as JSONC. Create a recoverable backup before writing.
3. Install or verify the three required extension IDs above.
4. Deep-merge `settings-overlay.jsonc` into the target settings. Preserve unrelated user settings.
5. Merge the nested `[Catppuccin Mocha]` objects instead of replacing the complete `workbench.colorCustomizations`, `editor.semanticTokenColorCustomizations`, or `editor.tokenColorCustomizations` objects.
6. Merge `better-comments.tags` by tag. The five tags in the overlay are the desired values; unrelated user-defined tags may remain.
7. Remove any active `Darcula Extra` theme selection or Darcula-specific color override. Do not remove unrelated Markdown preview settings.
8. Restart VS Code after writing. Better Comments documents a restart requirement for tag color changes.

The Agent must not overwrite the complete `settings.json`, delete unrelated extensions, or copy settings from the source machine that are not present in `settings-overlay.jsonc`.

## Verification

After restart, verify all of the following:

- `workbench.colorTheme` is `Catppuccin Mocha`.
- `workbench.iconTheme` is `material-icon-theme`.
- Explorer and workbench edge surfaces use the dark `#191927` family with `#313244` borders.
- Explorer selection uses `#25253A`; hover uses translucent `#222234B3`.
- Ordinary comments and documentation comments use the low-saturation green `#86A994`.
- Better Comments uses muted blue, gold, red, and green tags without opaque backgrounds.
- Git added/untracked markers use `#718B79`; modified markers use `#9A8C66`.
- The active settings contain no `Darcula Extra` reference and no full Darcula-style Rust palette.
- The settings file parses as JSONC without errors.

A visual check should include an Explorer tree with a selected file, Git `M`/`U` decorations, a Rust or shell source file, an ordinary comment, and at least one Better Comments tag.

On Windows, the operating-system outer window border can remain system-controlled. The overlay controls the VS Code custom title bar and workbench surfaces.

## Palette reference

| Surface | Color |
| --- | --- |
| Workbench edge / Explorer base | `#191927` |
| Borders | `#313244` |
| Explorer selection | `#25253A` |
| Explorer hover | `#222234B3` |
| Comment | `#86A994` |
| Git added / untracked | `#718B79` |
| Git modified | `#9A8C66` |
| Git deleted | `#907783` |
| Git conflict | `#8D829F` |
| File icon base | `#9290A0` |
| Folder icon base | `#918BA5` |

Material Icon Theme uses saturation `0.42` and opacity `0.68`.

## Rollback

Restore the backup created before the merge, or remove only the keys supplied by `settings-overlay.jsonc`. Keep unrelated user settings and extensions intact.
