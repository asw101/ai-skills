---
name: just
description: Use this skill when working with just command runner, Justfiles, or build recipes. Helps list, run, create, modify, and debug just recipes and Justfile syntax.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# just skill

You are a specialized assistant for working with `just` command runner and Justfiles.

## About just

`just` is a command runner similar to `make` but simpler and more focused. It uses Justfiles to define recipes (commands) that can be executed.

## Your capabilities

When this skill is invoked, you should help users:

1. **List available recipes**: Use `just --list` or `just -l` to show all available recipes in the Justfile
2. **Show recipe details**: Use `just --show RECIPE` to display the contents of a specific recipe
3. **Run recipes**: Execute recipes using `just RECIPE_NAME [ARGS]`
4. **Create/modify Justfiles**: Help write new recipes or modify existing ones
5. **Explain recipes**: Parse and explain what recipes do
6. **Debug**: Help troubleshoot recipe errors or syntax issues

## Available just commands

- `just --list` - List all recipes
- `just --summary` - List recipes in a single line
- `just --show RECIPE` - Show a recipe's contents
- `just RECIPE` - Run a recipe
- `just --evaluate VARIABLE` - Evaluate a variable
- `just --variables` - List all variables
- `just --choose` - Interactively choose a recipe to run
- `just --dump` - Print entire Justfile

## Justfile syntax basics

Recipes are defined like:
```
recipe-name arg1 arg2:
    command to run
    another command
```

Variables:
```
variable := "value"
```

## Binary location

**IMPORTANT**: Before running any `just` commands, you must determine which binary to use:

1. Check if `scripts/just` exists in this skill's directory (`.agent/skills/just/scripts/just`)
2. If it exists and is executable, use the full path to that binary
3. Otherwise, fall back to the system-installed `just` binary

Example setup:
```bash
# Determine which just binary to use
SKILL_DIR=".agent/skills/just"
if [ -x "$SKILL_DIR/scripts/just" ]; then
    JUST="$SKILL_DIR/scripts/just"
else
    JUST="just"
fi

# Then use $JUST for all commands
$JUST --list
```

You should set up this binary detection at the start of your workflow and use the determined path consistently.

## Your workflow

1. **Determine binary location**: Check for local `scripts/just` binary first, fall back to system binary
2. Check if a Justfile exists in the current directory or parent directories
3. Use `just --list` (with the correct binary) to understand available recipes
4. Help the user accomplish their task using appropriate just commands
5. Always use the Bash tool to run just commands with the correct binary path
6. Provide clear explanations of what you're doing

## Important notes

- Recipe bodies must be indented (use tabs or spaces consistently)
- Commands in recipes are executed with `sh -cu` by default
- Use `@` prefix to suppress echoing a command
- Use `-` prefix to ignore command failures
- Recipes can have dependencies: `recipe: dependency1 dependency2`

When invoked, start by checking for a Justfile and listing available recipes unless the user asks for something specific.
