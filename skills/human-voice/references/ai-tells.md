# AI tells: full catalogue (EN + RU)

Compiled from Wikipedia's ["Signs of AI writing"](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing) (WikiProject AI Cleanup), [blader/humanizer](https://github.com/blader/humanizer) (MIT), [gregorymm/humanize-text](https://github.com/gregorymm/humanize-text), and [Pangram's measured data](https://www.pangram.com/signs-of-ai-writing). Patterns are grouped strongest first: Section A-D patterns justify an edit on one sighting; "weak alone" patterns need company from other tells in the same passage.

## Measured frequency (Pangram, per 10,000 words)

| Signal | Human | AI | Multiplier |
|---|---|---|---|
| Markdown formatting in plain text | 8 | 90 | 12× |
| AI phrases (delve, tapestry, crucial...) | 3 | 30 | 12× |
| Em dashes | 2 | 17 | 10× |
| Bullet lists in plain text | 3 | 28 | 9× |
| Triads (ideas in threes) | 5 | 19 | 4× |
| "Not just X but Y" | 1 | 3 | 3× |
| Unusual Unicode (≈, →, ⚡ in plain text) | 28 | 71 | 3× |
| AI-style headers ("Certainly! Here's...") | 1 | 2 | 2× |
| Emoji in plain text | 0.1 | 0.2 | 2× |

No single tell is proof on its own; the multiplier only means the habit is far more common in AI text. Act on clusters.

## A. Staging instead of stating

### A1. Not X but Y
Watch for: "not just X, but Y", "it's not X, it's Y", "X, not Y"; Russian: «это не просто X, это Y», «не только..., но и...», «это не про X, а про Y».
The negative half names something no one claimed. State the point directly.
- Before: "It's not just about the beat; it's part of the aggression and atmosphere."
- After: "The heavy beat adds to the aggressive tone."
- Before: «Это не просто редактор — это подход к работе с текстом.»
- After: «Редактор меняет сам подход к работе с текстом.»
Keep a contrast only when the reader actually holds the belief being corrected, or when both halves carry information.

### A2. One-line closers and dramatic fragments
A one-sentence paragraph that restates the paragraph before it: "That is the real win.", "Read that again.", «И в этом вся суть.», «Запомните это.». Also a sentence after an example that names what it showed ("This shows the importance of..."), rows of fragments ("No aesthetic prior. No nostalgia."), ALL CAPS or period-separated words (every. single. day.).
Cut a closer that repeats; keep one that adds a fact or consequence. Merge fragment rows into a sentence with a specific claim.

### A3. Sayings that sound deep
"the real question is", "at its core", "what really matters", "X is the Y of Z", "X is not a tool but a mirror"; «на самом деле вопрос в другом», «в основе всего лежит».
Replace the saying with the specific claim.

### A4. Staged run-up before the point
"Let's dive in", "here's what you need to know", "Let's be honest", "Here's the thing"; «давайте разберёмся», «давайте посмотрим на факты», «сразу к делу, но сначала», «стоит отметить», «важно понимать».
Remove the run-up, not just its tone. (Discourse markers like «кстати» or "honestly" inside a casual sentence are ordinary; the tell is the standalone opener before a routine claim.)

### A5. Arguing with no one
"This isn't about", "I'm not saying", "Don't get me wrong", "Some might say... but"; «я не утверждаю, что», «не стоит думать, будто», «вопреки распространённому мнению». The text answers an objection nobody made. Remove the defense; if it holds a real claim, state the claim.

## B. Rhythm by rule

### B6. Forced triads
Ideas arrive in threes to sound complete: "innovation, inspiration, and insights", three parallel examples, three facts followed by a lesson; «скорость, качество и удобство». Check each item adds a distinct idea; merge, develop the strongest, or vary the structure. Keep three real items when the meaning needs three.

### B7. Repeated sentence openings
Several sentences in a row starting with the same subject. Merge, change the subject, or begin with the action. (Writers repeat openings on purpose for rhythm - "She came. She saw. She conquered." - that stays.)

### B8. Dashes as the universal connector
Default to zero em dashes (—) and spaced hyphens ( - ) used as dashes in informal text; replace each with a period, comma, colon, or parentheses. Many human writers do use dashes, so one dash is weak alone; a text full of them is not. In Russian, тире is a legitimate punctuation mark (see typography reference) - the tell is dash-plus-colon density, not the character itself. Leave dashes inside code, paths, and ranges (1941–1945) alone.
- Before: "The new policy — announced without warning — affects thousands of workers."
- After: "The new policy, announced without warning, affects thousands of workers."

### B9. Stacked qualifiers
"to be fair", "could potentially", "might arguably", "in some cases it may"; «в определённой степени», «в некоторых случаях может». Repeated editing piles qualifiers until every claim sounds uncertain. Weak alone.

### B10. Hyphenated pairs everywhere (EN)
"high-quality, well-known, long-term" after the noun they describe. Keep the hyphen before a noun ("a high-quality report"), drop it after ("the report is high quality"). Weak alone.

### B11. Passive voice and missing subjects
"No configuration file needed." → "You do not need a configuration file." Weak alone.

## C. Inflation and borrowed authority

### C12. AI vocabulary
Words that are tells wherever they appear: additionally (sentence-opener), boast (meaning "has"), bolstered, crucial, delve, endure/enduring, enhance, garner, highlight (verb), interplay, intricate, landscape (abstract), meticulous, pivotal, showcase, tapestry (abstract), testament, underscore (verb), vibrant; plus UX/marketing: seamless, empower, unlock, elevate, streamline, leverage, cutting-edge, game-changing, best-in-class.
Swap table: delve → look at; tapestry/landscape → mix, range, world; pivotal → important; testament → proof; seamless → smooth; empower → let, help; leverage → use; unlock → open, start using; meticulously → carefully.
Russian stock: «в современном мире», «на сегодняшний день», «в эпоху цифровых технологий», «играет важную/ключевую роль», «имеет огромное значение», «уникальный», «инновационный», «эффективный и надёжный», «является» (as default verb), «данный» (for «этот»), «осуществлять» (for plain verbs).
Do not swap one AI word for another; if the sentence is filler, delete it.

### C13. Inflated significance
"stands as a testament", "a pivotal moment", "plays a key role", "underscores its importance", "setting the stage for", "the future looks bright"; «знаковый этап», «поворотный момент», «открыть новые горизонты», «внести неоценимый вклад». Keep the fact, drop the significance. End on the last concrete fact; cut send-off paragraphs entirely.

### C14. Vague connection or association
"associated with", "linked to", "in connection with"; «связан с», «имеет отношение к». Name the relationship the source gives, or keep the vague wording rather than inventing a role.

### C15. Shallow -ing riders
"...highlighting", "...ensuring", "...reflecting", "...showcasing"; «...что подчёркивает», «...что свидетельствует о». A participial phrase bolted onto a simple fact to make it sound deeper. Keep the fact; keep the rider only when the source supports it.

### C16. Sales language
"rich (figurative)", "profound", "nestled", "renowned", "breathtaking", "must-visit"; «уникальная атмосфера», «непревзойдённый», «знаменитый», «жемчужина». State what the thing is.

### C17. Borrowed authority
"experts argue", "industry reports", "some critics"; «эксперты считают», «по мнению специалистов», «исследования показывают». Name the source or cut. "Trusted by 2,400 teams" beats "trusted by thousands of professionals worldwide."

### C18. Avoiding is, are, and has
"serves as", "stands as", "features", "boasts"; «является», «представляет собой», «обладает», «имеет в своём составе». Use "is", "are", "has"; в русском часто достаточно тире или нулевой связки: «Панель — рабочий стол аналитика», «В составе четыре комнаты».

## D. Formatting by rule

### D19. Bold as decoration
Bolded words without a reason; vertical lists where every item has a bold label and a colon. Remove the bold; turn labeled lists into prose when the labels carry no information. (Bold in a plain chat message or plain-text email is an AI tell at 43× per Pangram - humans typing into a text box rarely do it.)

### D20. Decorative headings and emoji
Title Case in Every Heading, emojis or arrows as bullets (🚀 💡 →), a horizontal rule between every section. Use sentence case ("How the six options compare", «Как работает установщик»), remove decoration. Emoji in casual chat is human; emoji at the start of document sections is not.

### D21. Curly quotes in plain text
“curly quotes” in chat messages, plain-text email, or code contexts where the writer uses straight ones. In Russian text «ёлочки» are the standard for formal prose - match the medium (see typography reference). Weak alone.

## E. Leftovers from the chat and the draft (delete outright)

### E22. Chatbot residue
"I hope this helps", "Of course!", "Certainly!", "Great question!", "You're absolutely right", "Would you like...", "Let me know if..."; «Отличный вопрос!», «Надеюсь, эта информация была вам полезна», «Если у вас есть ещё вопросы, обращайтесь», «С радостью помогу», «Конечно! Вот что нужно знать».
Remove the wrapper and keep the content.

### E23. Knowledge-limit disclaimers and guesses
"as of my last update", "while specific details are limited", "not widely documented", "it is believed that"; «на момент моего обучения», «точных данных нет, однако». State what the source does not show, or remove the sentence - do not fill the gap with a plausible guess.

### E24. A heading repeated in the first sentence
"## Performance" followed by "Speed matters." Remove the repeated sentence.

### E25. Writing about the document instead of its subject
"was added to replace", "this section is organized by", "the table below compares". Mention a previous version only in change logs and release notes.

### E26. Re-explaining what the reader knows (in replies)
A reply that restates the problem, walks through the diagnosis, and buries the decision in the last line. Lead with the decision; keep only the reasoning that would change whether the reader agrees.

## F. Russian-specific habits

- **Идеальная грамматика при нулевом стиле.** Человек в переписке опечатывается и пишет небрежно; текст без единой ошибки и запятой, стоящей идеально, в неформальном жанре сам по себе маркер.
- **Равномерный ритм.** Абзацы одной длины, предложения одной конструкции от начала до конца; живой текст дышит.
- **Тире и двоеточие на каждом шагу.** ChatGPT ставит «—» и «:» при любом удобном случае; человек в чате пишет через дефис, запятую или новую строку.
- **Парные конструкции.** «не только..., но и...», «как..., так и...», «это не про X, а про Y» - по три на страницу.
- **Канцелярит вместо глагола.** «осуществляет поддержку» вместо «поддерживает», «производит подключение» вместо «подключает».
- **Пустые выводы.** «В заключение стоит отметить, что...», «Таким образом, данная технология играет важную роль» - абзац, который ничего не добавляет. Удалить.
- **Список из трёх пунктов после каждого раздела.** И «Итоги и перспективы» с оптимистичной концовкой в любом тексте.

## When not to act

A person can make any one of these choices on purpose. Leave a watched phrase alone inside a quotation, a title, a proper name, or a passage that discusses the phrase rather than uses it. Text written before November 30, 2022 is not AI-written. People judging by feel do little better than chance, so act on clusters, not single sightings. Keep the details that carry a writer's voice: specific unusual details, mixed feelings, dated references, genuine asides.
