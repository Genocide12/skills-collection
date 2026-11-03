---
name: media
description: Медиа и графика: генерация и редактирование изображений, поиск картинок, видео (монтаж, Manim-анимация, Remotion), анализ изображений и видео (VLM), речь (ASR-распознавание, TTS-синтез). Загружай для любой задачи с картинками, видео и звуком.
---
# Медиа и графика

> Дистиллят из 13 исходных скиллов. Полные тексты — в репо/платформе: skills/<имя-скилла>/.

## Когда применять
- «сгенерируй / отредактируй картинку», «найди / подбери изображение», «сделай иконку для iOS» → раздел 1
- «что на этом изображении», «опиши/проанализируй видео», OCR, сравнение картинок → раздел 2
- «распознай аудио/транскрибируй», «озвучь текст», голосовой ассистент → раздел 3
- «смонтируй видео», «нарежь запись», анимационный explainer, титры/оверлеи, таймлайн для NLE → раздел 4
- Blender-персонаж «кривой/зеркальный/проскальзывает», проверка рига и ретаргетинга → раздел 5

## 1. Генерация и правка изображений (image-generation, image-edit, image-search, ios-icon-gen)

### Железные правила
- z-ai-web-dev-sdk — только в backend-коде, никогда в клиентском.
- Генерация: `zai.images.generations.create({prompt, size})` → `response.data[0].base64` (base64, декодировать перед записью). Правка: `zai.images.generations.edit({prompt, images: [{url}], size, model?})` — `images` обязательно массив объектов с `url`, не строка; url — либо ссылка, либо data-URL (`data:image/jpeg;base64,...`).
- Размер только из списка: `1024x1024`, `768x1344`, `864x1152`, `1344x768`, `1152x864`, `1440x720`, `720x1440`.
- Промпт генерации: субъект + стиль + детали + качество («high quality», «detailed»). Слабые промпты: «headphones», «logo».
- Промпт правки: указывать, ЧТО изменить И ЧТО сохранить («keep … unchanged, maintain overall composition»). Слабые: «make it better», «change something».
- image-search: один вызов = один концепт; для двух несвязанных сюжетов — два вызова; запрос — описательное предложение, не набор ключевых слов; язык запроса определяет язык подписей.
- Показывать пользователю OSS-ссылку `results[].original_url` (гарантированно доступную), а не URL сайта-источника.
- Иконки: перед генерацией проверить стиль существующих иконок проекта (размер, цвет, вес); генерировать сразу в asset catalog через `--output ./Assets.xcassets/icons`.

### Команды и параметры (дословно из исходников)
```bash
# Генерация (CLI)
z-ai image --prompt "A beautiful landscape" --output "./image.png"   # = -p / -o
z-ai image -p "A sunset" -o "./sunset.png" -s 1344x768

# Правка (CLI)
z-ai image-edit -p "Change the background to sunset colors" -i "./photo.png" -o "./edited.png" -s 1344x768
# -p промпт правки (обяз.), -i URL или локальный файл (обяз.), -o PNG-выход (обяз.), -s размер (по умолч. 1024x1024)

# Поиск картинок (CLI)
z-ai image-search -q "a cute orange tabby kitten playing with yarn" --count 5
z-ai image-search -q "vintage red sports car on a mountain road" --count 5 --gl us --no-rank
z-ai image-search -q "中国传统水墨山水画" --count 5 -o results.json
# Флаги: -q (обяз.), --count 1–20 (по умолч. 5), --gl cn|us|jp|kr (по умолч. cn), --no-rank (без подписей, быстрее), -o файл JSON
```
Эффективные паттерны промпта правки (из image-edit):
- `[Subject description], replace background with [new background], maintain subject lighting and pose`
- `[Current description] transformed into [style name] style, preserve composition and key elements`
- `[Scene description], replace [element A] with [element B], keep everything else identical`
- `[Image description], change color scheme to [colors], maintain contrast and composition`
Выбор размера под задачу: генерация — hero-banner `1440x720`, blog-header `1344x768`, social-square/product/thumbnail `1024x1024`, portrait `768x1344`, landscape `1344x768`, mobile-banner `720x1440`; правка — background-change `1440x720`, style-transfer/color-adjustment `1024x1024`, element-replacement `1344x768`, composition-change `1152x864`, portrait-edit `768x1344`, landscape-edit `1344x768`.
Ответ поиска: проверять `success` до чтения `results`; поля `original_url` (OSS, стабильно), `caption` (только при ranked), `source`, `original_width`/`original_height` («NNNpx»). Полный вызов может занимать 90+ секунд — таймаут клиента минимум 120 с.
```bash
# Иконки: Iconify API (275k+) и SF Symbols (5000+, только macOS)
$SKILL_DIR/scripts/iconify_gen.sh search "receipt"          # поиск по всем коллекциям
$SKILL_DIR/scripts/iconify_gen.sh search "business card" --prefix mdi
$SKILL_DIR/scripts/iconify_gen.sh collections
$SKILL_DIR/scripts/iconify_gen.sh preview mdi:receipt-text-outline
$SKILL_DIR/scripts/iconify_gen.sh mdi:receipt-text-outline myIcon --color 007AFF --output ./Assets.xcassets/icons
swift $SKILL_DIR/scripts/generate_icons.swift person.crop.rectangle myIcon --color 007AFF --weight regular --output ./Assets.xcassets/icons
# Опции обоих: --size <pt> (по умолч. 68), --color <hex> (по умолч. 8E8E93); у swift ещё --weight (по умолч. thin)
```
Выход — готовый imageset: `<name>.imageset/` c `Contents.json` и PNG 1x/2x/3x (68/136/204 px по умолчанию). Коллекции Iconify: `mdi` (7400+), `ph` (9000+, 6 весов), `solar`, `tabler`, `lucide`, `ri`, `carbon`, `heroicons`; каталог — https://icon-sets.iconify.design/.

### Типовые ошибки
- SDK в клиентском коде; строка вместо `images: [{url}]` в edit.
- Недопустимый size; повреждённый файл из-за пропущенного декодирования base64.
- Размытый промпт правки без указания сохраняемых элементов → непредсказуемый результат; потеря качества — брать больший размер.
- Поиск: сцепка несвязанных ключевых слов в один запрос; пустой `results` при `success:true` — расширить запрос, поднять `--count`, сменить `--gl`.
- Иконки: сгенерировать без сверки с палитрой/размерами проекта; закоммитить без визуальной проверки @2x PNG.

## 2. Анализ изображений и видео (VLM, video-understand) — как вызывать, что передавать

### Железные правила
- Один и тот же вызов: `zai.chat.completions.createVision({messages, thinking})`; thinking — `{type: 'disabled'}` для простых описаний, `{type: 'enabled'}` для сложного временно́го анализа (видео, подсчёт, события).
- Типы контента в сообщении: `image_url` (PNG/JPEG/GIF/WebP/BMP), `video_url` (MP4/AVI/MOV/WebM/MKV/FLV), `file_url` (PDF/DOCX/TXT); можно совмещать несколько в одном сообщении.
- Рекомендуемый способ — base64 data-URL вместо URL (надёжнее); локальный файл: `fs.readFileSync` → `toString('base64')` → `data:<mime>;base64,...`.
- В CLI видео передаётся тем же флагом `--image` (несмотря на имя).
- Для локальных видео: заливать на CDN и передавать URL; короткие — ключевые кадры как изображения; длинные — чанки/выборка интервалов.
- В промптах для видео задавать временные ориентиры («beginning», «throughout», «at the end») и требуемую структуру (хронология, таймлайн, категории).

### Команды и параметры (дословно из исходников)
```bash
z-ai vision -p "Describe this image" -i "https://example.com/image.png"
z-ai vision -p "What objects are in this photo?" -i "./photo.jpg" -o description.json
z-ai vision -p "Compare these two images" -i "./photo1.jpg" -i "./photo2.jpg" -o comparison.json
z-ai vision -p "Count the number of people..." -i "./crowd.jpg" --thinking -o analysis.json
z-ai vision -p "Describe this image in detail" -i "./photo.jpg" --stream
# Видео — тем же CLI
z-ai vision -p "Summarize what happens in this video" --image "https://example.com/video.mp4"
z-ai vision -p "Analyze this video and identify: 1) Main events, 2) People and their actions, 3) Timeline" -i "./event.mp4" --thinking
# -p (обяз.), -i URL/путь, повторяемый; --thinking по умолч. выключен; -o JSON; --stream
```
SDK-скелет типов контента (из VLM):
```typescript
{ type: 'image_url', image_url: { url: imageUrl } }    // статичные изображения
{ type: 'video_url', video_url: { url: videoUrl } }    // видео (MP4, AVI, MOV…)
{ type: 'file_url',  file_url:  { url: fileUrl } }     // документы (PDF, DOCX, TXT…)
```
Готовые постановки запросов: OCR — «Extract all text from this image. Preserve the layout and formatting as much as possible»; классификация — субъект/объекты/сцена/теги в JSON; для видео — summary, таймлайн событий, детекция действий, классификация, оценка качества, модерация.
Ответ: `response.choices[0]?.message?.content`. SDK-скелет для видео: `{type:'text'...}, {type:'video_url', video_url:{url}}`. МультиTurn: сохранять assistant-ответы в `messages` и продолжать диалог.

### Типовые ошибки
- `response.audio`/несуществующие поля — читать именно `choices[0].message.content`.
- URL недоступен или неверный MIME → «image not loading»; проверить доступность и формат.
- Медленно/неточно на видео: длинное видео целиком вместо клипов; thinking выключен там, где нужна временная логика.
- Массовая обработка без задержек → rate limiting (в примерах пауза 1000 мс между видео).

## 3. Речь: ASR и TTS — команды и параметры

### Железные правила
- SDK (`zai.audio.*`) — только backend. ASR: `zai.audio.asr.create({file_base64})` → `response.text`; аудио читается в base64.
- TTS: `zai.audio.tts.create({input, voice, speed, volume, response_format, stream})` возвращает стандартный **Response** — брать `await response.arrayBuffer()` и `Buffer.from(new Uint8Array(arrayBuffer))`. `response.audio` не существует.
- Ограничения TTS: `input` ≤ 1024 символов на запрос (длинный текст резать на чанки по предложениям, ~1000 симв.); speed 0.5–2.0 (вне диапазона — ошибка API); volume — строго >0 и ≤10 (по умолч. 1.0); при `stream:true` только `pcm`; без стриминга — `wav`/`pcm`/`mp3`; частота 24000 Hz.
- Голоса: `tongtong` (温暖亲切), `chuichui` (活泼可爱), `xiaochen` (沉稳专业), `jam` (英音绅士), `kazi` (清晰标准), `douji` (自然流畅), `luodo` (富有感染力); по умолчанию `tongtong`.
- Качество ASR: 16 kHz+, WAV/MP3/M4A, минимум шума, файл < 100 МБ (больше — резать на сегменты); поддерживаются .wav, .mp3, .m4a, .flac, .ogg.

### Команды и параметры (дословно из исходников)
```bash
# ASR
z-ai asr --file ./audio.wav
z-ai asr -f ./recording.mp3 -o transcript.json
z-ai asr --base64 "UklGRiQAAABXQVZFZm10..." -o result.json
z-ai asr -f ./audio.wav --stream
# -f путь (обяз. если нет -b), -b base64 (обяз. если нет -f), -o JSON, --stream

# TTS
z-ai tts --input "Hello, world" --output ./hello.wav     # = -i / -o
z-ai tts -i "Welcome to our service" -o ./welcome.wav --voice tongtong
z-ai tts -i "This is faster speech" -o ./fast.wav --speed 1.5
z-ai tts -i "Hello World" -o ./hello.mp3 --format mp3    # wav | mp3 | pcm
z-ai tts -i "..." -o ./stream.wav --stream               # только pcm при стриминге
# -i (обяз., ≤1024 симв.), -o (обяз.), -v голос (tongtong), -s скорость 0.5–2.0 (1.0), -f формат (wav), --stream
```
Нарезка длинного текста для TTS (из TTS, дословно):
```javascript
function splitTextIntoChunks(text, maxLength = 1000) {
  const chunks = [];
  const sentences = text.match(/[^.!?]+[.!?]+/g) || [text];
  let currentChunk = '';
  for (const sentence of sentences) {
    if ((currentChunk + sentence).length <= maxLength) { currentChunk += sentence; }
    else { if (currentChunk) chunks.push(currentChunk.trim()); currentChunk = sentence; }
  }
  if (currentChunk) chunks.push(currentChunk.trim());
  return chunks;
}
```
Подготовка текста: схлопнуть лишние пробелы, раскрыть частые сокращения (Dr. → Doctor и т.п.) для лучшего произношения.
Постобработка ASR (из исходников): схлопнуть пробелы, капитализировать предложения, при желании убрать слова-паразиты. Переиспользовать экземпляр SDK; кэшировать результаты повторных транскрипций/озвучек.

### Типовые ошибки
- `response.audio is undefined` → нужен `await response.arrayBuffer()`.
- «Input text exceeds maximum length» → чанкование; «Invalid speed/volume» → выйти за 0.5–2.0 / (0,10].
- «Stream format not supported» для WAV/MP3 → стриминг только с pcm.
- Пустая транскрипция → проверить качество аудио и что `response.text` не пуст; SDK в клиентском коде.

## 4. Видео-продакшн (video-editing, tasteforge-video, remotion-video-creation, manim-video)

### Железные правила
- Пайплайн монтажа (каждый слой со своей задачей, не пропускать): Screen Studio/raw footage → Claude/Codex (структура, EDL) → FFmpeg (детерминированные нарезки) → Remotion (оверлеи/моушн) → ElevenLabs/fal.ai (только недостающие ассеты) → Descript/CapCut (финальный вкус).
- «Edit, don't generate»: ценность — сжатие и структурирование реальных съёмок, а не генерация видео целиком. Сначала структура (что остаётся/режется/порядок), потом стиль.
- Перед живыми правками в редакторе/DAW — сохранить версионный чекпоинт проекта и проверить, что файл существует; после правок — ещё один. API-readback доказывает состояние в памяти, а не то, что оно сохранено.
- Remotion: если делается больше одного раза — делать переиспользуемый компонент; рендер `npx remotion render`.
- Manim: тезис визуализации одним предложением → 3–6 сцен, каждая что-то доказывает → outline до кода → минимальный рендер сначала, полировку после; прогрессивное раскрытие вместо перегруженных диаграмм; движение объясняет смену состояния.
- TasteForge: локальные операции офлайн и детерминированы; провайдерская генерация обязана fail-closed — `provider_calls:0` (целое число, не `false`), `provider_execution:false`, `dry_run:true`, `submit:false`, `provider_call_mode:"disabled"`; dry-run никогда не называть «сгенерировано моделью». Рецепты/манифесты жанров не смешивать (Flash Ethereal / 3D Cyber Glitch / Fluid Sketch — раздельно).
- Таймлайн-экспорт: `timeline_events` обернуть в `{"clips": [...]}` и передать тот же `--fps`, что при `apply`; сверить количество событий, суммарные кадры, уникальные источники и привязку медиа; в NLE перечитать каждые start/end/duration — отсутствие/сдвиг/обрезка эффектов = брак.

### Команды и параметры (дословно из исходников)
```bash
# FFmpeg — нарезка, склейка, прокси, аудио
ffmpeg -i raw.mp4 -ss 00:12:30 -to 00:15:45 -c copy segment_01.mp4
while IFS=, read -r start end label; do ffmpeg -i raw.mp4 -ss "$start" -to "$end" -c copy "segments/${label}.mp4"; done < cuts.txt
for f in segments/*.mp4; do echo "file '$f'"; done > concat.txt
ffmpeg -f concat -safe 0 -i concat.txt -c copy assembled.mp4
ffmpeg -i raw.mp4 -vf "scale=960:-2" -c:v libx264 -preset ultrafast -crf 28 proxy.mp4
ffmpeg -i raw.mp4 -vn -acodec pcm_s16le -ar 16000 audio.wav
ffmpeg -i segment.mp4 -af loudnorm=I=-16:TP=-1.5:LRA=11 -c:v copy normalized.mp4

# Детекция сцен и тишины
ffmpeg -i input.mp4 -vf "select='gt(scene,0.3)',showinfo" -vsync vfr -f null - 2>&1 | grep showinfo
ffmpeg -i input.mp4 -af silencedetect=noise=-30dB:d=2 -f null - 2>&1 | grep silence

# Рефрейм под платформы
ffmpeg -i input.mp4 -vf "crop=ih*9/16:ih,scale=1080:1920" vertical.mp4   # 16:9 → 9:16
ffmpeg -i input.mp4 -vf "crop=ih:ih,scale=1080:1080" square.mp4          # 16:9 → 1:1
# YouTube 1920x1080 (16:9); TikTok/Reels 1080x1920 (9:16); Instagram Feed 1080x1080 (1:1); X 1280x720 или 720x720

# Remotion
npx remotion render src/index.ts VlogComposition output.mp4

# Manim — смоук-тест низкого качества
manim -ql assets/network_graph_scene.py NetworkGraphExplainer

# TasteForge (движок ecc-tasteforge)
python3 -m tasteforge validate stylepacks/flashethereal
python3 -m tasteforge interview --answers answers.json --genre flashethereal --out profile.json
python3 -m tasteforge distill --profile profile.json --pack stylepacks/flashethereal --out spec.json
python3 -m tasteforge apply --pack stylepacks/flashethereal --media media.json --duration 20 --out report.json
python3 -m tasteforge export --events events.json --out-dir out --title flashethereal-cut
python3 -m tasteforge provenance
python3 -m tasteforge multimodal --config workflow.json --out-dir out/multimodal
# Без повторов клипов: apply --no-repeat --fps (строгий режим: каждый источник ≤1 раза; если флагов нет — сообщить о пробеле, не молчать)

# Озвучка в пайплайне (ElevenLabs, из video-editing)
requests.post(f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}",
  headers={"xi-api-key": os.environ["ELEVENLABS_API_KEY"], "Content-Type": "application/json"},
  json={"text": "...", "model_id": "eleven_turbo_v2_5",
        "voice_settings": {"stability": 0.5, "similarity_boost": 0.75}})
```
Мини-пример Remotion-композиции (из video-editing):
```tsx
import { AbsoluteFill, Sequence, Video, useCurrentFrame } from "remotion";
export const VlogComposition: React.FC = () => (
  <AbsoluteFill>
    <Sequence from={0} durationInFrames={300}><Video src="/segments/intro.mp4" /></Sequence>
    <Sequence from={30} durationInFrames={90}>
      <AbsoluteFill style={{ justifyContent: "center", alignItems: "center" }}>
        <h1 style={{ fontSize: 72, color: "white", textShadow: "2px 2px 8px rgba(0,0,0,0.8)" }}>The AI Editing Stack</h1>
      </AbsoluteFill>
    </Sequence>
    <Sequence from={300} durationInFrames={450}><Video src="/segments/demo.mp4" /></Sequence>
  </AbsoluteFill>
);
```
Промпт слоя организации (Layer 2): «Here's the transcript of a 4-hour recording. Identify the 8 strongest segments for a 24-minute vlog. Give me FFmpeg cut commands for each segment.» Ремоушн-сценарии: оверлеи, дата-виз, моушн-графика, переиспользуемые сцены, демо продукта.
Remotion-композиция: `AbsoluteFill` + `Sequence from/durationInFrames` + `Video src` + `useCurrentFrame()` для титров и оверлеев. У Remotion 29 правил-файлов (rules/): 3d, animations, assets, audio, calculate-metadata, captions (display/import-srt/transcribe), charts, compositions, extract-frames, fonts, gifs, lottie, measuring-dom-nodes/text, sequencing, tailwind, text-animations, timing, transitions, trimming, videos, media-метрики через Mediabunny (can-decode, get-video/audio-duration, get-video-dimensions). Manim-выход: короткий 16:9 MP4 + один читаемый в соцсетях thumbnail + сториборд и план сцен; вертикаль — только по запросу.

### Типовые ошибки
- Один инструмент «на всё»; генерация вместо монтажа; стиль до структуры.
- MIDI-аудио: успешное создание клипов может дать тишину — сверять питчи с маппингом ноты и прослушивать результат; реконструированный DAW-проект проверять нативной загрузкой/сохранением и прослушкой экспорта.
- Экспорт TasteForge: чужой `--fps` реконформирует план; booleans как числа в timeline/probe-данных невалидны (всё конечные real); источник изменился во время пробы/хэширования → fail-closed, а не чинить ресипт удалением evidence.
- Manim: сразу высокое качество до стабильной композиции/тайминга; перегруженные диаграммы; «постоянно движущийся» экран без смысла.

## 5. 3D и анимация состояний (blender-motion-state-inspection)

### Железные правила
- Не судить об анимированных 3D-ассетах по скриншотам: они скрывают конвенции осей, имена костей, масштаб, локальные трансформы, родительские связи и контакт по кадрам. Сначала структурированные факты из Blender, потом скриншот как подтверждение.
- Порядок работы: инвентаризация сцены (мешы, арматуры, хелперы, bbox) → скелет (кости, иерархии, семантические имена hips/spine/neck/…) → оси forward/up/side по совокупности (таз, позвоночник, плечи, голова, стопы + корневое движение; glTF Y-up vs Blender Z-up) → выборка кадров (первый, средний, контактные, воздушные, экстремальные) → целостность модели до обвинения ретаргетинга → диагноз контактов → отчёт.
- Отчёт: факты до мнений — номера кадров, имена объектов/костей, мировые координаты, пороги; отдельно подтверждённые сбои и визуальные подозрения; скриншоты только после того, как факты объяснили, что искать.
- Пороги: проникновение в пол >1–2 см видно; скачок масштаба >5% — подозрение на риг/констрейнт/наследование; разворот root heading >30° за кадр — подозрителен; смена порядка левых/правых лодыжек в воздухе — риск crossover.
- Чинить только то, что просили: не менять пропорции тела ради позы (если это не явный mesh repair), не запекать чистую базовую позу до её записи, не удалять хелпер-объекты до записи, почему они не часть персонажа.

### Команды и параметры (дословно из исходников)
```bash
blender --background scene.blend --python collect_motion_state.py
```
`bpy` недоступен в обычном системном Python — скрипт запускается через сам Blender. Если есть экспортёр состояния — предпочесть JSON с мешами, арматурами, позными костями, материалами, контактами, bbox и выборкой кадров анимации. Формат отчёта: Scene Inventory / Orientation (world up, forward, root heading, риск зеркальности) / Baseline Integrity (чистые и анимированные bounds, сохранность материалов/skin) / Frame Findings (таблица кадр–факт–свидетельство) / Verdict (pass/fail, требуемое исправление, готовность к рендеру).

### Типовые ошибки
- Один ракурс камеры как «доказательство» корректной позы; вывод «персонаж смотрит в +Y/-Y/±X» без сверки головы, стоп, торса и корневого движения.
- Обвинение ретаргетинга при сломанном импорте: сферовидные блобы, гигантские прокси-меши, сплющенные тела — сначала вопрос импорта/выделения.
- Редактирование кривых анимации до исправления оси импорта/ретаргетинга (пример из исходников: лицо в −Y, root-движение в +Y → чинить маппинг осей).

## Чек-лист перед сдачей медиа-результата
- SDK-вызовы везде в backend; аудио/изображения переданы в правильном формате (base64/data-URL, допустимые size/форматы).
- Сгенерированный файл существует и не пуст; изображение просмотрено (например, сгенерированный @2x PNG) до коммита; результат edit соответствует и «что изменить», и «что сохранить».
- image-search: `success:true` проверен; пользователю показан OSS `original_url`.
- TTS: текст ≤1024 симв. (или нарезан), speed/volume в диапазоне, формат согласован со стримингом; ASR: `response.text` не пуст, качество аудио проверено.
- Видео: структура до стиля; FFmpeg-команды дают ожидаемые сегменты; перед сдачей сверены счётчики (события, кадры, источники) и прочтены тайминги размещённых эффектов; аудио прослушано на предмет нежелательной тишины; чекпоинты проекта сохранены и проверены.
- Manim/Remotion: смоук-рендер прошёл, thumbnail читается в малом размере, композиция и тайминг стабильны до повышения качества.
- Blender: отчёт разделяет факты и подозрения, содержит кадры/кости/координаты; чистая базовая поза записана до любых правок.
- TasteForge: все fail-closed поля на месте (`provider_calls:0`, `dry_run:true`…), ресипт и манифесты провалидированы после создания; dry-run не выдан за провайдерскую генерацию.

## Карта источников
| Тема | Скиллы |
| --- | --- |
| Генерация/правка изображений | image-generation, image-edit |
| Поиск изображений | image-search |
| Иконки для iOS | ios-icon-gen |
| Анализ изображений | VLM |
| Анализ видео | video-understand |
| Распознавание речи | ASR |
| Синтез речи | TTS |
| Монтаж реальных съёмок | video-editing |
| Стиль-паки, офлайн-планирование, EDL/FCPXML | tasteforge-video |
| Видео в React | remotion-video-creation |
| Manim-анимация | manim-video |
| Blender: проверка рига и анимации | blender-motion-state-inspection |
