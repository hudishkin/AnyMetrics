# AnyMetrics | [RU](README_ru.md)

**Turn any API or website into a home screen widget.**

AnyMetrics lets you send requests to any HTTP endpoint — REST API, JSON service, or web page — and display the result as a widget on your iPhone. No coding required.

![Preview](preview.png)

## Features

- **Custom API requests** — any HTTP method, custom headers, configurable timeout
- **JSON parsing** — powerful dot-path rules with filters, aggregates, and selectors
- **HTML parsing** — extract text from web pages using CSS selectors
- **HTTP status monitoring** — check endpoint availability (2xx = success)
- **Home screen widgets** — display live data in compact WidgetKit widgets
- **Value formatting** — currency, length trimming, and more
- **Gallery** — browse ready-made metrics and add them with one tap
- **Import / Export** — share metrics as JSON with your team
- **Free, no ads, no subscription, open source**

## Use Cases

- Monitor server uptime and API availability
- Track CI/CD build stats from GitHub, GitLab, or Jenkins
- Display response times, error rates, or any endpoint data
- Keep an eye on deployment status and service health
- Show download stats, repository stars, or usage metrics

## Parsing Rules

### JSON

Navigate through JSON using dot-separated paths.

#### Basic navigation

``` json
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

``` json
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

``` json
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

## Requirements

- iOS 15.0+
- Xcode 15+
- [Tuist](https://tuist.io)

## Getting Started

```bash
tuist install
tuist generate
```

## Links

- [Gallery Repository](https://github.com/hudishkin/AnyMetricsGallery) — community-contributed metrics
- [App Store](https://apps.apple.com/us/app/anymetrics/id1609900961)

## License

Open source.

______

[![AppStore](appstore.png)](https://apps.apple.com/us/app/anymetrics/id1609900961)
