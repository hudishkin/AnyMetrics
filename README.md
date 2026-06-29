# AnyMetrics | [RU](README_ru.md)

[![Download on the App Store](appstore.png)](https://apps.apple.com/us/app/anymetrics/id1609900961)

**Any HTTP endpoint → a widget on your iPhone home screen.**

AnyMetrics sends requests to REST APIs, JSON services, or web pages and displays the result in a home screen widget. Configure everything in the app — no code required.

iOS 15+ · Free · No ads · Open source · English & Russian

![Preview](preview.png)

## How it works

1. **Set up a request** — URL, HTTP method, headers, timeout
2. **Extract a value** — JSON path, HTML selector, or HTTP status code
3. **Add a widget** — data refreshes on your home screen

## What you can monitor

- Server uptime and API availability
- CI/CD stats from GitHub, GitLab, or Jenkins
- Response times, error rates, deployment status
- Download counts, repo stars, or any endpoint data

## Features

- **Custom HTTP requests** — any method, headers, configurable timeout
- **JSON parsing** — dot-path rules with filters, aggregates, and selectors
- **HTML parsing** — extract text via CSS selectors (`Document.querySelector` syntax)
- **HTTP status checks** — endpoint health at a glance (2xx = OK)
- **Home screen widgets** — compact WidgetKit widgets with live data
- **Value formatting** — currency, length trimming, and more
- **Gallery** — ready-made metrics, one tap to add
- **Import / Export** — share metrics as JSON with your team

## Parsing Rules

### JSON

Navigate through JSON using dot-separated paths.

#### Basic navigation

```json
{
  "data": {
    "items": ["apple", "google", "facebook"]
  }
}
```

| Rule | Result | Description |
|---|---|---|
| `data.items.1` | `google` | Access array element by index |
| `data.items.0` | `apple` | First element |

#### Aggregate operations

Apply operations across all elements of an array.

```json
{
  "users": [
    { "name": "Alice", "age": 25 },
    { "name": "Bob", "age": 30 },
    { "name": "Charlie", "age": 35 }
  ]
}
```

| Operator | Description | Example | Result |
|---|---|---|---|
| `*+` | Sum | `users.*+.age` | `90` |
| `*avg` | Average | `users.*avg.age` | `30` |
| `*min` | Minimum | `users.*min.age` | `25` |
| `*max` | Maximum | `users.*max.age` | `35` |

#### Element selectors

| Operator | Description | Example | Result |
|---|---|---|---|
| `*first` | First element | `users.*first.name` | `Alice` |
| `*last` | Last element | `users.*last.name` | `Charlie` |
| `*count` | Number of elements | `users.*count` | `3` |

#### Filters

Filter array elements before applying other operations. Syntax: `*[field<op>value]`

```json
{
  "servers": [
    { "name": "s1", "status": "online", "cpu": 45 },
    { "name": "s2", "status": "offline", "cpu": 90 },
    { "name": "s3", "status": "online", "cpu": 72 }
  ]
}
```

| Operator | Description | Example | Result |
|---|---|---|---|
| `=` | Equal | `servers.*[status=online].*count` | `2` |
| `!=` | Not equal | `servers.*[status!=offline].*count` | `2` |
| `>` | Greater than | `servers.*[cpu>50].*count` | `2` |
| `<` | Less than | `servers.*[cpu<80].*+.cpu` | `117` |
| `>=` | Greater or equal | `servers.*[cpu>=72].*avg.cpu` | `81` |
| `<=` | Less or equal | `servers.*[cpu<=45].*first.name` | `s1` |

#### Combining operations

Filters, selectors and aggregates can be chained:

- `servers.*[status=online].*avg.cpu` — average CPU of online servers → `58`
- `servers.*[cpu>50].*last.name` — name of the last server with cpu > 50 → `s3`
- `servers.*[status=online].*max.cpu` — max CPU among online servers → `72`

### HTML

Use format like `Document.querySelector(selector)`

Example: `div a.link`

## Links

- [App Store](https://apps.apple.com/us/app/anymetrics/id1609900961)
- [Gallery Repository](https://github.com/hudishkin/AnyMetricsGallery) — community-contributed metrics

## For developers

**Requirements:** iOS 15.0+, Xcode 15+, [Tuist](https://tuist.io)

```bash
tuist install
tuist generate
```

## License

Open source.
