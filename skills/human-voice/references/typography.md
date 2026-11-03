# Punctuation and typography: match the register

The point is not "perfect typography". The point is punctuation a real person would produce in this medium. Two failure modes both look machine-made: a chat message full of em dashes and curly quotes, and a formal document that cannot tell a hyphen from a dash. Compiled from [А. Лебедев, Ководство §97 «Тире, минус и дефис»](https://www.artlebedev.ru/kovodstvo/sections/97/) and register observations from the AI-tells catalogue.

## The register rule (before any fix)

1. **Informal text** - chat messages, comments, social posts, quick emails: humans type hyphens, not dashes. Replace dashes with hyphens, commas, periods, or line breaks; drop curly quotes to straight ones; drop decorative markdown (**bold**, ## headings) entirely - in plain text boxes it appears 12-43× more often in AI text than human text.
2. **Formal text** - documents, READMEs, articles, books: follow the language's rules below. Here the AI tell is not the dash character but its density: an em dash and a colon in every second sentence.

## English

- **Hyphen (-)** joins compound words and modifiers before a noun: well-known author, third-party library, long-term plan. After the noun, no hyphen: "the plan is long term".
- **En dash (–)** marks ranges and contrasts: 1941–1945, pages 10–20, the London–Paris route.
- **Em dash (—)** marks a break or emphasis. Humans use it sparingly (Pangram: 2 per 10k words vs AI's 17). In rewrites, default to zero: use a comma, colon, parentheses, or a new sentence.
- **Quotes**: straight (") in code and plain text; typographic (" ") in print-grade prose - but stay consistent within a document, mixing is itself a signal.
- **Ellipsis** is the three-dot character or three periods, not four: "..." or "…", spaced per style guide.
- **No double spaces** between sentences; one space after terminal punctuation.

## Russian

В русской типографике три разные горизонтальные черты (Ководство §97):

- **Дефис (-)** - внутри слов: частицы (кто-либо, где-то), префиксы (во-первых, по-русски), сокращения (физ-ра), сложносоставные слова (ковер-самолет, бизнес-ланч, интернет-кафе), знак переноса.
- **Минус (−)** - только в математических выражениях и отрицательных числах. Не путать с дефисом: это разные знаки.
- **Короткое тире (–)** - числовые диапазоны и интервалы: 1941–1945, 10–20 страниц.
- **Тире (—)** - пунктуационный знак: на месте пропущенного члена предложения («Я — страсть как!»), между подлежащим и сказуемым («Дважды два — четыре»), для выделения прямой речи («— Да, согласна»), для обозначения пауз. Набирается с пробелами по бокам; неразрывный пробел ставится перед тире, чтобы знак не уезжал на новую строку.
- **Кавычки** - «ёлочки»; внутри цитируемого - „лапки". В чатах и заметках человек обычно пишет "прямые" - это нормально для неформального регистра.
- **Многоточие** - знак «…» или три точки, без пробела внутри; после него пробел.
- **Ё** - факультативна, но либо замените все ё на е, либо поставьте все: выборка - тоже маркер.
- **Пробелы** - один после запятой и точки; неразрывный пробел перед «», в числах (10 000), после № и §; никакой двойной пробел между словами.

### Что выдавает нейросеть в русском тексте

- «—» в неформальном сообщении там, где человек поставил бы дефис или запятую (главная жалоба пользователей: «длинные тире вместо коротких -»).
- Двоеточие в каждом втором предложении («Вот что важно:», «Причина простая:»).
- Безупречная пунктуация в жанре, где люди пишут небрежно.
- Кавычки-ёлочки и длинные тире в тексте, который претендует на «написано на коленке».

### Быстрые замены при правке

| Было (ИИ) | Стало |
|---|---|
| «Это важно — и вот почему.» | «Это важно, и вот почему.» |
| «Причина простая: всё завязано на кэш.» | «Причина простая - всё завязано на кэш.» (неформальный) / «Причина в кэше.» |
| «проект — стартап — корпорация» | «проект, стартап, корпорация» |
| "текст" (в русской формальной прозе) | «текст» |
| 1941-1945 | 1941–1945 (диапазон) |
| 5-7 дней (диапазон в формальном тексте) | 5–7 дней |
| «10-15%» в чате | «10-15%» (оставить, дефис норм) |

For the density problem the fix is structural, not character-level: replace dash-joined clauses with separate sentences, and delete colons that introduce nothing that needs introducing.
