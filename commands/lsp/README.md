# LSP Commands

## /lsp:setup

Configures LSP plugins at project scope. Run once when starting work in a new project:

```
/lsp:setup
```

Reads your installed LSP plugins, scans the project for language indicators, then asks
which plugins to enable. Detected languages are listed first, but you can enable any
installed plugin regardless of whether matching files exist yet. Your selections are
written to `.claude/settings.json` in the project root. Run again at any time to reconfigure.
