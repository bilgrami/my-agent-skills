# my-agent-skills

A collection of reusable Claude agent skills that can be shared and used across projects.

## What are Agent Skills?

Agent skills are modular, reusable instructions and prompts that extend what Claude agents can do. Each skill lives in its own directory under `skills/` and contains:

- `skill.md` — the skill definition and instructions for the agent
- `README.md` — human-readable documentation, usage examples, and configuration notes

## Skills

| Skill | Description |
|-------|-------------|
| [example-skill](skills/example-skill/) | A template skill demonstrating the required structure |

## Usage

To use a skill, reference its `skill.md` file when configuring your Claude agent. Skills are designed to be composable — you can combine multiple skills for more complex workflows.

## Contributing

1. Create a new directory under `skills/` named after your skill (use `kebab-case`)
2. Add a `skill.md` with the agent instructions
3. Add a `README.md` documenting the skill for humans
4. Open a pull request