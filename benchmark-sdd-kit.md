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
5. в каждом из репозиториев nude-WBN (nude-claude/web-backend-new) и sdd-WBN (sdd-kit-claude/web-backend-new) запускаем терминал с claude code
6. найти в youtack назначенные на меня таски со статусами backlog/read_to_go (use mcp youtack)
7. уточнить какую из задач взять в работу (к примеру WEB-2334)
8. выполнить шаги refactor_v4/INIT.md:1-33
9. сравнить результаты и метрики