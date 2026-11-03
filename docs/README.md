# Сайт коллекции

Лендинг skills-collection: двуязычный, каждая версия — один самодостаточный HTML.

- `index.html` — русская версия (основная)
- `index-en.html` — английская версия; языки переключаются ссылками в шапке

Данные поиска — 427 описаний скиллов из `manifest.json`, вшиты в страницу при сборке
(сборщик: `/home/z/my-project/scripts/build_landing_i18n.py`, шаблоны: `site-build/`).

## Публикация

GitHub Pages: Settings → Pages → Source: `main`, папка `/docs` — русская версия откроется
на корне, английская по `/index-en.html`.
