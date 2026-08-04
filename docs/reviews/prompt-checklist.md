# Prompt checklist — как писать тексты skill/agent для Claude Code

Эталон для рерайт-сабагентов волн 1–3 (ADR-0022, `docs/PLAN_TEXTS.md`). Каждый
пункт — проверяемое утверждение (да/нет по конкретному файлу). Термины —
по-английски, комментарии — по-русски. Пункт без источника или без
подтверждения в наших файлах помечен «(предположение)».

## 1. Frontmatter агента (`.claude/agents/*.md`)

Источник: https://code.claude.com/docs/en/sub-agents

- [ ] `name`, `description` — обязательные поля; `tools`, `model` —
  опциональные (без `tools` агент наследует все инструменты сессии).
- [ ] `description` отвечает на один вопрос — **when Claude should delegate
  to this subagent** — не «что агент умеет в деталях», а «в какой момент его
  вызвать». Доки прямо называют его routing-полем: «Claude uses each
  subagent's description to decide when to delegate tasks».
- [ ] Detailed descriptions — да, но detailed ≠ длинный: официальные примеры
  (`code-reviewer`, `debugger`, `data-scientist`) держат description в
  1–2 предложениях: роль + триггер + «use proactively/immediately when…».
  Инструкции ЧТО ДЕЛАТЬ (процесс, формат вывода, запреты) не входят в
  description — это разросшийся description, антипаттерн волны 0.
- [ ] Триггерные фразы («use proactively», «use immediately after…», «use
  when…») повышают шанс автоделегирования — доки прямо советуют их вписывать.
- [ ] `tools` — явный список только нужных инструментов (security + focus);
  «Limit tool access» — один из четырёх официальных best practices.
- [ ] `model` — фиксируется во frontmatter, не выбирается на бегу
  (`model: opus|sonnet|haiku|inherit`); для нашего кита это уже решено
  ADR-0021 (модели статичны per-агент).
- [ ] Тело системного промпта начинается не с description, а с отдельного
  текста после frontmatter — «Design focused subagents: each subagent
  should excel at one specific task» (первый из 4 официальных best practices).

Типовые ошибки (из доков + наблюдений):
- Инструкции процесса/формата в `description` вместо тела — description
  тогда попадает в контекст роутинга на каждый вызов, раздувая его без нужды.
- Description длиной в абзац с примерами и оговорками — снижает точность
  матчинга, а не повышает (routing работает на коротком сигнале).

## 2. Frontmatter скилла (`SKILL.md`)

Источник: https://code.claude.com/docs/en/skills

- [ ] Только `description` рекомендован («Recommended», не Required); если
  отсутствует — Claude берёт первый параграф markdown.
- [ ] `description` = **что делает + когда использовать**, в таком порядке;
  первым — «put the key use case first», потому что combined `description`
  + `when_to_use` **обрубается на 1536 символов** в общем листинге скиллов
  (context budget shared между всеми скиллами).
- [ ] `when_to_use` — отдельное поле под триггерные фразы/примеры запросов,
  если description сам по себе недостаточно однозначен для роутинга.
- [ ] Тело SKILL.md — сама процедура/инструкции, которые исполняются только
  когда скилл реально вызван («full skill content only loads when invoked»
  в обычной сессии) — то есть длина тела почти бесплатна по контексту,
  в отличие от description, который висит в листинге всегда.
- [ ] Supporting files (`template.md`, `scripts/*.sh`, `examples/*.md`) —
  выносить туда то, что не нужно грузить каждый раз; SKILL.md ссылается на
  них явно, «so Claude knows what they contain and when to load them».
- [ ] Наш feature-flow — reference-скилл (канон процедуры), не
  автоматизация одной командой; для такого типа длинное тело — норма, доки
  это разделяют («Types of skill content»: reference content run inline vs
  procedural/executable content).

## 3. Тело промпта — структура

Источник: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-4-best-practices
(секция General principles); подтверждается формой официальных subagent-примеров
(code-reviewer/debugger/data-scientist, sub-agents doc).

- [ ] Роль в первом предложении тела («You are a senior code reviewer…» /
  «You interrogate a plan…») — «Give Claude a role... even a single
  sentence makes a difference».
- [ ] Дальше — вход/процесс как **пронумерованный список шагов**, когда
  порядок или полнота шагов важны («Provide instructions as sequential
  steps using numbered lists... when the order or completeness of steps
  matters» — Golden rule секция). Все три официальных примера следуют
  этой форме: «When invoked: 1. … 2. … 3. …».
- [ ] Императивы, а не описания: «Run git diff», «Cite the file:line», не
  «the agent should look at git diff». Подтверждается стилем официальных
  примеров (сплошные глаголы в повелительном наклонении).
- [ ] Конкретика вместо generic-чеклиста: официальный `code-reviewer`
  использует общий checklist («No duplicated code», «Good test coverage») —
  это нормально для *generic* ревьюера, но доки отдельно требуют:
  «Golden rule: show your prompt to a colleague with minimal context… if
  they'd be confused, Claude will be too» — то есть для агента, который
  читает конкретный репозиторий/спеку, чеклист должен цепляться за то, что
  реально там есть (наш plan-griller это уже делает: «Cite the file:line or
  Scenario that makes each question real» — сильная сторона файла).
- [ ] Явный output-контракт с форматом (и, где возможно, примером/шаблоном
  строки) — «Control the format of responses»: явно указывать желаемый
  формат эффективнее, чем полагаться на то, что Claude угадает. plan-griller
  делает это правильно: фиксированный трёхстрочный формат вопроса + формат
  `## Grill`-блока + единственная verdict-строка.
- [ ] «Зачем» у неочевидных правил — «Add context to improve performance»:
  объяснение причины **обобщается** моделью лучше, чем голый запрет
  (пример из доков: «NEVER use ellipses» слабее, чем «…text-to-speech
  engine will not know how to pronounce them»). У нас: planner.md объясняет
  «зачем» почти для каждого правила («A plan built on an unverified ticket
  claim is the most expensive kind of wrong») — хороший образец.
- [ ] Explicit «above and beyond» request, если оно нужно — доки: не
  надеяться, что модель сама решит быть тщательной, просить явно
  («Include as many relevant features… go beyond the basics»).
- [ ] Примеры (few-shot) — 3–5 штук, релевантные и разные, если формат
  вывода некритично тривиален; для короткого формата (одна строка
  вердикта) пример не нужен — сам формат уже пример.

## 4. Чего НЕ писать

Источник: https://code.claude.com/docs/en/sub-agents,
https://code.claude.com/docs/en/skills, ADR-0022.

- [ ] Ссылки `ADR-XXXX` внутри промпта агента/скилла — целевой репозиторий
  не имеет `docs/ADR/`, ссылка ничего агенту не даёт (ADR-0022 п.2/3).
  Правило остаётся фразой, ссылка живёт в grounding-таблице WORKFLOW.md.
- [ ] Дубли того, что агент и так умеет как базовая модель (generic
  «write readable code», «handle errors» без привязки к репозиторию) —
  подтверждено самим ADR-0022 приоритетом «дедупликация» и духом Golden
  rule (специфика > общие места).
- [ ] Маркетинг-проза («мощный», «профессиональный», «best-in-class») —
  не встречается ни в одном официальном примере; система инструкций — не
  реклама (предположение, но напрямую следует из тона всех примеров доков).
- [ ] Избыточные примеры сверх 3–5 (доки прямо дают потолок — «Include 3–5
  examples for best results»), особенно если формат тривиален (одна
  строка/один блок).
- [ ] Процедурные разделы, продублированные в другом каноническом файле
  (skill vs WORKFLOW.md) — по ADR-0022 п.3 канон процедуры живёт в одном
  месте (skills), второе место — одна строка + ссылка.
- [ ] Абсолютные пути конкретной машины разработчика в теле промпта
  (найден дрейф: `tools/cf/mine-section.md`) — непереносимо между
  машинами/CI, чистый баг, не связанный с доками, но исправление входит в
  план волны 4.

## 5. Длина и экономия токенов

Источник: https://code.claude.com/docs/en/skills (skill listing budget),
ADR-0022 п.1 (приоритет: правильность → эффективность → дедуп → токены).

- [ ] `description` (agent и skill) — самое дорогое место: висит в контексте
  при каждом вызове модели (routing listing). Здесь экономия токенов имеет
  наибольший ROI: описание в листинге скиллов режется по бюджету
  «1% контекстного окна модели», и урезка идёт с наименее используемых
  скиллов первыми — длинный description первым теряет читаемость.
- [ ] Тело промпта (после frontmatter) — грузится только при вызове агента/
  скилла, поэтому длина здесь оправдана, когда несёт информацию, которая
  реально меняет поведение (конкретные CLI-команды, конкретный формат
  вывода, конкретные правила репозитория). Длина без информации — просто
  дублирование того, что модель и так знает или что уже написано в другом
  каноническом файле.
- [ ] При конфликте между «короче» и «точнее» ADR-0022 отдаёт точности
  приоритет: «Короткий, но неверный текст хуже длинного верного» — сжатие
  не должно ломать факты (пример дрейфа волны 0: сжимать CLI-шпаргалку в
  planner.md можно только ПОСЛЕ проверки актуальности команд openspec
  1.7.0, не раньше).
- [ ] Ориентир (предположение, не из доков): agent-файл — 30–120 строк
  тела; description — 1–3 предложения (≤ ~400 символов); skill — тело без
  жёсткого лимита, но каждый раздел должен быть тем, что реально грузится
  каждый вызов (без reference-каскада — выносить в supporting files).

## 6. Анти-паттерны из наших файлов

Прочитаны: `templates/agents/plan-griller.md`, `templates/agents/planner.md`,
`templates/skills/feature-flow/SKILL.md`.

1. **`plan-griller.md` — разросшийся description.** Frontmatter description
   занимает 5 предложений и несёт критичную операционную информацию («This
   is a one-shot report: the agent has no channel to the developer... the
   MAIN SESSION conducts the dialogue») — эта фраза дублирует первый абзац
   тела («You have no channel to the developer - you get one prompt and
   return one report»). По п.1 чеклиста: описание должно быть триггером
   («when to use»), не документацией поведения; критичная часть уже и так
   есть в теле — description можно сжать до 1–2 предложений.
2. **`plan-griller.md` / `planner.md` / `feature-flow/SKILL.md` — ADR-теги
   в тексте промпта.** Найдено множественные упоминания `ADR-0007`,
   `ADR-0009`, `ADR-0010`, `ADR-0011`, `ADR-0012`, `ADR-0013`, `ADR-0015`,
   `ADR-0016`, `ADR-0017`, `ADR-0018`, `ADR-0021` прямо в теле правил
   (например planner.md п.4–9, feature-flow разделы 1–4b). По ADR-0022 п.2
   это прямое нарушение принятого решения — правило должно остаться
   фразой без номера, номер уходит в grounding-таблицу WORKFLOW.md.
3. **`feature-flow/SKILL.md` — дублирование store/graphify процедуры.**
   Раздел 1 полностью повторяет последовательность `graphify explain/query/
   path`, а также команды `openspec store list -> openspec list --specs
   --store ... -> openspec show ... --store ...` — те же команды в том же
   порядке встречаются в planner.md (раздел «Reading store contracts») и,
   по плану, в incident-flow/AGENTS.md. По ADR-0022 п.3/дрейфу из
   PLAN_TEXTS.md — канон должен остаться в одном месте (AGENTS.md по плану
   волны 3), остальным — ссылка.
4. **`planner.md` — CLI-шпаргалка дублирует openspec-propose skill.**
   Блок ```bash openspec new change...``` с примечаниями «Notes that cost
   time when missed» повторяет процедуру, которая, по замыслу самого файла,
   должна жить в `.claude/skills/openspec-propose/SKILL.md» («authoritative
   procedure — read it if present»). Держать полную копию «на случай если
   файла нет» — обоснованный fallback, но сверка актуальности (openspec
   версия) должна идти перед любым сокращением (сам план волны 2 это уже
   предусматривает).
5. **`feature-flow/SKILL.md` — смешение канона и процедуры без языковой
   пометки.** Вопросы разработчику/автору тикета в разделе 1 описаны как
   «Post as a ticket comment» на английском, при том что ADR-0022 п.4
   требует, чтобы сам вопрос разработчику был на русском (только
   форматы/теги — английские). Файл как написан не различает «что писать
   агенту» (английский, ок) от «что агент выведет человеку» (должно быть
   по-русски) — в тексте нет явного напоминания об этом различии, что и
   стало пунктом плана волны 2 для test-author/executor.

## Источники, использованные в этом документе

- https://code.claude.com/docs/en/sub-agents — формат `.claude/agents/*.md`,
  frontmatter, best practices, официальные примеры (code-reviewer,
  debugger, data-scientist).
- https://code.claude.com/docs/en/skills — формат `SKILL.md`, frontmatter
  (`description`, `when_to_use`), skill listing budget (1536 симв.,
  1% контекста), types of skill content, supporting files.
- https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-4-best-practices —
  General principles (be clear and direct, add context, use examples,
  give Claude a role, structure with XML), Output and formatting
  (control the format of responses).
