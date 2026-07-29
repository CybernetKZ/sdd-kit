нам нужно провести сравнение С и БЕЗ sdd-kit на нашем реальном репозитории и реальной задаче.

изначально мы должны 
1. проверить все глобальные (claude code, etc):
- skills
- plugins
- rules
- CLAUDE.md / AGENTS.md / etc
- другие tools влияющие на процессы работы с LLM (на примере claude code)

2. с разрешения пользователя отключить / убрать их все -> проверить
3. git clone https://github.com/CybernetKZ/web-backend-new в nude-claude И sdd-kit-claude
4. запустить refactor_v4/sdd-kit для sdd-kit-claude/web-backend-new

